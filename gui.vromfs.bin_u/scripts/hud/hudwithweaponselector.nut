from "%scripts/dagui_library.nut" import *

let { HudAirWeaponSelector } = require("%scripts/hud/hudAirWeaponSelector.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseUnitHud } = require("%scripts/hud/baseUnitHud.nut")

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

return {
  HudWithWeaponSelector
}