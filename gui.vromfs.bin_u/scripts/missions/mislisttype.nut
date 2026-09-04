from "%sqStdLibs/helpers/u.nut" import isTable
from "%sqStdLibs/helpers/enums.nut" import enumsAddTypes
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "%sqstd/datablock.nut" import getBlkValueByPath, blkOptFromPath
from "guiMission" import get_meta_mission_info_by_name, get_meta_missions_info_chapter, get_meta_missions_info_by_chapters, get_meta_missions_info_by_campaigns, get_mission_local_online_progress
from "mission" import get_game_mode, get_cur_game_mode_name
from "%sqstd/string.nut" import capitalize
from "%scripts/dagui_natives.nut" import toggle_fav_mission, is_mission_favorite, has_entitlement, get_last_played, get_mission_progress, scan_user_missions
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version
from "dagor.workcycle" import defer

let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")
let { isNotAloneOnline } = require("%scripts/squads/squadState.nut")
let { isPlatformSony, isPlatformXbox } = require("%scripts/clientState/platform.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { isMissionComplete, getSessionLobbyMissionName } = require("%scripts/missions/missionsUtilsModule.nut")
let { getCombineLocNameMission } = require("%scripts/missions/missionsText.nut")
let { isInSessionRoom, getMissionUrl } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { findUnitNoCase } = require("%scripts/unit/unitParams.nut")
let { is_user_mission } = require("%scripts/missions/missionsStates.nut")
let { isDebugModeEnabled } = require("%scripts/debugTools/dbgChecks.nut")

enum mislistTabsOrder {
  BASE
  UGM
  URL

  UNKNOWN
}

function getMissionNameTextDefault(mission) {
  let { id = "" } = mission
  if (mission?.isHeader)
    return mission?.isCampaign ? loc($"campaigns/{id}") : loc($"chapters/{id}")
  if ("blk" in mission)
    return getCombineLocNameMission(mission.blk)
  return loc($"missions/{id}")
}

function sortMissionsByName(missions) {
  let sortData = missions.map(@(m) { locName = m.getNameText(), mission = m })
  sortData.sort(@(a, b) a.locName <=> b.locName)
  return sortData.map(@(d) d.mission)
}

function getMissionConfig(id, misListType, ovr = {}) {
  let { getMissionNameText } = misListType
  return {
    id = id
    isHeader = false
    isCampaign = false
    isUnlocked = true
    campaign = ""
    chapter = ""

    getNameText = @() getMissionNameText(this)
  }.__update(ovr)
}

function getMissionsByBlkArray(misListType, campaignName, missionBlkArray) {
  let res = []
  let gm = get_game_mode()
  let checkFunc = misListType?.misBlkCheckFunc ?? @(_misBlk) true

  foreach (misBlk in missionBlkArray) {
    let missionId = misBlk?.name ?? ""
    if (!checkFunc(misBlk))
      continue
    if ((gm == GM_SINGLE_MISSION) && isNotAloneOnline())
      if (!misBlk.getBool("gt_cooperative", false) || is_user_mission(misBlk))
        continue
    if (misBlk?.hideInSingleMissionList)
      continue
    let unlock = misBlk?.chapter ? getUnlockById($"{misBlk.chapter}/{missionId}") : null
    if (unlock && !isUnlockVisible(unlock))
      continue
    if (misBlk?.reqFeature && !hasFeature(misBlk.reqFeature))
      continue

    let misDescr = getMissionConfig(missionId, misListType, {
      blk = misBlk
      chapter = campaignName
      campaign = misBlk.getStr("campaign", "")
      presetName = misBlk.getStr("presetName", "")
    })

    if (is_user_mission(misBlk)) {
      
      
      if (!misBlk?.player_class) {
        let missionBlk = blkOptFromPath(misBlk?.mis_file)
        let wing = getBlkValueByPath(missionBlk, "mission_settings/player/wing")
        let unitsBlk = missionBlk?.units
        if (unitsBlk && wing)
          for (local i = 0; i < unitsBlk.blockCount(); i++) {
            let block = unitsBlk.getBlock(i)
            if (block?.name == wing && block?.unit_class) {
              misBlk.player_class   = block.unit_class
              misBlk.player_weapons = block?.weapons
              break
            }
          }
      }

      let reqUnit = misBlk.getStr("player_class", "")
      if (reqUnit != "") {
        let unit = findUnitNoCase(reqUnit)
        if (unit && !unit?.isUsable()) {
          misDescr.isUnlocked = false
          misDescr.mustHaveUnit <- unit.name
        }
      }
    }

    if (gm == GM_CAMPAIGN || gm == GM_SINGLE_MISSION || gm == GM_TRAINING) {
      let missionFullName = $"{campaignName}/{misDescr?.id ?? ""}"
      misDescr.progress <- get_mission_progress(missionFullName)
      if (!is_user_mission(misBlk))
        misDescr.isUnlocked = misDescr?.progress != 4
      let misLOProgress = get_mission_local_online_progress(missionFullName)
      misDescr.singleProgress <- misLOProgress?.singleDiff
      misDescr.onlineProgress <- misLOProgress?.onlineDiff

      
      
      if (is_user_mission(misBlk) && !misDescr?.isUnlocked)
        misDescr.progress = 4
    }

    res.append(misDescr)
  }
  return res
}

function getMissionsList(isShowCampaigns, misListType, customChapterId = null, customChapters = null) {
  let gm = get_game_mode()
  if (customChapterId) {
    let missionBlkArray = get_meta_missions_info_chapter(gm, customChapterId)
    let misList = getMissionsByBlkArray(misListType, customChapterId, missionBlkArray)
    return misList
  }

  let res = []

  
  local campaigns = []
  if (customChapters)
    campaigns = [{ chapters = customChapters }]
  else if (!isShowCampaigns)
    campaigns = [{ chapters = get_meta_missions_info_by_chapters(gm) }]
  else {
    let mbc = get_meta_missions_info_by_campaigns(gm)
    foreach (c in mbc)
      if (gm != GM_CAMPAIGN || has_entitlement(c.name) || hasFeature(c.name))
        campaigns.append({ name = c.name, chapters = c.chapters })
  }

  foreach (camp in campaigns) {
    let campName = camp?.name
    let campMissions = []
    local lastMission = null

    foreach (chapterMissions in camp.chapters) {
      if (chapterMissions.len() == 0)
        continue;
      let chapterName = chapterMissions[0].getStr("chapter", get_cur_game_mode_name())

      let isChapterSpecial = isInArray(chapterName, [ "hidden", "test" ])
      local canShowChapter = true
      if (!isDebugModeEnabled.status && isChapterSpecial) {
        let featureName = $"MissionsChapter{capitalize(chapterName)}"
        canShowChapter = is_dev_version() || hasFeature(featureName)
      }
      if (!canShowChapter)
        continue

      let missions = getMissionsByBlkArray(misListType, chapterName, chapterMissions)
      if (!missions.len())
        continue

      local isChapterUnlocked = true
      if (lastMission && gm == GM_CAMPAIGN)
        isChapterUnlocked = isChapterSpecial || isDebugModeEnabled.status || isMissionComplete(lastMission?.chapter, lastMission?.id)
      let chapterHeader = getMissionConfig(chapterName, misListType,
        { isHeader = true, isUnlocked = isChapterUnlocked })
      campMissions.append(chapterHeader)
      campMissions.extend(missions)

      lastMission = missions.top()
    }

    if (!campMissions.len())
      continue

    if (campName) {
      let campHeader = getMissionConfig(campName, misListType, { isHeader = true, isCampaign = true })
      res.append(campHeader)
    }
    res.extend(campMissions)

    
    if (lastMission && gm == GM_CAMPAIGN
        && (campName == "usa_pacific_41_43" || campName == "jpn_pacific_41_43")) {
      let isVideoUnlocked = isDebugModeEnabled.status || isMissionComplete(lastMission?.chapter, lastMission?.id)
      res.append(getMissionConfig("victory", misListType,
        { isHeader = true, isUnlocked = isVideoUnlocked }))
    }
  }
  return res
}

function getCurMission(misListType) {
  if (isInSessionRoom.get()) {
    let misName = getSessionLobbyMissionName(true)
    if (misName)
      return getMissionConfig(misName, misListType)
  }
  let lastPlayed = get_last_played("", get_game_mode())
  if (!lastPlayed)
    return null

  let res = getMissionConfig(lastPlayed[1], misListType)
  res.chapter = lastPlayed[0]
  return res
}

let g_mislist_type = {
  types = []
  template = {
    id = "" 
    tabsOrder = mislistTabsOrder.UNKNOWN

    canBeEmpty = true
    canRefreshList = false
    canAddToList = false

    requestMissionsList = function(_isShowCampaigns, callback = null, _customChapterId = null, _customChapters = null) { if (callback) callback([]) }
    canJoin = function(_gm) { return true }
    canCreate = function(gm) { return this.canJoin(gm) }

    getTabName = function() { return "" }

    addToList = function() {}
    canModify = function(_mission) { return false }
    modifyMission = function(_mission) {}
    canDelete = function(_mission) { return false }
    deleteMission = function(_mission) {}

    canMarkFavorites = function() {
      let gm = get_game_mode()
      return gm == GM_DOMINATION || gm == GM_SKIRMISH
    }

    isMissionFavorite = function(mission) { return is_mission_favorite(mission.id) }
    toggleFavorite = function(mission) { toggle_fav_mission(mission.id) }

    getCurMission = @() getCurMission(this)
    getMissionNameText = getMissionNameTextDefault

    forceExternalLink = false
    getInfoLink = @() ""
    infoLinkTextLocId = ""
    infoLinkTooltipLocId = ""
    getInfoLinkData = function() {
      if (isPlatformSony || isPlatformXbox)
        return null

      let infoLink = this.getInfoLink()
      if (infoLink == "")
        return null

      return {
        link = infoLink
        text = loc(this.infoLinkTextLocId)
        tooltip = loc(this.infoLinkTooltipLocId, "")
        forceExternal = this.forceExternalLink
      }
    }
  }
}

enumsAddTypes(g_mislist_type, {
  BASE = {
    tabsOrder = mislistTabsOrder.BASE
    canBeEmpty = false
    getTabName = function() { return loc("mainmenu/btnMissions") }

    function requestMissionsList(isShowCampaigns, callback, customChapterId = null, customChapters = null) {
      let misList = getMissionsList(isShowCampaigns, this, customChapterId, customChapters)
      defer(@() callback(misList))
    }
    misBlkCheckFunc = function(misBlk) {
      return !is_user_mission(misBlk)
    }
  }

  UGM = {
    tabsOrder = mislistTabsOrder.UGM
    canRefreshList = true
    getTabName = function() { return loc("mainmenu/btnUserMission") }
    forceExternalLink = true
    getInfoLink = @() getCurCircuitOverride("liveUserMissionsUrl", loc("url/live/user_missions"))
    infoLinkTextLocId = "missions/user_missions/getOnline"
    infoLinkTooltipLocId = "missions/user_missions/about"

    canJoin = function(gm) {
      if (gm == GM_SINGLE_MISSION)
        return hasFeature("UserMissions")
      if (gm == GM_SKIRMISH)
        return hasFeature("UserMissionsSkirmishLocal")
      return false
    }

    requestMissionsList = function(isShowCampaigns, callback, customChapterId = null, customChapters = null) {
      let fn = function() {
        let misList = getMissionsList(isShowCampaigns, this, customChapterId, customChapters)
        defer(@() callback(misList))
      }
      scan_user_missions(this, fn.bindenv(this))
    }
    misBlkCheckFunc = is_user_mission
  }

  URL = {
    tabsOrder = mislistTabsOrder.URL
    canAddToList = true
    getTabName = function() { return loc("urlMissions/header") }
    getInfoLink = @() getCurCircuitOverride("liveUserMissionsUrl", loc("url/live/user_missions"))
    infoLinkTextLocId = "missions/user_missions/getOnline"
    infoLinkTooltipLocId = "missions/user_missions/about"

    canJoin = function(gm) {
      return gm == GM_SKIRMISH && hasFeature("UserMissionsSkirmishByUrl")
    }

    canCreate = function(gm) {
      return gm == GM_SKIRMISH && hasFeature("UserMissionsSkirmishByUrlCreate")
    }

    requestMissionsList = function(_isShowCampaigns, callback, ...) { 
      let list = g_url_missions.getList()
      let res = []
      foreach (urlMission in list) {
        let mission = getMissionConfig(urlMission.name, this,
          { urlMission, blk = urlMission.getMetaInfo() })
        res.append(mission)
      }
      callback(res)
    }

    addToList = function() {
      g_url_missions.openCreateUrlMissionWnd()
    }

    canModify = function(_mission) { return true }

    modifyMission = function(mission) {
      let urlMission = mission?.urlMission
      if (urlMission)
        g_url_missions.openModifyUrlMissionWnd(urlMission)
    }

    canDelete = function(_mission) { return true }

    deleteMission = function(mission) {
      let urlMission = mission?.urlMission
      if (urlMission)
        g_url_missions.openDeleteUrlMissionConfirmationWnd(urlMission)
    }

    canMarkFavorites = function() { return true }
    isMissionFavorite = function(mission) {
      let urlMission = mission?.urlMission
      if (urlMission)
        return urlMission.isFavorite
      return false
    }
    toggleFavorite = function(mission) {
      g_url_missions.toggleFavorite(mission?.urlMission)
    }

    getCurMission = function() {
      if (isInSessionRoom.get()) {
        let url = getMissionUrl()
        let urlMission = g_url_missions.findMissionByUrl(url)
        if (urlMission)
          return getMissionConfig(urlMission.name, this)
      }

      let lastPlayed = get_last_played("url", get_game_mode())
      if (!lastPlayed)
        return null

      let urlMission = g_url_missions.findMissionByUrl(lastPlayed[1])
      if (urlMission)
        return getMissionConfig(urlMission.name, this)
      return null
    }

    getMissionNameText = @(mission) mission.id
  }
}, null, "id")

g_mislist_type.types.sort(function(a, b) {
  if (a.tabsOrder != b.tabsOrder)
    return a.tabsOrder < b.tabsOrder ? -1 : 1
  return 0
})

function getMislistTypeByName(typeName) {
  let res = g_mislist_type?[typeName]
  return isTable(res) ? res : g_mislist_type.BASE
}

function getSortedMissionsListByNames(namesList) {
  let blkList = []
  foreach (name in namesList) {
    let misBlk = get_meta_mission_info_by_name(name)
    if (misBlk)
      blkList.append(misBlk)
  }
  let res = getMissionsByBlkArray(g_mislist_type.BASE, "", blkList)
  return sortMissionsByName(res)
}

return {
  g_mislist_type
  getMislistTypeByName
  getSortedMissionsListByNames
  getMissionsList
}