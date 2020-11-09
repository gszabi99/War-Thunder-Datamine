local enums = ::require("sqStdlibs/helpers/enums.nut")
local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")

enum mislistTabsOrder {
  BASE
  UGM
  URL

  UNKNOWN
}

::g_mislist_type <- {
  types = []
}

g_mislist_type._getMissionConfig <- function _getMissionConfig(id, isHeader = false, isCampaign = false, isUnlocked = true)
{
  return {
    id = id
    isHeader = isHeader
    isCampaign = isCampaign
    isUnlocked = isUnlocked
    campaign = ""
    chapter = ""
    misListType = this

    getNameText = function() { return misListType.getMissionNameText(this) }
  }
}

g_mislist_type._getMissionsByBlkArray <- function _getMissionsByBlkArray(campaignName, missionBlkArray)
{
  local res = []
  local gm = ::get_game_mode()
  local checkFunc = ::getTblValue("misBlkCheckFunc", this, function(misBlk) { return true })

  foreach(misBlk in missionBlkArray)
  {
    local missionId = misBlk?.name ?? ""
    if (!checkFunc(misBlk))
      continue
    if (!::has_feature("Tanks") && ::is_mission_for_unittype(misBlk, ::ES_UNIT_TYPE_TANK))
      continue
    if ((gm == ::GM_SINGLE_MISSION) && ::g_squad_manager.isNotAloneOnline())
      if (!misBlk.getBool("gt_cooperative", false) || ::is_user_mission(misBlk))
        continue
    local unlock = misBlk?.chapter? ::g_unlocks.getUnlockById(misBlk.chapter + "/" + missionId) : null
    if (unlock && !::is_unlock_visible(unlock))
      continue
    if (misBlk?.reqFeature && !::has_feature(misBlk.reqFeature))
      continue

    local misDescr = getMissionConfig(missionId)
    misDescr.blk <- misBlk
    misDescr.chapter <- campaignName
    misDescr.campaign <- misBlk.getStr("campaign","")
    misDescr.presetName <- misBlk.getStr("presetName", "")

    if (::is_user_mission(misBlk))
    {
      // Temporary fix for 1.53.7.X (workaround for not detectable player_class).
      // Can be removed after http://cvs1.gaijin.lan:8080/#/c/57465/ reach all PC platforms.
      if (!misBlk?.player_class)
      {
        local missionBlk = ::DataBlock(misBlk?.mis_file ?? "")
        local wing = ::get_blk_value_by_path(missionBlk, "mission_settings/player/wing")
        local unitsBlk = missionBlk?.units
        if (unitsBlk && wing)
          for (local i = 0; i < unitsBlk.blockCount(); i++)
          {
            local block = unitsBlk.getBlock(i)
            if (block?.name == wing && block?.unit_class)
            {
              misBlk.player_class   = block.unit_class
              misBlk.player_weapons = block?.weapons
              break
            }
          }
      }

      local reqUnit = misBlk.getStr("player_class", "")
      if (reqUnit != "")
      {
        local unit = ::findUnitNoCase(reqUnit)
        if (unit && !::isUnitUsable(unit))
        {
          misDescr.isUnlocked = false
          misDescr.mustHaveUnit <- unit.name
        }
      }
    }

    if (gm == ::GM_CAMPAIGN || gm == ::GM_SINGLE_MISSION || gm == ::GM_TRAINING)
    {
      local missionFullName = campaignName + "/" + (misDescr?.id ?? "")
      misDescr.progress <- ::get_mission_progress(missionFullName)
      if (!::is_user_mission(misBlk))
        misDescr.isUnlocked = misDescr?.progress != 4
      local misLOProgress = get_mission_local_online_progress(missionFullName)
      misDescr.singleProgress <- misLOProgress?.singleDiff
      misDescr.onlineProgress <- misLOProgress?.onlineDiff

      // progress: 0 - completed (arcade), 1 - completed (realistic), 2 - completed (hardcore)
      // 3 - unlocked but not completed, 4 - locked
      if (::is_user_mission(misBlk) && !misDescr?.isUnlocked)
        misDescr.progress = 4
    }

    res.append(misDescr)
  }
  return res
}

