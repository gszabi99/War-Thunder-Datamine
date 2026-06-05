from "%scripts/dagui_library.nut" import *

let { hangar_get_current_unit_name } = require("hangar")
let { eventbus_subscribe } = require("eventbus")
let guiStartWeaponryPresets = require("%scripts/weaponry/guiStartWeaponryPresets.nut")
let { isUnitHaveSecondaryWeapons } = require("%scripts/unit/unitWeaponryInfo.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")

function onClickDemonstratedShell(params) {
  let unitName = hangar_get_current_unit_name()
  let unit = getAircraftByName(unitName)

  if (unit && !unit.isSlave() && isUnitHaveSecondaryWeapons(unit)) {
    guiStartWeaponryPresets({
      unit
      curEdiff = getCurrentGameModeEdiff()
      selectedIdxOnInit = params.presetName
    })
  }
}

eventbus_subscribe("click_demonstrated_shell", onClickDemonstratedShell)