import "%scripts/matchingRooms/destroySessionScripted.nut" as destroySessionScripted
from "%scripts/slotbar/playerCurUnit.nut" import getPlayerCurUnit
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_TRAINING, USEROPT_AIRCRAFT, USEROPT_WEAPONS, USEROPT_SKIN
from "%scripts/clientState/localProfileDeprecated.nut" import loadLocalByAccount, saveLocalByAccount
from "%scripts/myStats.nut" import getPvpRespawnsOnUnitType, isStatsLoaded
from "%scripts/missions/startMissionsList.nut" import guiStartFlight
from "%scripts/missions/missionsStates.nut" import currentCampaignMission
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameMode
from "%scripts/slotbar/crewsList.nut" import getCrewsListByCountry
from "%scripts/crew/crew.nut" import getCrewUnit
from "%scripts/user/playerCountry.nut" import profileCountrySq
from "%scripts/weaponry/unitForWeapons.nut" import unitNameForWeapons
from "%scripts/weaponry/weaponryActions.nut" import enable_current_modifications, updateBulletCountOptions
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "chard" import save_profile
from "guiMission" import get_meta_mission_info_by_name, select_training_mission
from "mission" import set_game_mode
from "guiOptions" import set_gui_option, setGuiOptionsMode
from "%scripts/dagui_natives.nut" import enable_bullets_modifications
from "%globalScripts/unitTypeConsts.nut" import *
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let UnitBulletsManager = require("%scripts/weaponry/unitBulletsManager.nut")

let esUnitTypeMisNameMap = {
  [ES_UNIT_TYPE_BOAT] = ["tutorial_boat_battle_arcade_part1"],
  [ES_UNIT_TYPE_SHIP] = ["tutorial_destroyer_battle_arcade_part1"]
}

function getNextTutorialMissionParams(unit) {
  let res = {
    misName = null
    hasLaunches = false
  }

  if (unit.esUnitType not in esUnitTypeMisNameMap)
    return res

  foreach(mName in esUnitTypeMisNameMap[unit.esUnitType]) {
    let hasLaunched = loadLocalByAccount($"tutor/mission_launched_{mName}", false)
    res.misName = mName
    res.hasLaunches = hasLaunched
    if (!hasLaunched) {
      break
    }
  }
  return res
}

function isGmForUnitType(esUnitType) {
  let gameMode = getCurrentGameMode()
  return gameMode?.reqUnitTypes.contains(esUnitType) ?? false
}

function findUnitInSlotByType(esUnitType) {
  let crews = getCrewsListByCountry(profileCountrySq.get())
  let curUnit = getPlayerCurUnit()
  let units = crews.map(@(c) getCrewUnit(c))
    .filter(@(u) u?.esUnitType == esUnitType)
  return units.contains(curUnit) ? curUnit : units?[0]
}

function getFleetTrainingMissionName() {
  if (!isStatsLoaded() || !isProfileReceived.get())
    return null

  local unit = getPlayerCurUnit()
  if (!unit || !unit.isShipOrBoat())
    unit = findUnitInSlotByType(ES_UNIT_TYPE_SHIP) ?? findUnitInSlotByType(ES_UNIT_TYPE_BOAT)

  if (!unit)
    return null

  let { misName, hasLaunches } = getNextTutorialMissionParams(unit)
  if (misName == null || hasLaunches)
    return null

  let hasRespawns = getPvpRespawnsOnUnitType(unit.esUnitType) > 0
  if (hasRespawns)
    return null

  if (!isGmForUnitType(unit.esUnitType))
    return null

  let misBlk = get_meta_mission_info_by_name(misName)
  if (!misBlk || (("reqFeature" in misBlk) && !hasFeature(misBlk.reqFeature)))
    return null

  return misName
}

function startFleetTrainingMission(misName) {
  local unit = getPlayerCurUnit()
  if (!unit || !unit.isShipOrBoat())
    unit = findUnitInSlotByType(ES_UNIT_TYPE_SHIP) ?? findUnitInSlotByType(ES_UNIT_TYPE_BOAT)

  if (!unit)
    return

  if (!isGmForUnitType(unit.esUnitType))
    return

  destroySessionScripted($"on startFleetTrainingMission")

  set_game_mode(GM_TRAINING)
  setGuiOptionsMode(OPTIONS_MODE_TRAINING)

  let unitName = unit.name
  unitNameForWeapons.set(unitName)
  set_gui_option(USEROPT_AIRCRAFT, unitName)
  set_gui_option(USEROPT_WEAPONS, "")
  set_gui_option(USEROPT_SKIN, "default")
  updateBulletCountOptions(unit, UnitBulletsManager(unit).getBulletsGroups())

  enable_bullets_modifications(unitName)
  enable_current_modifications(unitName)

  currentCampaignMission.set(misName)
  let misBlk = get_meta_mission_info_by_name(misName)
  select_training_mission(misBlk)
  guiStartFlight()

  saveLocalByAccount($"tutor/mission_launched_{misName}", true)
  save_profile(false)
}

return {
  startFleetTrainingMission
  getFleetTrainingMissionName
  fleetTrainingMissionMap = esUnitTypeMisNameMap
}
