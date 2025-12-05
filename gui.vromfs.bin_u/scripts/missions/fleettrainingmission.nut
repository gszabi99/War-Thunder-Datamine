from "%scripts/dagui_natives.nut" import enable_bullets_modifications
from "%scripts/dagui_library.nut" import *
let { save_profile } = require("chard")
let { get_meta_mission_info_by_name, select_training_mission } = require("guiMission")
let { set_game_mode } = require("mission")
let { set_gui_option, setGuiOptionsMode } = require("guiOptions")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { OPTIONS_MODE_TRAINING, USEROPT_AIRCRAFT, USEROPT_WEAPONS, USEROPT_SKIN
} = require("%scripts/options/optionsExtNames.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { getPvpRespawnsOnUnitType, isStatsLoaded } = require("%scripts/myStats.nut")
let { guiStartFlight } = require("%scripts/missions/startMissionsList.nut")
let { currentCampaignMission } = require("%scripts/missions/missionsStates.nut")
let { getCurrentGameMode } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { enable_current_modifications, updateBulletCountOptions } = require("%scripts/weaponry/weaponryActions.nut")
let destroySessionScripted = require("%scripts/matchingRooms/destroySessionScripted.nut")

let UnitBulletsManager = require("%scripts/weaponry/unitBulletsManager.nut")

let esUnitTypeMisNameMap = {
  [ES_UNIT_TYPE_BOAT] = ["tutorial_boat_battle_arcade_part1", "tutorial_boat_battle_arcade_part2"],
  [ES_UNIT_TYPE_SHIP] = ["tutorial_destroyer_battle_arcade_part1", "tutorial_destroyer_battle_arcade_part2"]
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
}