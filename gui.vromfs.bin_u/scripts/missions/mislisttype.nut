from "%scripts/dagui_natives.nut" import toggle_fav_mission, is_mission_favorite, has_entitlement, get_last_played, get_mission_progress, scan_user_missions
from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version

let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let u = require("%sqStdLibs/helpers/u.nut")
let { getBlkValueByPath, blkOptFromPath } = require("%sqstd/datablock.nut")
let { enumsAddTypes } = require("%sqStdLibs/helpers/enums.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { get_meta_mission_info_by_name, get_meta_missions_info_chapter,
  get_meta_missions_info_by_chapters, get_meta_missions_info_by_campaigns,
  get_mission_local_online_progress } = require("guiMission")
let { get_game_mode, get_cur_game_mode_name } = require("mission")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { capitalize } = require("%sqstd/string.nut")
let { isMissionComplete, getSessionLobbyMissionName
} = require("%scripts/missions/missionsUtilsModule.nut")
let { getCombineLocNameMission } = require("%scripts/missions/missionsText.nut")
let { isInSessionRoom, getMissionUrl } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { isUnitUsable } = require("%scripts/unit/unitStatus.nut")
let { findUnitNoCase } = require("%scripts/unit/unitParams.nut")
let { is_user_mission } = require("%scripts/missions/missionsStates.nut")

enum mislistTabsOrder {
  BASE
  UGM
  URL

  UNKNOWN
}

let g_mislist_type = {
  types = []
}

g_mislist_type._getMissionConfig <- function _getMissionConfig(id, isHeader = false, isCampaign = false, isUnlocked = true) {
  return {
    id = id
    isHeader = isHeader
    isCampaign = isCampaign
    isUnlocked = isUnlocked
    campaign = ""
    chapter = ""
    misListType = this

    getNameText = function() { return this.misListType.getMissionNameText(this) }
  }
}

g_mislist_type._getMissionsByBlkArray <- function _getMissionsByBlkArray(campaignName, missionBlkArray) {
  let res = []
  let gm = get_game_mode()
  let checkFunc = getTblValue("misBlkCheckFunc", this, function(_misBlk) { return true })

  foreach (misBlk in missionBlkArray) {
    let missionId = misBlk?.name ?? ""
    if (!checkFunc(misBlk))
      continue
    if ((gm == GM_SINGLE_MISSION) && g_squad_manager.isNotAloneOnline())
      if (!misBlk.getBool("gt_cooperative", false) || is_user_mission(misBlk))
        continue
    if (misBlk?.hideInSingleMissionList)
      continue
    let unlock = misBlk?.chapter ? getUnlockById($"{misBlk.chapter}/{missionId}") : null
    if (unlock && !isUnlockVisible(unlock))
      continue
    if (misBlk?.reqFeature && !hasFeature(misBlk.reqFeature))
      continue

    let misDescr = this.getMissionConfig(missionId)
    misDescr.blk <- misBlk
    misDescr.chapter <- campaignName
    misDescr.campaign <- misBlk.getStr("campaign", "")
    misDescr.presetName <- misBlk.getStr("presetName", "")

    if (is_user_mission(misBlk)) {
      // Temporary fix for 1.53.7.X (workaround for not detectable player_class).
      // Can be removed after reach all PC platforms.
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
        if (unit && !isUnitUsable(unit)) {
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

      // progress: 0 - completed (arcade), 1 - completed (realistic), 2 - completed (hardcore)
      // 3 - unlocked but not completed, 4 - locked
      if (is_user_mission(misBlk) && !misDescr?.isUnlocked)
        misDescr.progress = 4
    }

    res.append(misDescr)
  }
  return res
}

g_mislist_type._getMissionsList <- function _getMissionsList(isShowCampaigns, callback, customChapterId = null, customChapters = null) {
  let gm = get_game_mode()
  if (customChapterId) {
    let missionBlkArray = get_meta_missions_info_chapter(gm, customChapterId)
    let misList = this.getMissionsByBlkArray(customChapterId, missionBlkArray)
    callback(misList)
    return
  }

  let res = []

  //collect campaigns chapters list
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
    let campName = getTblValue("name", camp)
    let campMissions = []
    local lastMission = null

    foreach (chapterMissions in camp.chapters) {
      if (chapterMissions.len() == 0)
        continue;
      let chapterName = chapterMissions[0].getStr("chapter", get_cur_game_mode_name())

      let isChapterSpecial = isInArray(chapterName, [ "hidden", "test" ])
      local canShowChapter = true
      if (!::is_debug_mode_enabled && isChapterSpecial) {
        let featureName = $"MissionsChapter{capitalize(chapterName)}"
        canShowChapter = is_dev_version() || hasFeature(featureName)
      }
      if (!canShowChapter)
        continue

      let missions = this.getMissionsByBlkArray(chapterName, chapterMissions)
      if (!missions.len())
        continue

      if (this.showChapterHeaders) {
        local isChapterUnlocked = true
        if (lastMission && gm == GM_CAMPAIGN)
          isChapterUnlocked = isChapterSpecial || ::is_debug_mode_enabled || isMissionComplete(lastMission?.chapter, lastMission?.id)
        let chapterHeader = this.getMissionConfig(chapterName, true, false, isChapterUnlocked)
        campMissions.append(chapterHeader)
      }
      campMissions.extend(missions)

      lastMission = missions.top()
    }

    if (!campMissions.len())
      continue

    if (campName && this.showCampaignHeaders) {
      let campHeader = this.getMissionConfig(campName, true, true)
      res.append(campHeader)
    }
    res.extend(campMissions)

    //add victory video for campaigns
    if (lastMission && gm == GM_CAMPAIGN
        && (campName == "usa_pacific_41_43" || campName == "jpn_pacific_41_43")) {
      let isVideoUnlocked = ::is_debug_mode_enabled || isMissionComplete(lastMission?.chapter, lastMission?.id)
      res.append(this.getMissionConfig("victory", true, false, isVideoUnlocked))
    }
  }
  callback(res)
}

