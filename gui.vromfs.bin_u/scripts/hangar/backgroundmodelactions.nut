import "%scripts/weaponry/guiStartWeaponryPresets.nut" as guiStartWeaponryPresets
from "%scripts/unit/unitWeaponryInfo.nut" import isUnitHaveSecondaryWeapons
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeEdiff
from "%scripts/weaponry/weaponryPresetsWndState.nut" import isPresetsWndReserved
from "%scripts/modalInfo/modalInfo.nut" import destroyModalInfo
from "hangar" import hangar_get_current_unit_name
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

function onClickDemonstratedShell(params) {
  if (isPresetsWndReserved.get())
    return

  destroyModalInfo()
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