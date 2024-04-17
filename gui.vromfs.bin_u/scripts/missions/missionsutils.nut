from "%scripts/dagui_natives.nut" import add_last_played, get_player_army_for_hud, get_game_mode_name, has_entitlement
from "%scripts/dagui_library.nut" import *

let { g_team } = require("%scripts/teams.nut")
let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let DataBlock = require("DataBlock")
let { format } = require("string")
let { getBlkValueByPath, blkOptFromPath } = require("%sqstd/datablock.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getMissionLocName, isMissionComplete, getCombineLocNameMission } = require("%scripts/missions/missionsUtilsModule.nut")
let { get_meta_mission_info_by_name, get_meta_missions_info_by_campaigns,
  add_custom_mission_list_full, get_meta_mission_info_by_gm_and_name,
  get_current_mission_desc, get_meta_missions_info } = require("guiMission")
let { get_game_mode, get_game_type, get_current_mission_name } = require("mission")
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")
let { isStringInteger, isStringFloat, toUpper } = require("%sqstd/string.nut")
let { getDynamicLayoutsBlk } = require("dynamicMission")
let { g_mislist_type } = require("%scripts/missions/misListType.nut")
let regexp2 = require("regexp2")

const COOP_MAX_PLAYERS = 4

let dynamicLayouts = persist("dynamicLayouts", @() [])
let gameModeMaps = persist("gameModeMaps", @() [])
let campaignNames = []

let customWeatherLocIds = {
  thin_clouds = "options/weatherthinclouds"
  thunder = "options/weatherstorm"
}

let getWeatherLocName = @(weather)
  loc(customWeatherLocIds?[weather] ?? $"options/weather{weather}")

let canPlayGamemodeBySquad = @(gm) !g_squad_manager.isNotAloneOnline()
  || gm == GM_SINGLE_MISSION || gm == GM_SKIRMISH

::can_play_gamemode_by_squad <- canPlayGamemodeBySquad

//return 0 when no limits
::get_max_players_for_gamemode <- function get_max_players_for_gamemode(gm) {
  if (isInArray(gm, [GM_SINGLE_MISSION, GM_DYNAMIC, GM_BUILDER]))
    return COOP_MAX_PLAYERS
  return 0
}

::get_game_mode_loc_name <- function get_game_mode_loc_name(gm) {
  return loc(format("multiplayer/%sMode", get_game_mode_name(gm)))
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
    fullMissionBlk = getTblValue("fullMissionBlk", g_url_missions.findMissionByUrl(url))
  else
    fullMissionBlk = blkOptFromPath(misBlk?.mis_file)
  return ::has_unittype_in_full_mission_blk(fullMissionBlk, esUnitType)
}

::has_unittype_in_full_mission_blk <- function has_unittype_in_full_mission_blk(fullMissionBlk, esUnitType) {
  // Searching by units of Single missions
  let unitsBlk = fullMissionBlk?.units
  let playerBlk = fullMissionBlk && getBlkValueByPath(fullMissionBlk, "mission_settings/player")
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

      add_last_played(mission?.chapter, mission?.id, GM_CAMPAIGN, false)
      break
    }

  }
 g_mislist_type.BASE.requestMissionsList(true, callback)
}

::buildRewardText <- function buildRewardText(name, reward, highlighted = false, _coloredIcon = false, additionalReward = false) {
  local rewText = reward.tostring()
  if (rewText != "") {
    if (highlighted)
      rewText = colorize("highlightedTextColor", additionalReward ? $"+({rewText})" : rewText)
    rewText = "".concat(name, name != "" ? loc("ui/colon") : "", rewText)
  }
  return rewText
}

::add_mission_list_full <- function add_mission_list_full(gm_builder, add, dynlist) {
  add_custom_mission_list_full(gm_builder, add, dynlist)
  gameModeMaps.clear()
}

function getUrlOrFileMissionMetaInfo(missionName, gm = null) {
  let urlMission = g_url_missions.findMissionByName(missionName)
  if (urlMission != null)
    return urlMission.getMetaInfo()

  if (gm != null) {
    let misBlk = get_meta_mission_info_by_gm_and_name(gm, missionName)
    if (misBlk != null)
      return misBlk
  }

  return get_meta_mission_info_by_name(missionName)
}

function cacheCampaignNames() {
  if (campaignNames.len() > 0)
    return
  let mbc = get_meta_missions_info_by_campaigns(GM_CAMPAIGN)
  foreach (item in mbc)
    campaignNames.append(item.name)
}

::is_any_campaign_available <- function is_any_campaign_available() {
  cacheCampaignNames()
  return campaignNames.findvalue(@(name) has_entitlement(name) || hasFeature(name)) != null
}

::get_not_purchased_campaigns <- function get_not_purchased_campaigns() {
  cacheCampaignNames()
  return campaignNames.filter(@(name) !has_entitlement(name) && !hasFeature(name))
}

