from "%scripts/hud/hudAirWeaponSelector.nut" import HudAirWeaponSelector
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/hud/baseUnitHud.nut" import BaseUnitHud
from "%scripts/dagui_library.nut" import *

let HudWithWeaponSelector = class (BaseUnitHud) {
  airWeaponSelector = null
  currentHudUnitName = ""

  function onDestroy() {
    this.airWeaponSelector.onDestroy()
    this.airWeaponSelector = null
  }

  function reinitScreen() {
    this.airWeaponSelector?.reinitScreen()
  }

  function createAirWeaponSelector(unit) {
    let weaponSelectorNest = this.scene.findObject("air_weapon_selector_nest")
    this.airWeaponSelector = HudAirWeaponSelector(unit, weaponSelectorNest)
  }

}
register_gui_handler("HudWithWeaponSelector", HudWithWeaponSelector)

return freeze({
  HudWithWeaponSelector
})