g_mislist_type._getMissionsListByNames <- function _getMissionsListByNames(namesList) {
  let blkList = []
  foreach (name in namesList) {
    let misBlk = get_meta_mission_info_by_name(name)
    if (misBlk)
      blkList.append(misBlk)
  }
  return this.getMissionsByBlkArray("", blkList)
}

g_mislist_type._getCurMission <- function _getCurMission() {
  if (isInSessionRoom.get()) {
    let misName = getSessionLobbyMissionName(true)
    if (misName)
      return this.getMissionConfig(misName)
  }
  let lastPlayed = get_last_played("", get_game_mode())
  if (!lastPlayed)
    return null

  let res = this.getMissionConfig(lastPlayed[1])
  res.chapter = lastPlayed[0]
  return res
}

g_mislist_type._getMissionNameText <- function _getMissionNameText(mission) {
  let { id = "" } = mission
  if (mission?.isHeader)
    return mission?.isCampaign ? loc($"campaigns/{id}") : loc($"chapters/{id}")
  if ("blk" in mission)
    return getCombineLocNameMission(mission.blk)
  return loc($"missions/{id}")
}

g_mislist_type.template <- {
  id = "" //filled automatically by typeName
  tabsOrder = mislistTabsOrder.UNKNOWN

  canBeEmpty = true
  canRefreshList = false
  canAddToList = false

  showCampaignHeaders = true
  showChapterHeaders  = true

  getMissionConfig = g_mislist_type._getMissionConfig
  requestMissionsList = function(_isShowCampaigns, callback = null, _customChapterId = null, _customChapters = null) { if (callback) callback([]) }
  getMissionsListByNames = function(_namesList) { return [] }
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

  getCurMission = function() { return null }
  getMissionNameText = g_mislist_type._getMissionNameText

  getInfoLink = @() ""
  infoLinkTextLocId = ""
  infoLinkTooltipLocId = ""
  getInfoLinkData = function() {
    if (isPlatformSony || isPlatformXboxOne)
      return null

    let infoLink = this.getInfoLink()
    if (infoLink == "")
      return null

    return {
      link = infoLink
      text = loc(this.infoLinkTextLocId)
      tooltip = loc(this.infoLinkTooltipLocId, "")
    }
  }

  sortMissionsByName = function(missions) {
    let sortData = missions.map((@(m) { locName = this.getMissionNameText(m), mission = m }).bindenv(this))
    sortData.sort(@(a, b) a.locName <=> b.locName)
    return sortData.map(@(d) d.mission)
  }
}