::get_mission_name <- function get_mission_name(missionId, config, locNameKey = "locName") {
  let locNameValue = getTblValue(locNameKey, config, null)
  if (locNameValue && locNameValue.len())
    return getMissionLocName(config, locNameKey)

  return loc($"missions/{missionId}")
}

function locCurrentMissionName(needComment = true) {
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)
  let teamId = g_team.getTeamByCode(get_player_army_for_hud()).id
  let locNameByTeamParamName = $"locNameTeam{teamId}"
  local ret = ""

  if ((misBlk?[locNameByTeamParamName].len() ?? 0) > 0)
    ret = getMissionLocName(misBlk, locNameByTeamParamName)
  else if ((misBlk?.locName.len() ?? 0) > 0)
    ret = getMissionLocName(misBlk, "locName")
  else if ((misBlk?.loc_name ?? "") != "")
    ret = loc($"missions/{misBlk.loc_name}", "")
  if (ret == "")
    ret = getCombineLocNameMission(misBlk)
  if (needComment && (get_game_type() & GT_VERSUS)) {
    if (misBlk?.maxRespawns == 1)
      ret = "".concat(ret, " ", loc("template/noRespawns"))
    else if ((misBlk?.maxRespawns ?? 1) > 1)
      ret = "".concat(ret, " ",
        loc("template/limitedRespawns/num/plural", { num = misBlk.maxRespawns }))
  }
  return ret
}

::loc_current_mission_desc <- function loc_current_mission_desc() {
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)
  let teamId = g_team.getTeamByCode(get_player_army_for_hud()).id
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
    locDesc = loc($"missions/{missionLocName}/desc", "")
  }
  if (get_game_type() & GT_VERSUS) {
    if (misBlk.maxRespawns == 1) {
      if (get_game_mode() != GM_DOMINATION)
        locDesc = "".concat(locDesc, "\n\n", loc("template/noRespawns/desc"))
    }
    else if ((misBlk.maxRespawns != null) && (misBlk.maxRespawns > 1))
      locDesc = "".concat(locDesc, "\n\n", loc("template/limitedRespawns/desc"))
  }
  return locDesc
}

function getMissionTimeText(missionTime) {
  if (isStringInteger(missionTime))
    return format("%d:00", missionTime.tointeger())
  if (isStringFloat(missionTime))
    missionTime = missionTime.replace(".", ":")
  return loc($"options/time{toUpper(missionTime, 1)}")
}

function setMissionEnviroment(obj) {
  if (!(obj?.isValid() ?? false))
    return
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)
  let time = misBlk?.time ?? misBlk?.environment ?? ""
  let weather = misBlk?.weather ?? ""
  if (time == "" && weather == "") {
    obj.setValue("")
    return
  }
  let cond = []
  if (time != "")
    cond.append(colorize("activeTextColor", getMissionTimeText(time)))
  if (weather != "")
    cond.append(colorize("activeTextColor", getWeatherLocName(weather)))
  obj.setValue(loc("ui/colon").concat(loc("sm_conditions"), loc("ui/comma").join(cond, true)))
}

function getGameModeMaps() {
  if (gameModeMaps.len())
    return gameModeMaps

  for (local modeNo = 0; modeNo < GM_COUNT; ++modeNo) {
    let mi = get_meta_missions_info(modeNo)

    let modeMap = {
      items = []
      values = []
      coop = []
    }
    for (local i = 0; i < mi.len(); ++i) {
      let blkMap = mi[i]
      let misId = blkMap.getStr("name", "")
      modeMap.values.append(misId)
      modeMap.items.append($"#missions/{misId}")
      modeMap.coop.append(blkMap.getBool("gt_cooperative", false))
    }
    gameModeMaps.append(modeMap)
  }

  return gameModeMaps
}

function getDynamicLayouts() {
  if (dynamicLayouts.len())
    return dynamicLayouts

  let dblk = getDynamicLayoutsBlk()
  for (local i = 0; i < dblk.blockCount(); i++) {
    let info = {
      mis_file = dblk.getBlock(i).getStr("mis_file", "")
      name = dblk.getBlock(i).getStr("name", "")
    }
    dynamicLayouts.append(info)
  }

  return dynamicLayouts
}

function clearMapsCache() {
  gameModeMaps.clear()
  dynamicLayouts.clear()
}

// first april 2024
let isMissionExtrByName = @(misName = "") regexp2(@"_extr$").match(misName)
let isMissionExtr = @() isMissionExtrByName(get_current_mission_name())

return {
  getUrlOrFileMissionMetaInfo
  isMissionComplete
  getCombineLocNameMission
  locCurrentMissionName
  getMissionTimeText
  getWeatherLocName
  setMissionEnviroment
  getGameModeMaps
  getDynamicLayouts
  clearMapsCache
  isMissionExtr
  isMissionExtrByName
}