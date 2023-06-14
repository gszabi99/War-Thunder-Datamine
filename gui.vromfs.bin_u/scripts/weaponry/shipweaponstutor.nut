from "%scripts/dagui_library.nut" import *
let { ANY_CLICK } = require("%scripts/tutorials/tutorialActions.nut")
let { isModMounted } = require("%scripts/weaponry/modificationInfo.nut")

const MAX_WEAPONS_TUTOR_SHOWS = 2
const MIN_RESPAWNS_REQUIRED = 8

let mkWeaponsTutorStep = @(target, text) {
  obj = [target]
  text
  actionType = ANY_CLICK
  shortcut = ::GAMEPAD_ENTER_SHORTCUT
  nextActionShortcut = "help/NEXT_ACTION"
}

let function getIdsByItemType(itemType, config) {
  let ids = []
  foreach (column in config.columns)
    foreach (cell in column)
      if (cell?.itemType == itemType) {
        ids.append(cell.id)
        if (cell.header != null)
          ids.append($"header_{cell.id}")
      }
  return ids
}

let function checkShowShipWeaponsTutor(weaponsHandler, columnsConfig) {
  if (!weaponsHandler.scene?.isValid())
    return

  if (!weaponsHandler.unit?.isShipOrBoat())
    return

  if (!::g_login.isProfileReceived())
    return

  let numShows = ::load_local_account_settings("tutor/weapons/numShows", 0)
  if (numShows >= MAX_WEAPONS_TUTOR_SHOWS)
    return

  if (!::my_stats.isStatsLoaded()
      || !::my_stats.isMeNewbieOnUnitType(ES_UNIT_TYPE_SHIP)
      || (::my_stats.getPvpRespawnsOnUnitType(ES_UNIT_TYPE_SHIP) < MIN_RESPAWNS_REQUIRED))
    return

  let hasReqMods = weaponsHandler.unit.modifications.findindex(
    @(mod) (mod.modClass == "firepower")
      && (mod.tier == 1)
      && !isModMounted(weaponsHandler.unit.name, mod.name)) == null
  if (!hasReqMods)
    return

  ::save_local_account_settings("tutor/weapons/numShows", numShows + 1)

  let bulletsIds = getIdsByItemType(weaponsItem.modification, columnsConfig)
  let secondaryWeaponIds = getIdsByItemType(weaponsItem.weapon, columnsConfig)
  let steps = []
  if (bulletsIds.len() > 0 && secondaryWeaponIds.len() > 0)
    steps.append(mkWeaponsTutorStep(weaponsHandler.scene, loc("tutor/weapons/step1")))
  if (bulletsIds.len() > 0)
    steps.append(mkWeaponsTutorStep(bulletsIds, loc("tutor/weapons/step2")))
  if (secondaryWeaponIds.len() > 0)
    steps.append(mkWeaponsTutorStep(secondaryWeaponIds, loc("tutor/weapons/step3")))

  ::gui_modal_tutor(steps, weaponsHandler)
}

return {
  checkShowShipWeaponsTutor
}