g_mislist_type._getMissionsList <- function _getMissionsList(isShowCampaigns, callback, customChapterId = null, customChapters = null)
{
  local gm = ::get_game_mode()
  if (customChapterId)
  {
    local missionBlkArray = ::get_meta_missions_info_chapter(gm, customChapterId)
    local misList = getMissionsByBlkArray(customChapterId, missionBlkArray)
    callback(misList)
    return
  }

  local res = []

  //collect campaigns chapters list
  local campaigns = []
  if (customChapters)
    campaigns = [{ chapters = customChapters }]
  else if (!isShowCampaigns)
    campaigns = [{ chapters = ::get_meta_missions_info_by_chapters(gm) }]
  else
  {
    local mbc = ::get_meta_missions_info_by_campaigns(gm)
    foreach(c in mbc)
      if (gm!=::GM_CAMPAIGN || ::has_entitlement(c.name) || ::has_feature(c.name))
        campaigns.append({ name = c.name, chapters = c.chapters})
  }

  foreach(camp in campaigns)
  {
    local campName = ::getTblValue("name", camp)
    local campMissions = []
    local lastMission = null

    foreach(chapterMissions in camp.chapters)
    {
      if (chapterMissions.len() == 0)
        continue;
      local chapterName = chapterMissions[0].getStr("chapter",::get_cur_game_mode_name())

      local isChapterSpecial = ::isInArray(chapterName, [ "hidden", "test" ])
      local canShowChapter = true
      if (!::is_debug_mode_enabled && isChapterSpecial)
      {
        local featureName = "MissionsChapter" + ::g_string.toUpper(chapterName, 1)
        canShowChapter = ::is_dev_version || ::has_feature(featureName)
      }
      if (!canShowChapter)
        continue

      local missions = getMissionsByBlkArray(chapterName, chapterMissions)
      if (!missions.len())
        continue

      if (showChapterHeaders)
      {
        local isChapterUnlocked = true
        if (lastMission && gm == ::GM_CAMPAIGN)
          isChapterUnlocked = isChapterSpecial || ::is_debug_mode_enabled || ::is_mission_complete(lastMission?.chapter, lastMission?.id)
        local chapterHeader = getMissionConfig(chapterName, true, false, isChapterUnlocked)
        campMissions.append(chapterHeader)
      }
      campMissions.extend(missions)

      lastMission = missions.top()
    }

    if (!campMissions.len())
      continue

    if (campName && showCampaignHeaders)
    {
      local campHeader = getMissionConfig(campName, true, true)
      res.append(campHeader)
    }
    res.extend(campMissions)

    //add victory video for campaigns
    if (lastMission && gm == ::GM_CAMPAIGN
        && (campName == "usa_pacific_41_43" || campName == "jpn_pacific_41_43"))
    {
      local isVideoUnlocked = ::is_debug_mode_enabled || ::is_mission_complete(lastMission?.chapter, lastMission?.id)
      res.append(getMissionConfig("victory", true, false, isVideoUnlocked))
    }
  }
  callback(res)
}

g_mislist_type._getMissionsListByNames <- function _getMissionsListByNames(namesList)
{
  local blkList = []
  foreach(name in namesList)
  {
    local misBlk = ::get_meta_mission_info_by_name(name)
    if (misBlk)
      blkList.append(misBlk)
  }
  return getMissionsByBlkArray("", blkList)
}

g_mislist_type._getCurMission <- function _getCurMission()
{
  if (::SessionLobby.isInRoom())
  {
    local misName = ::SessionLobby.getMissionName(true)
    if (misName)
      return getMissionConfig(misName)
  }
  local lastPlayed = ::get_last_played("", ::get_game_mode())
  if (!lastPlayed)
    return null

  local res = getMissionConfig(lastPlayed[1])
  res.chapter = lastPlayed[0]
  return res
}

g_mislist_type._getMissionNameText <- function _getMissionNameText(mission)
{
  if (mission?.isHeader)
    return ::loc((mission?.isCampaign ? "campaigns/" : "chapters/") + (mission?.id ?? ""))
  if ("blk" in mission)
    return ::get_combine_loc_name_mission(mission.blk)
  return ::loc("missions/" + (mission?.id ?? ""))
}

::g_mislist_type.template <- {
  id = "" //filled automatically by typeName
  tabsOrder = mislistTabsOrder.UNKNOWN

  canBeEmpty = true
  canRefreshList = false
  canAddToList = false

  showCampaignHeaders = true
  showChapterHeaders  = true

  getMissionConfig = ::g_mislist_type._getMissionConfig
  requestMissionsList = function(isShowCampaigns, callback = null, customChapterId = null, customChapters = null) { if (callback) callback([]) }
  getMissionsListByNames = function(namesList) { return [] }
  canJoin = function(gm) { return true }
  canCreate = function(gm) { return canJoin(gm) }

  getTabName = function() { return "" }

  addToList = function() {}
  canModify = function(mission) { return false }
  modifyMission = function(mission) {}
  canDelete = function(mission) { return false }
  deleteMission = function(mission) {}

  canMarkFavorites = function()
  {
    local gm = ::get_game_mode()
    return gm == ::GM_DOMINATION || gm == ::GM_SKIRMISH
  }

  isMissionFavorite = function(mission) { return ::is_mission_favorite(mission.id) }
  toggleFavorite = function(mission) { ::toggle_fav_mission(mission.id) }

  getCurMission = function() { return null }
  getMissionNameText = ::g_mislist_type._getMissionNameText

  infoLinkLocId = ""
  infoLinkTextLocId = ""
  infoLinkTooltipLocId = ""
  getInfoLinkData = function()
  {
    if (isPlatformSony || isPlatformXboxOne || !infoLinkLocId.len())
      return null

    return {
      link = ::loc(infoLinkLocId)
      text = ::loc(infoLinkTextLocId)
      tooltip = ::loc(infoLinkTooltipLocId, "")
    }
  }

  sortMissionsByName = function(missions)
  {
    local sortData = ::u.map(missions, (@(m) { locName = getMissionNameText(m), mission = m }).bindenv(this))
    sortData.sort(@(a, b) a.locName <=> b.locName)
    return ::u.map(sortData, @(d) d.mission)
  }
}

