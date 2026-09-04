import "DataBlock" as DataBlock
import "regexp2" as regexp2
from "%sqstd/datablock.nut" import getBlkValueByPath, blkOptFromPath, blkFromPath
from "guiMission" import get_meta_missions_info_by_campaigns, add_custom_mission_list_full, get_current_mission_desc, get_meta_missions_info
from "mission" import get_game_mode, get_game_type, get_current_mission_name
from "dynamicMission" import getDynamicLayoutsBlk
from "%globalScripts/gameTypeConsts.nut" import *
from "%scripts/dagui_natives.nut" import add_last_played, has_entitlement, map_to_location
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")
let { isNotAloneOnline } = require("%scripts/squads/squadState.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isMissionComplete } = require("%scripts/missions/missionsUtilsModule.nut")
let { getMissionTimeText, getWeatherLocName } = require("%scripts/missions/missionsText.nut")
let { getEsUnitType, findUnitNoCase } = require("%scripts/unit/unitParams.nut")
let { g_mislist_type } = require("%scripts/missions/misListType.nut")
let { currentCampaignMission } = require("%scripts/missions/missionsStates.nut")
let { measureType } = require("%scripts/measureType.nut")

const COOP_MAX_PLAYERS = 4

let dynamicLayouts = persist("dynamicLayouts", @() [])
let gameModeMaps = persist("gameModeMaps", @() [])
let campaignNames = []

let canPlayGamemodeBySquad = @(gm) !isNotAloneOnline()
  || gm == GM_SINGLE_MISSION || gm == GM_SKIRMISH


function getMaxPlayersForGamemode(gm) {
  if (isInArray(gm, [GM_SINGLE_MISSION, GM_DYNAMIC, GM_BUILDER]))
    return COOP_MAX_PLAYERS
  return 0
}

function isSkirmishWithKillStreaks(misBlk) {
  return misBlk.getBool("allowedKillStreaks", false);
}

function hasUnitInFullMissionBlk(fullMissionBlk, unitType) {
  
  let { esUnitType } = unitType
  let unitsBlk = fullMissionBlk?.units
  let playerBlk = fullMissionBlk && getBlkValueByPath(fullMissionBlk, "mission_settings/player")
  let wings = playerBlk ? (playerBlk % "wing") : []
  let unitsCache = {}
  if (unitsBlk && wings.len())
    for (local i = 0; i < unitsBlk.blockCount(); i++) {
      let block = unitsBlk.getBlock(i)
      if (isInArray(block?.name, wings)) {
        let { unit_class = null } = block
        if (unit_class) {
          if (unit_class in unitsCache)
            continue

          unitsCache[unit_class] <- true
          let curEsUnitType = getEsUnitType(findUnitNoCase(unit_class))
          if (curEsUnitType == esUnitType)
            return true
        }
      }
    }

  
  let tag = unitType.tag
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

function getFullMissionBlkFromMisBlk(misBlk) {
  let url = misBlk?.url
  if (url != null)
    return g_url_missions.findMissionByUrl(url)?.fullMissionBlk
  return blkOptFromPath(misBlk?.mis_file)
}

function getFullMissionBlk(misBlk, unitType, fullMissionBlk) {
  if (fullMissionBlk != null)
    return fullMissionBlk
  if (unitType.missionSettingsAvailabilityFlag in misBlk)
    return null
  return getFullMissionBlkFromMisBlk(misBlk)
}

function isMissionForUnitType(misBlk, esUnitType, useKillStreaks = null, fullMissionBlk = null) {
  let unitType = unitTypes.getByEsUnitType(esUnitType)

  
  if (unitType.missionSettingsAvailabilityFlag in misBlk)
    return unitType.isAvailableByMissionSettings(misBlk, useKillStreaks)

  
  fullMissionBlk = getFullMissionBlk(misBlk, unitType, fullMissionBlk)
  return hasUnitInFullMissionBlk(fullMissionBlk, unitType)
}

function getMissionAllowedUnittypesMask(misBlk, useKillStreaks = null) {
  local res = 0
  local fullMissionBlk = null
  foreach (unitType in unitTypes.types) {
    if (!unitType.isAvailable())
      continue
    fullMissionBlk = getFullMissionBlk(misBlk, unitType, fullMissionBlk)

    if (isMissionForUnitType(misBlk, unitType.esUnitType, useKillStreaks, fullMissionBlk))
      res = res | unitType.bit
  }
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

let BAD_WEATHER_CONDITIONS = ["mist", "poor", "blind", "overcast", "rain", "thunder", "cloudy_windy"]

function isMissionWithBadWeatherConditions(missionBlk) {
  let weatherText = missionBlk?.weather ?? ""
  if (!weatherText.len())
    return false

  return BAD_WEATHER_CONDITIONS.contains(weatherText)
}

function getBadWeatherTooltipText(isBadWeather, hasAirfield, isSpawnAutoChanged = false) {
  if (!isBadWeather)
    return ""
  const locKey = "bad_weather_conditions"
  local tText = loc($"{locKey}/{hasAirfield ? "long" : "short"}")
  if (isSpawnAutoChanged)
    tText = "\n".concat(tText, loc($"{locKey}/airfiled_changed"))
  return tText
}

function setMissionEnviroment(obj, missionBlk = null) {
  if (!(obj?.isValid() ?? false))
    return
  local misBlk = null
  if (missionBlk)
    misBlk = missionBlk
  else {
    misBlk = DataBlock()
    get_current_mission_desc(misBlk)
  }
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

let levelMapBackgroundColors = {}

function getLevelMapBackgroundColors(levelName) {
  if (levelName in levelMapBackgroundColors)
    return levelMapBackgroundColors[levelName]

  let res = {
    customMapBackColorInBriefing = ""
    customMapBackColor = ""
  }
  if (levelName == "")
    return res
  let levelBlk = blkFromPath($"{levelName.slice(0, -3)}blk")
  res.customMapBackColorInBriefing = levelBlk?.customMapBackColorInBriefing ?? ""
  res.customMapBackColor = levelBlk?.customMapBackColor ?? ""

  levelMapBackgroundColors[levelName] <- res
  return res
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
  isMissionWithBadWeatherConditions
  getBadWeatherTooltipText
  getLevelMapBackgroundColors
}