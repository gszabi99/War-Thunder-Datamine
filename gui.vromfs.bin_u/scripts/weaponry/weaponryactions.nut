from "%scripts/dagui_natives.nut" import shop_enable_modifications
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { set_unit_option, set_gui_option } = require("guiOptions")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { shopIsModificationEnabled } = require("chardResearch")
let { USEROPT_BULLETS0, USEROPT_BULLET_COUNT0, USEROPT_BULLETS_WEAPON0
} = require("%scripts/options/optionsExtNames.nut")
let { set_option } = require("%scripts/options/optionsExt.nut")

function open_weapons_for_unit(unit, params = {}) {
  if (!("name" in unit))
    return
  unitNameForWeapons.set(unit.name)
  handlersManager.loadHandler(gui_handlers.WeaponsModalHandler, params)
}

function enable_modifications(unitName, modNames, enable) {
  modNames = modNames?.filter(@(n) n != "")
  if ((modNames?.len() ?? 0) == 0)
    return

  let db = DataBlock()
  db[unitName] <- DataBlock()
  foreach (modName in modNames)
    db[unitName][modName] <- enable
  return shop_enable_modifications(db)
}

function enable_current_modifications(unitName) {
  let db = DataBlock()
  db[unitName] <- DataBlock()

  let air = getAircraftByName(unitName)
  foreach (mod in air.modifications)
    db[unitName][mod.name] <- shopIsModificationEnabled(unitName, mod.name)

  return shop_enable_modifications(db)
}

function updateBulletCountOptions(unit, bulletGroups) {
  let unitName = unit.name
  local bulIdx = 0
  foreach (bulGroup in bulletGroups) {
    let name = bulGroup.getBulletNameForCode(bulGroup.selectedName)
    let count = bulGroup.bulletsCount
    set_option(USEROPT_BULLETS0 + bulIdx, name)
    set_unit_option(unitName, USEROPT_BULLETS0 + bulIdx, name)
    set_gui_option(USEROPT_BULLET_COUNT0 + bulIdx, count)
    set_gui_option(USEROPT_BULLETS_WEAPON0 + bulIdx, bulGroup.getWeaponName())
    bulIdx++
  }

  while (bulIdx < BULLETS_SETS_QUANTITY) {
    set_option(USEROPT_BULLETS0 + bulIdx, "")
    set_unit_option(unitName, USEROPT_BULLETS0 + bulIdx, "")
    set_gui_option(USEROPT_BULLET_COUNT0 + bulIdx, 0)
    set_gui_option(USEROPT_BULLETS_WEAPON0 + bulIdx, "")
    ++bulIdx
  }
}

return {
  open_weapons_for_unit
  enable_modifications
  enable_current_modifications
  updateBulletCountOptions
}