enums.addTypesByGlobalName("g_mislist_type", {
  BASE = {
    tabsOrder = mislistTabsOrder.BASE
    canBeEmpty = false
    getTabName = function() { return ::loc("mainmenu/btnMissions") }

    requestMissionsList = ::g_mislist_type._getMissionsList
    getMissionsByBlkArray = ::g_mislist_type._getMissionsByBlkArray
    getMissionsListByNames = ::g_mislist_type._getMissionsListByNames
    misBlkCheckFunc = function(misBlk)
    {
      return !::is_user_mission(misBlk)
    }
    getCurMission = ::g_mislist_type._getCurMission
  }

  UGM = {
    tabsOrder = mislistTabsOrder.UGM
    canRefreshList = true
    getTabName = function() { return ::loc("mainmenu/btnUserMission") }
    infoLinkLocId = "url/live/user_missions"
    infoLinkTextLocId = "missions/user_missions/getOnline"
    infoLinkTooltipLocId = "missions/user_missions/about"

    canJoin = function(gm)
    {
      if (gm == ::GM_SINGLE_MISSION)
        return ::has_feature("UserMissions")
      if (gm == ::GM_SKIRMISH)
        return ::has_feature("UserMissionsSkirmishLocal")
      return false
    }

    requestMissionsList = function(isShowCampaigns, callback, customChapterId = null, customChapters = null)
    {
      local fn = function(){ getMissionsListImpl(isShowCampaigns, callback, customChapterId, customChapters); }
      ::scan_user_missions(this, fn.bindenv(this))
    }
    getMissionsListImpl = ::g_mislist_type._getMissionsList
    getMissionsByBlkArray = ::g_mislist_type._getMissionsByBlkArray
    misBlkCheckFunc = ::is_user_mission
    getCurMission = ::g_mislist_type._getCurMission
  }

  URL = {
    tabsOrder = mislistTabsOrder.URL
    canAddToList = true
    getTabName = function() { return ::loc("urlMissions/header") }
    infoLinkLocId = "url/live/user_missions"
    infoLinkTextLocId = "missions/user_missions/getOnline"
    infoLinkTooltipLocId = "missions/user_missions/about"

    canJoin = function(gm)
    {
      return gm == ::GM_SKIRMISH && ::has_feature("UserMissionsSkirmishByUrl")
    }

    canCreate = function(gm)
    {
      return gm == ::GM_SKIRMISH && ::has_feature("UserMissionsSkirmishByUrlCreate")
    }

    requestMissionsList = function(isShowCampaigns, callback, ...) //standard parameters doesn't work for urlMissions
    {
      local list = ::g_url_missions.getList()
      local res = []
      foreach(urlMission in list)
      {
        local mission = getMissionConfig(urlMission.name)
        mission.urlMission <- urlMission
        mission.blk <- urlMission.getMetaInfo()
        res.append(mission)
      }
      callback(res)
    }

    addToList = function()
    {
      ::g_url_missions.openCreateUrlMissionWnd()
    }

    canModify = function(mission) { return true }

    modifyMission = function(mission)
    {
      local urlMission = ::getTblValue("urlMission", mission)
      if (urlMission)
        ::g_url_missions.openModifyUrlMissionWnd(urlMission)
    }

    canDelete = function(mission) { return true }

    deleteMission = function(mission)
    {
      local urlMission = ::getTblValue("urlMission", mission)
      if (urlMission)
        ::g_url_missions.openDeleteUrlMissionConfirmationWnd(urlMission)
    }

    canMarkFavorites = function() { return true }
    isMissionFavorite = function(mission)
    {
      local urlMission = ::getTblValue("urlMission", mission)
      if (urlMission)
        return urlMission.isFavorite
      return false
    }
    toggleFavorite = function(mission)
    {
      ::g_url_missions.toggleFavorite(::getTblValue("urlMission", mission))
    }

    getCurMission = function()
    {
      if (::SessionLobby.isInRoom())
      {
        local url = ::SessionLobby.getMissionUrl()
        local urlMission = ::g_url_missions.findMissionByUrl(url)
        if (urlMission)
          return getMissionConfig(urlMission.name)
      }

      local lastPlayed = ::get_last_played("url", ::get_game_mode())
      if (!lastPlayed)
        return null

      local urlMission = ::g_url_missions.findMissionByUrl(lastPlayed[1])
      if (urlMission)
        return getMissionConfig(urlMission.name)
      return null
    }

    getMissionNameText = function(mission) { return mission.id }
  }
}, null, "id")

::g_mislist_type.types.sort(function(a, b) {
  if (a.tabsOrder != b.tabsOrder)
    return a.tabsOrder < b.tabsOrder ? -1 : 1
  return 0
})

g_mislist_type.getTypeByName <- function getTypeByName(typeName)
{
  local res = ::getTblValue(typeName, ::g_mislist_type)
  return ::u.isTable(res) ? res : BASE
}

g_mislist_type.isUrlMission <- function isUrlMission(mission)
{
  return "urlMission" in mission
}