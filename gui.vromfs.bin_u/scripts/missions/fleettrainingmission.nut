from "%scripts/dagui_natives.nut" import save_profile, enable_bullets_modifications
from "%scripts/dagui_library.nut" import *
let { get_meta_mission_info_by_name, select_training_mission } = require("guiMission")
let { set_game_mode } = require("mission")
let { set_unit_option, set_gui_option, setGuiOptionsMode } = require("guiOptions")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { set_option } = require("%scripts/options/optionsExt.nut")
let { OPTIONS_MODE_TRAINING, USEROPT_BULLETS0, USEROPT_BULLET_COUNT0,
  USEROPT_AIRCRAFT, USEROPT_WEAPONS, USEROPT_SKIN
} = require("%scripts/options/optionsExtNames.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { getPvpRespawnsOnUnitType, isStatsLoaded } = require("%scripts/myStats.nut")
let { guiStartFlight, setCurrentCampaignMission } = require("%scripts/missions/startMissionsList.nut")
let { getCurrentGameMode } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/slotbarState.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

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
  if (!isStatsLoaded() || !::g_login.isProfileReceived())
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

function updateBulletCountOptions(unit) {
  local bulIdx = 0
  let bulletsManager = ::UnitBulletsManager(unit)
  let bulletGroups = bulletsManager.getBulletsGroups()
  foreach (idx, bulGroup in bulletGroups) {
    bulIdx = idx
    let name = bulGroup.active ? bulGroup.getBulletNameForCode(bulGroup.selectedName) : ""
    let count = bulGroup.active ? (bulGroup.bulletsCount * bulGroup.guns) : 0
    set_option(USEROPT_BULLETS0 + bulIdx, name)
    set_unit_option(unit.name, USEROPT_BULLETS0 + bulIdx, name)
    set_gui_option(USEROPT_BULLET_COUNT0 + bulIdx, count)
  }
  ++bulIdx

  while (bulIdx < BULLETS_SETS_QUANTITY) {
    set_option(USEROPT_BULLETS0 + bulIdx, "")
    set_unit_option(unit.name, USEROPT_BULLETS0 + bulIdx, "")
    set_gui_option(USEROPT_BULLET_COUNT0 + bulIdx, 0)
    ++bulIdx
  }
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

  ::update_test_flight_unit_info({ unit })
  ::cur_aircraft_name = unit.name
  ::aircraft_for_weapons = unit.name
  set_gui_option(USEROPT_AIRCRAFT, unit.name)
  set_gui_option(USEROPT_WEAPONS, "")
  set_gui_option(USEROPT_SKIN, "default")
  updateBulletCountOptions(unit)

  enable_bullets_modifications(::aircraft_for_weapons)
  ::enable_current_modifications(::aircraft_for_weapons)

  setCurrentCampaignMission(misName)
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