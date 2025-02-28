from "%scripts/dagui_natives.nut" import save_profile, enable_bullets_modifications
from "%scripts/dagui_library.nut" import *
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
let { getCrewsListByCountry } = require("%scripts/slotbar/slotbarState.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { enable_current_modifications } = require("%scripts/weaponry/weaponryActions.nut")

let esUnitTypeMisNameMap = {
  [ES_UNIT_TYPE_SHIP] = "tutorial_destroyer_battle_arcade",
  [ES_UNIT_TYPE_BOAT] = "tutorial_boat_battle_arcade",
}

function isGmForUnitType(esUnitType) {
  let gameMode = getCurrentGameMode()
  return gameMode?.reqUnitTypes.contains(esUnitType) ?? false
}

function findUnitInSlotByType(esUnitType) {
  let crews = getCrewsListByCountry(profileCountrySq.value)
  let curUnit = getPlayerCurUnit()
  let units = crews.map(@(c) getCrewUnit(c))
    .filter(@(u) u?.esUnitType == esUnitType)
  return units.contains(curUnit) ? curUnit : units?[0]
}

function canStartFleetTrainingMission() {
  if (!isStatsLoaded() || !isProfileReceived.get())
    return false

  local unit = getPlayerCurUnit()
  if (!unit || !unit.isShipOrBoat())
    unit = findUnitInSlotByType(ES_UNIT_TYPE_SHIP) ?? findUnitInSlotByType(ES_UNIT_TYPE_BOAT)

  if (!unit)
    return

  let misName = esUnitTypeMisNameMap?[unit.esUnitType]
  if (misName == null)
    return

  let hasLaunches = loadLocalByAccount($"tutor/mission_launched_{misName}", false)
  if (hasLaunches)
    return false

  let hasRespawns = getPvpRespawnsOnUnitType(unit.esUnitType) > 0
  if (hasRespawns)
    return false

  if (!isGmForUnitType(unit.esUnitType))
    return false

  let misBlk = get_meta_mission_info_by_name(misName)
  if (!misBlk || (("reqFeature" in misBlk) && !hasFeature(misBlk.reqFeature)))
    return false

  return true
}

function startFleetTrainingMission() {
  local unit = getPlayerCurUnit()
  if (!unit || !unit.isShipOrBoat())
    unit = findUnitInSlotByType(ES_UNIT_TYPE_SHIP) ?? findUnitInSlotByType(ES_UNIT_TYPE_BOAT)

  if (!unit)
    return

  if (!isGmForUnitType(unit.esUnitType))
    return

  let misName = esUnitTypeMisNameMap?[unit.esUnitType]
  if (misName == null)
    return

  ::destroy_session_scripted($"on startFleetTrainingMission")

  set_game_mode(GM_TRAINING)
  setGuiOptionsMode(OPTIONS_MODE_TRAINING)

  let unitName = unit.name
  unitNameForWeapons.set(unitName)
  set_gui_option(USEROPT_AIRCRAFT, unitName)
  set_gui_option(USEROPT_WEAPONS, "")
  set_gui_option(USEROPT_SKIN, "default")
  ::UnitBulletsManager(unit).updateBulletCountOptions()

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
  canStartFleetTrainingMission
}