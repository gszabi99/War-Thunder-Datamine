from "%scripts/dagui_library.nut" import *

let { HudAirWeaponSelector } = require("%scripts/hud/hudAirWeaponSelector.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")

gui_handlers.HudWithWeaponSelector <- class (gui_handlers.BaseUnitHud) {
  airWeaponSelector = null
  currentHudUnitName = ""

  function onDestroy() {
    this.airWeaponSelector.onDestroy()
    this.airWeaponSelector = null
  }

  function reinitScreen() {
    if (this.airWeaponSelector && !this.airWeaponSelector.isPinned)
      this.airWeaponSelector.close()
  }

  function createAirWeaponSelector(unit) {
    let weaponSelectorNest = this.scene.findObject("air_weapon_selector_nest")
    this.airWeaponSelector = HudAirWeaponSelector(unit, weaponSelectorNest)
  }

}

return {
  HudWithWeaponSelector = gui_handlers.HudWithWeaponSelector
}