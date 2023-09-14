//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let DataBlock = require("DataBlock")
let { format } = require("string")
let { get_blk_value_by_path, blkOptFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { getMissionLocName } = require("%scripts/missions/missionsUtilsModule.nut")
let { get_meta_mission_info_by_name, get_meta_missions_info_by_campaigns,
  add_custom_mission_list_full, get_meta_mission_info_by_gm_and_name,
  get_current_mission_desc } = require("guiMission")
let { set_game_mode, get_game_mode, get_game_type } = require("mission")
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")

const COOP_MAX_PLAYERS = 4

::enable_coop_in_QMB <- false
::enable_coop_in_SingleMissions <- false
::enable_custom_battles <- false

global enum MIS_PROGRESS { //value received from get_mission_progress
  COMPLETED_ARCADE    = 0
  COMPLETED_REALISTIC = 1
  COMPLETED_SIMULATOR = 2
  UNLOCKED            = 3 //unlocked but not completed
  LOCKED              = 4
}

let needCheckForVictory = Watched(false)

registerPersistentData("MissionsUtilsGlobals", getroottable(),
  [
    "enable_coop_in_QMB", "enable_coop_in_SingleMissions", "enable_custom_battles"
  ])

::is_mission_complete <- function is_mission_complete(chapterName, missionName) { //different by mp_modes
  let progress = ::get_mission_progress(chapterName + "/" + missionName)
  return progress >= 0 && progress < 3
}

::is_user_mission <- function is_user_mission(missionBlk) {
  return missionBlk?.userMission == true //can be null
}

::can_play_gamemode_by_squad <- function can_play_gamemode_by_squad(gm) {
  if (!::g_squad_manager.isNotAloneOnline())
    return true

  if (gm == GM_SINGLE_MISSION)
    return ::enable_coop_in_SingleMissions
  if (gm == GM_BUILDER)
    return ::enable_coop_in_QMB
  if (gm == GM_SKIRMISH)
    return ::enable_custom_battles

  return false
}

//return 0 when no limits
::get_max_players_for_gamemode <- function get_max_players_for_gamemode(gm) {
  if (isInArray(gm, [GM_SINGLE_MISSION, GM_DYNAMIC, GM_BUILDER]))
    return COOP_MAX_PLAYERS
  return 0
}

::get_game_mode_loc_name <- function get_game_mode_loc_name(gm) {
  return loc(format("multiplayer/%sMode", ::get_game_mode_name(gm)))
}

::is_skirmish_with_killstreaks <- function is_skirmish_with_killstreaks(misBlk) {
  return misBlk.getBool("allowedKillStreaks", false);
}

::upgrade_url_mission <- function upgrade_url_mission(fullMissionBlk) {
  let misBlk = fullMissionBlk?.mission_settings?.mission
  if (!fullMissionBlk || !misBlk)
    return

  if (misBlk?.useKillStreaks && !misBlk?.allowedKillStreaks)
    misBlk.useKillStreaks = false

  foreach (unitType in unitTypes.types)
    if (unitType.isAvailable() && !(unitType.missionSettingsAvailabilityFlag in misBlk))
      misBlk[unitType.missionSettingsAvailabilityFlag] = ::has_unittype_in_full_mission_blk(fullMissionBlk, unitType.esUnitType)
}

::get_mission_allowed_unittypes_mask <- function get_mission_allowed_unittypes_mask(misBlk, useKillStreaks = null) {
  local res = 0
  foreach (unitType in unitTypes.types)
    if (unitType.isAvailable() && ::is_mission_for_unittype(misBlk, unitType.esUnitType, useKillStreaks))
      res = res | unitType.bit
  return res
}

::is_mission_for_unittype <- function is_mission_for_unittype(misBlk, esUnitType, useKillStreaks = null) {
  let unitType = unitTypes.getByEsUnitType(esUnitType)

  // Works for missions in Skirmish.
  if (unitType.missionSettingsAvailabilityFlag in misBlk)
    return unitType.isAvailableByMissionSettings(misBlk, useKillStreaks)

  // Works for all missions, including single missions, user missions, etc.
  local fullMissionBlk = null
  let url = getTblValue("url", misBlk)
  if (url != null)
    fullMissionBlk = getTblValue("fullMissionBlk", ::g_url_missions.findMissionByUrl(url))
  else
    fullMissionBlk = blkOptFromPath(misBlk?.mis_file)
  return ::has_unittype_in_full_mission_blk(fullMissionBlk, esUnitType)
}

::has_unittype_in_full_mission_blk <- function has_unittype_in_full_mission_blk(fullMissionBlk, esUnitType) {
  // Searching by units of Single missions
  let unitsBlk = fullMissionBlk?.units
  let playerBlk = fullMissionBlk && get_blk_value_by_path(fullMissionBlk, "mission_settings/player")
  let wings = playerBlk ? (playerBlk % "wing") : []
  let unitsCache = {}
  if (unitsBlk && wings.len())
    for (local i = 0; i < unitsBlk.blockCount(); i++) {
      let block = unitsBlk.getBlock(i)
      if (block && isInArray(block?.name, wings))
        if (block?.unit_class) {
          if (!(block.unit_class in unitsCache))
            unitsCache[block.unit_class] <- getEsUnitType(::findUnitNoCase(block.unit_class))
          if (unitsCache[block.unit_class] == esUnitType)
            return true
        }
    }

  // Searching by respawn points of Multiplayer missions
  let tag = unitTypes.getByEsUnitType(esUnitType).tag
  let triggersBlk = fullMissionBlk?.triggers
  if (triggersBlk)
    for (local i = 0; i < triggersBlk.blockCount(); i++) {
      let actionsBlk = triggersBlk.getBlock(i)?.getBlockByName("actions")
      let respawnPointsList = actionsBlk ? (actionsBlk % "missionMarkAsRespawnPoint") : []
      foreach (pointBlk in respawnPointsList)
        if (pointBlk?.tags?[tag])
          return true
    }

  return false
}

::select_next_avail_campaign_mission <- function select_next_avail_campaign_mission(chapterName, missionName) {
  if (get_game_mode() != GM_CAMPAIGN)
    return

  let callback = function(misList) {
    local isCurFound = false
    foreach (mission in misList) {
      if (mission?.isHeader || !mission?.isUnlocked)
        continue

      if (!isCurFound) {
        if (mission?.id == missionName && mission?.chapter == chapterName)
          isCurFound = true
        continue
      }

      ::add_last_played(mission?.chapter, mission?.id, GM_CAMPAIGN, false)
      break
    }

  }
 ::g_mislist_type.BASE.requestMissionsList(true, callback)
}

::buildRewardText <- function buildRewardText(name, reward, highlighted = false, _coloredIcon = false, additionalReward = false) {
  local rewText = reward.tostring()
  if (rewText != "") {
    if (highlighted)
      rewText = format("<color=@highlightedTextColor>%s</color>", (additionalReward ? ("+(" + rewText + ")") : rewText))
    rewText = name + ((name != "") ? loc("ui/colon") : "") + rewText
  }
  return rewText
}

::add_mission_list_full <- function add_mission_list_full(gm_builder, add, dynlist) {
  add_custom_mission_list_full(gm_builder, add, dynlist)
  ::game_mode_maps.clear()
}

let function getUrlOrFileMissionMetaInfo(missionName, gm = null) {
  let urlMission = ::g_url_missions.findMissionByName(missionName)
  if (urlMission != null)
    return urlMission.getMetaInfo()

  if (gm != null) {
    let misBlk = get_meta_mission_info_by_gm_and_name(gm, missionName)
    if (misBlk != null)
      return misBlk
  }

  return get_meta_mission_info_by_name(missionName)
}

::gui_start_campaign <- function gui_start_campaign(checkPack = true) {
  if (checkPack)
    return ::check_package_and_ask_download("hc_pacific", null, ::gui_start_campaign_no_pack, null, "campaign")

  ::gui_start_mislist(true, GM_CAMPAIGN)

  if (needCheckForVictory.value && ! ::is_system_ui_active()) {
    needCheckForVictory(false)
    ::play_movie("video/victory", false, true, true)
  }
}

::gui_start_campaign_no_pack <- function gui_start_campaign_no_pack() {
  ::gui_start_campaign(false)
}

::gui_start_menuCampaign <- function gui_start_menuCampaign() {
  ::gui_start_mainmenu()
  ::gui_start_campaign()
}

::gui_start_singleMissions <- function gui_start_singleMissions() {
  ::gui_start_mislist(true, GM_SINGLE_MISSION)
}

::gui_start_menuSingleMissions <- function gui_start_menuSingleMissions() {
  ::gui_start_mainmenu()
  ::gui_start_singleMissions()
}

::gui_start_userMissions <- function gui_start_userMissions() {
  ::gui_start_mislist(true, GM_SINGLE_MISSION, { misListType = ::g_mislist_type.UGM })
}

::gui_start_menuUserMissions <- function gui_start_menuUserMissions() {
  ::gui_start_mainmenu()
  ::gui_start_userMissions()
}

::gui_create_skirmish <- function gui_create_skirmish() {
  ::gui_start_mislist(true, GM_SKIRMISH)
}

::is_any_campaign_available <- function is_any_campaign_available() {
  let mbc = get_meta_missions_info_by_campaigns(GM_CAMPAIGN)
  foreach (item in mbc)
    if (::has_entitlement(item.name) || hasFeature(item.name))
      return true
  return false
}

::get_not_purchased_campaigns <- function get_not_purchased_campaigns() {
  let res = []
  let mbc = get_meta_missions_info_by_campaigns(GM_CAMPAIGN)
  foreach (item in mbc)
    if (!::has_entitlement(item.name) && !hasFeature(item.name))
      res.append(item.name)
  return res
}

::purchase_any_campaign <- function purchase_any_campaign() {
  ::OnlineShopModel.openBrowserForFirstFoundEntitlement(::get_not_purchased_campaigns())
}

::gui_start_singleplayer_from_coop <- function gui_start_singleplayer_from_coop() {
  set_game_mode(GM_SINGLE_MISSION);
  ::gui_start_missions();
}

::gui_start_mislist <- function gui_start_mislist(isModal = false, setGameMode = null, addParams = {}) {
  let hClass = isModal ? gui_handlers.SingleMissionsModal : gui_handlers.SingleMissions
  let params = clone addParams
  local gm = get_game_mode()
  if (setGameMode != null) {
    params.wndGameMode <- setGameMode
    gm = setGameMode
  }

  params.canSwitchMisListType <- gm == GM_SKIRMISH

  let showAllCampaigns = gm == GM_CAMPAIGN || gm == GM_SINGLE_MISSION
  ::current_campaign_id = showAllCampaigns ? null : ::get_game_mode_name(gm)
  params.showAllCampaigns <- showAllCampaigns

  if (!isModal) {
    params.backSceneParams = { globalFunctionName = "gui_start_mainmenu" }
    if (::SessionLobby.isInRoom() && (get_game_mode() == GM_DYNAMIC))
      params.backSceneParams = { globalFunctionName = "gui_start_dynamic_summary" }
  }

  handlersManager.loadHandler(hClass, params)
  if (!isModal)
    handlersManager.setLastBaseHandlerStartParams({ globalFunctionName = "gui_start_mislist" })
}

::gui_start_benchmark <- function gui_start_benchmark() {
  if (isPlatformSony) {
    ::ps4_vsync_enabled = ::d3d_get_vsync_enabled()
    ::d3d_enable_vsync(false)
  }
  ::gui_start_mislist(true, GM_BENCHMARK)
}

::gui_start_tutorial <- function gui_start_tutorial() {
  ::gui_start_mislist(true, GM_TRAINING)
}

::is_custom_battles_enabled <- function is_custom_battles_enabled() { return ::enable_custom_battles }

::init_coop_flags <- function init_coop_flags() {
  ::enable_coop_in_QMB            = hasFeature(isPlatformSony ? "QmbCoopPs4"            : "QmbCoopPc")
  ::enable_coop_in_SingleMissions = hasFeature(isPlatformSony ? "SingleMissionsCoopPs4" : "SingleMissionsCoopPc")
  ::enable_custom_battles         = hasFeature(isPlatformSony ? "CustomBattlesPs4"      : "CustomBattlesPc")
  broadcastEvent("GameModesAvailability")
}

::get_mission_name <- function get_mission_name(missionId, config, locNameKey = "locName") {
  let locNameValue = getTblValue(locNameKey, config, null)
  if (locNameValue && locNameValue.len())
    return getMissionLocName(config, locNameKey)

  return loc("missions/" + missionId)
}

::loc_current_mission_name <- function loc_current_mission_name(needComment = true) {
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)
  let teamId = ::g_team.getTeamByCode(::get_player_army_for_hud()).id
  let locNameByTeamParamName = $"locNameTeam{teamId}"
  local ret = ""

  if ((misBlk?[locNameByTeamParamName].len() ?? 0) > 0)
    ret = getMissionLocName(misBlk, locNameByTeamParamName)
  else if ((misBlk?.locName.len() ?? 0) > 0)
    ret = getMissionLocName(misBlk, "locName")
  else if ((misBlk?.loc_name ?? "") != "")
    ret = loc("missions/" + misBlk.loc_name, "")
  if (ret == "")
    ret = ::get_combine_loc_name_mission(misBlk)
  if (needComment && (get_game_type() & GT_VERSUS)) {
    if (misBlk?.maxRespawns == 1)
      ret = ret + " " + loc("template/noRespawns")
    else if ((misBlk?.maxRespawns ?? 1) > 1)
      ret = ret + " " +
        loc("template/limitedRespawns/num/plural", { num = misBlk.maxRespawns })
  }
  return ret
}

