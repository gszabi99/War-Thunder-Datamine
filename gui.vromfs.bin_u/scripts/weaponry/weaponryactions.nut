from "%scripts/dagui_natives.nut" import shop_enable_modifications
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { shopIsModificationEnabled } = require("chardResearch")

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

return {
  open_weapons_for_unit
  enable_modifications
  enable_current_modifications
}