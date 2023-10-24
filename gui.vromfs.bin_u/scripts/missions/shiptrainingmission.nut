from "%scripts/dagui_library.nut" import *
let { get_meta_mission_info_by_name, select_training_mission } = require("guiMission")
let { set_game_mode } = require("mission")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { set_unit_option, set_gui_option, setGuiOptionsMode } = require("guiOptions")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { set_option } = require("%scripts/options/optionsExt.nut")
let { OPTIONS_MODE_TRAINING, USEROPT_BULLETS0, USEROPT_BULLET_COUNT0,
  USEROPT_AIRCRAFT, USEROPT_WEAPONS, USEROPT_SKIN
} = require("%scripts/options/optionsExtNames.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfile.nut")

const MIS_NAME = "tutorial_destroyer_battle_arcade"

let function isGmForUnitType(esUnitType) {
  let gameMode = ::game_mode_manager.getCurrentGameMode()
  return gameMode?.reqUnitTypes.contains(esUnitType) ?? false
}

let function findUnitInSlotByType(esUnitType) {
  let crews = ::get_crews_list_by_country(profileCountrySq.value)
  let curUnit = getPlayerCurUnit()
  let units = crews.map(@(c) ::g_crew.getCrewUnit(c))
    .filter(@(u) u?.esUnitType == esUnitType)
  return units.contains(curUnit) ? curUnit : units?[0]
}

let isUnitTypeInSlot = @(esUnitType) findUnitInSlotByType(esUnitType) != null

let function canStartShipTrainingMission() {
  if (!::my_stats.isStatsLoaded() || !::g_login.isProfileReceived())
    return false

  let hasLaunches = loadLocalByAccount($"tutor/mission_launched_{MIS_NAME}", false)
  if (hasLaunches)
    return false

  let hasRespawns = ::my_stats.getPvpRespawnsOnUnitType(ES_UNIT_TYPE_SHIP) > 0
  if (hasRespawns)
    return false

  if (!isGmForUnitType(ES_UNIT_TYPE_SHIP) || !isUnitTypeInSlot(ES_UNIT_TYPE_SHIP))
    return false

  let misBlk = get_meta_mission_info_by_name(MIS_NAME)
  if (!misBlk || (("reqFeature" in misBlk) && !hasFeature(misBlk.reqFeature)))
    return false

  return true
}

let function updateBulletCountOptions(unit) {
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

let function startShipTrainingMission() {
  let unit = findUnitInSlotByType(ES_UNIT_TYPE_SHIP)
  if (!unit)
    return

  ::destroy_session_scripted("on startShipTrainingMission")

  set_game_mode(GM_TRAINING)
  setGuiOptionsMode(OPTIONS_MODE_TRAINING)

  ::update_test_flight_unit_info({ unit })
  ::cur_aircraft_name = unit.name
  ::aircraft_for_weapons = unit.name
  set_gui_option(USEROPT_AIRCRAFT, unit.name)
  set_gui_option(USEROPT_WEAPONS, "")
  set_gui_option(USEROPT_SKIN, "default")
  updateBulletCountOptions(unit)

  ::enable_bullets_modifications(::aircraft_for_weapons)
  ::enable_current_modifications(::aircraft_for_weapons)

  ::current_campaign_mission = MIS_NAME
  let misBlk = get_meta_mission_info_by_name(MIS_NAME)
  select_training_mission(misBlk)
  ::gui_start_flight()

  saveLocalByAccount($"tutor/mission_launched_{MIS_NAME}", true)
  ::save_profile(false)
}

return {
  startShipTrainingMission
  canStartShipTrainingMission
}