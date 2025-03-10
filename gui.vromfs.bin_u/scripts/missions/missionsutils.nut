from "%scripts/dagui_natives.nut" import add_last_played, get_player_army_for_hud, has_entitlement, map_to_location
from "%scripts/dagui_library.nut" import *

let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let DataBlock = require("DataBlock")
let { getBlkValueByPath, blkOptFromPath } = require("%sqstd/datablock.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isMissionComplete } = require("%scripts/missions/missionsUtilsModule.nut")
let { getMissionTimeText, getWeatherLocName } = require("%scripts/missions/missionsText.nut")
let { get_meta_missions_info_by_campaigns, add_custom_mission_list_full,
  get_current_mission_desc, get_meta_missions_info } = require("guiMission")
let { get_game_mode, get_game_type, get_current_mission_name } = require("mission")
let { getEsUnitType, findUnitNoCase } = require("%scripts/unit/unitParams.nut")
let { getDynamicLayoutsBlk } = require("dynamicMission")
let { g_mislist_type } = require("%scripts/missions/misListType.nut")
let regexp2 = require("regexp2")
let { currentCampaignMission } = require("%scripts/missions/missionsStates.nut")
let { measureType } = require("%scripts/measureType.nut")

const COOP_MAX_PLAYERS = 4

let dynamicLayouts = persist("dynamicLayouts", @() [])
let gameModeMaps = persist("gameModeMaps", @() [])
let campaignNames = []

let canPlayGamemodeBySquad = @(gm) !g_squad_manager.isNotAloneOnline()
  || gm == GM_SINGLE_MISSION || gm == GM_SKIRMISH



function getMaxPlayersForGamemode(gm) {
  if (isInArray(gm, [GM_SINGLE_MISSION, GM_DYNAMIC, GM_BUILDER]))
    return COOP_MAX_PLAYERS
  return 0
}

function isSkirmishWithKillStreaks(misBlk) {
  return misBlk.getBool("allowedKillStreaks", false);
}

function hasUnitInFullMissionBlk(fullMissionBlk, esUnitType) {
  
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
            unitsCache[block.unit_class] <- getEsUnitType(findUnitNoCase(block.unit_class))
          if (unitsCache[block.unit_class] == esUnitType)
            return true
        }
    }

  
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

function isMissionForUnitType(misBlk, esUnitType, useKillStreaks = null) {
  let unitType = unitTypes.getByEsUnitType(esUnitType)

  
  if (unitType.missionSettingsAvailabilityFlag in misBlk)
    return unitType.isAvailableByMissionSettings(misBlk, useKillStreaks)

  
  local fullMissionBlk = null
  let url = getTblValue("url", misBlk)
  if (url != null)
    fullMissionBlk = getTblValue("fullMissionBlk", g_url_missions.findMissionByUrl(url))
  else
    fullMissionBlk = blkOptFromPath(misBlk?.mis_file)
  return hasUnitInFullMissionBlk(fullMissionBlk, esUnitType)
}

function getMissionAllowedUnittypesMask(misBlk, useKillStreaks = null) {
  local res = 0
  foreach (unitType in unitTypes.types)
    if (unitType.isAvailable() && isMissionForUnitType(misBlk, unitType.esUnitType, useKillStreaks))
      res = res | unitType.bit
  return res
}

function selectNextAvailCampaignMission(chapterName, missionName) {
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

function addMissionListFull(gm_builder, add, dynlist) {
  add_custom_mission_list_full(gm_builder, add, dynlist)
  gameModeMaps.clear()
}

function cacheCampaignNames() {
  if (campaignNames.len() > 0)
    return
  let mbc = get_meta_missions_info_by_campaigns(GM_CAMPAIGN)
  foreach (item in mbc)
    campaignNames.append(item.name)
}

function isAnyCampaignAvailable() {
  cacheCampaignNames()
  return campaignNames.findvalue(@(name) has_entitlement(name) || hasFeature(name)) != null
}

function getNotPurchasedCampaigns() {
  cacheCampaignNames()
  return campaignNames.filter(@(name) !has_entitlement(name) && !hasFeature(name))
}

function getMissionCondition(misBlk) {
  let condition = []
  let timeText = misBlk.getStr("time", misBlk.getStr("environment", ""))
  if (timeText != "")
    condition.append(getMissionTimeText(timeText))
  let weatherText = misBlk.getStr("weather", "")
  if (weatherText != "")
    condition.append(getWeatherLocName(weatherText))
  let temperature = misBlk?.temperature ?? 0
  if (temperature != 0)
    condition.append(measureType.TEMPERATURE.getMeasureUnitsText(temperature))
  let pressure = misBlk?.pressure ?? 0
  if (pressure != 0)
    condition.append(measureType.MM_HG.getMeasureUnitsText(pressure))
  let altitude = misBlk?.altitude ?? 0
  if (altitude != 0)
    condition.append("".concat(loc("options/altitude_baro"), loc("ui/colon"),
      measureType.ALTITUDE.getMeasureUnitsText(altitude)))
  return condition
}

function setMissionEnviroment(obj) {
  if (!(obj?.isValid() ?? false))
    return
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)
  let condition = getMissionCondition(misBlk)
  if (condition.len() == 0) {
    obj.setValue("")
    return
  }

  obj.setValue(loc("ui/colon").concat(loc("sm_conditions"),
    loc("ui/comma").join(condition.map(@(v) colorize("activeTextColor", v)))))
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

function getMissionLocaltionAndConditionText(blk) {
  local conditionText = ""
  let currentCampMission = currentCampaignMission.get() ?? ""
  if (currentCampMission != "")
    conditionText = loc($"missions/{currentCampMission}/condition", "")

  if (conditionText == "" && !(get_game_type() & GT_VERSUS)) {
    let condition = getMissionCondition(blk)
    let locationText = blk.getStr("locationName", map_to_location(blk.getStr("level", "")))
    if (locationText != "")
      condition.insert(0, loc($"location/{locationText}"))
    conditionText = "; ".join(condition)
  }

  if (conditionText != "")
    conditionText = "".concat(loc("sm_conditions"), loc("ui/colon"), " ", conditionText)

  return conditionText
}


let isMissionExtrByName = @(misName = "") regexp2(@"_extr$").match(misName)
let isMissionExtr = @() isMissionExtrByName(get_current_mission_name())

return {
  isMissionComplete
  setMissionEnviroment
  getGameModeMaps
  getDynamicLayouts
  clearMapsCache
  isMissionExtr
  isMissionExtrByName
  selectNextAvailCampaignMission
  getMissionLocaltionAndConditionText
  getNotPurchasedCampaigns
  isAnyCampaignAvailable
  addMissionListFull
  hasUnitInFullMissionBlk
  isMissionForUnitType
  getMissionAllowedUnittypesMask
  isSkirmishWithKillStreaks
  getMaxPlayersForGamemode
  canPlayGamemodeBySquad
}