::get_combine_loc_name_mission <- function get_combine_loc_name_mission(missionInfo) {
  let misInfoName = missionInfo?.name ?? ""
  local locName = ""
  if ((missionInfo?["locNameTeamA"].len() ?? 0) > 0)
    locName = getMissionLocName(missionInfo, "locNameTeamA")
  else if ((missionInfo?.locName.len() ?? 0) > 0)
    locName = getMissionLocName(missionInfo, "locName")
  else
    locName = loc("missions/" + misInfoName, "")

  if (locName == "") {
    let misInfoPostfix = missionInfo?.postfix ?? ""
    if (misInfoPostfix != "" && misInfoName.indexof(misInfoPostfix)) {
      let name = misInfoName.slice(0, misInfoName.indexof(misInfoPostfix))
      locName = "[" + loc("missions/" + misInfoPostfix) + "] " + loc("missions/" + name)
    }
  }

  //we dont have lang and postfix
  if (locName == "")
    locName = "missions/" + misInfoName
  return locName
}

::loc_current_mission_desc <- function loc_current_mission_desc() {
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)
  let teamId = ::g_team.getTeamByCode(::get_player_army_for_hud()).id
  let locDecsByTeamParamName = $"locDescTeam{teamId}"

  local locDesc = ""
  if ((misBlk?[locDecsByTeamParamName].len() ?? 0) > 0)
    locDesc = getMissionLocName(misBlk, locDecsByTeamParamName)
  else if ((misBlk?.locDesc.len() ?? 0) > 0)
    locDesc = getMissionLocName(misBlk, "locDesc")
  else {
    local missionLocName = misBlk.name
    if ("loc_name" in misBlk && misBlk.loc_name != "")
      missionLocName = misBlk.loc_name
    locDesc = loc("missions/" + missionLocName + "/desc", "")
  }
  if (get_game_type() & GT_VERSUS) {
    if (misBlk.maxRespawns == 1) {
      if (get_game_mode() != GM_DOMINATION)
        locDesc = locDesc + "\n\n" + loc("template/noRespawns/desc")
    }
    else if ((misBlk.maxRespawns != null) && (misBlk.maxRespawns > 1))
      locDesc = locDesc + "\n\n" + loc("template/limitedRespawns/desc")
  }
  return locDesc
}

return {
  needCheckForVictory
  getUrlOrFileMissionMetaInfo
}