enumsAddTypes(g_mislist_type, {
  BASE = {
    tabsOrder = mislistTabsOrder.BASE
    canBeEmpty = false
    getTabName = function() { return loc("mainmenu/btnMissions") }

    requestMissionsList = g_mislist_type._getMissionsList
    getMissionsByBlkArray = g_mislist_type._getMissionsByBlkArray
    getMissionsListByNames = g_mislist_type._getMissionsListByNames
    misBlkCheckFunc = function(misBlk) {
      return !is_user_mission(misBlk)
    }
    getCurMission = g_mislist_type._getCurMission
  }

  UGM = {
    tabsOrder = mislistTabsOrder.UGM
    canRefreshList = true
    getTabName = function() { return loc("mainmenu/btnUserMission") }
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
      let fn = function() { this.getMissionsListImpl(isShowCampaigns, callback, customChapterId, customChapters); }
      scan_user_missions(this, fn.bindenv(this))
    }
    getMissionsListImpl = g_mislist_type._getMissionsList
    getMissionsByBlkArray = g_mislist_type._getMissionsByBlkArray
    misBlkCheckFunc = is_user_mission
    getCurMission = g_mislist_type._getCurMission
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

    requestMissionsList = function(_isShowCampaigns, callback, ...) { //standard parameters doesn't work for urlMissions
      let list = g_url_missions.getList()
      let res = []
      foreach (urlMission in list) {
        let mission = this.getMissionConfig(urlMission.name)
        mission.urlMission <- urlMission
        mission.blk <- urlMission.getMetaInfo()
        res.append(mission)
      }
      callback(res)
    }

    addToList = function() {
      g_url_missions.openCreateUrlMissionWnd()
    }

    canModify = function(_mission) { return true }

    modifyMission = function(mission) {
      let urlMission = getTblValue("urlMission", mission)
      if (urlMission)
        g_url_missions.openModifyUrlMissionWnd(urlMission)
    }

    canDelete = function(_mission) { return true }

    deleteMission = function(mission) {
      let urlMission = getTblValue("urlMission", mission)
      if (urlMission)
        g_url_missions.openDeleteUrlMissionConfirmationWnd(urlMission)
    }

    canMarkFavorites = function() { return true }
    isMissionFavorite = function(mission) {
      let urlMission = getTblValue("urlMission", mission)
      if (urlMission)
        return urlMission.isFavorite
      return false
    }
    toggleFavorite = function(mission) {
      g_url_missions.toggleFavorite(getTblValue("urlMission", mission))
    }

    getCurMission = function() {
      if (isInSessionRoom.get()) {
        let url = getMissionUrl()
        let urlMission = g_url_missions.findMissionByUrl(url)
        if (urlMission)
          return this.getMissionConfig(urlMission.name)
      }

      let lastPlayed = get_last_played("url", get_game_mode())
      if (!lastPlayed)
        return null

      let urlMission = g_url_missions.findMissionByUrl(lastPlayed[1])
      if (urlMission)
        return this.getMissionConfig(urlMission.name)
      return null
    }

    getMissionNameText = function(mission) { return mission.id }
  }
}, null, "id")

g_mislist_type.types.sort(function(a, b) {
  if (a.tabsOrder != b.tabsOrder)
    return a.tabsOrder < b.tabsOrder ? -1 : 1
  return 0
})

g_mislist_type.getTypeByName <- function getTypeByName(typeName) {
  let res = getTblValue(typeName, g_mislist_type)
  return u.isTable(res) ? res : this.BASE
}

g_mislist_type.isUrlMission <- function isUrlMission(mission) {
  return "urlMission" in mission
}

return {
  g_mislist_type
}