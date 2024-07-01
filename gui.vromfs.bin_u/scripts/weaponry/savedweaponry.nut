from "%scripts/dagui_library.nut" import *
//!!!FIX ME: Need remove get_last_weapon and get_last_bullets at all. Currently they used for compatibility only.
let { get_unit_option } = require("guiOptions")
let { get_last_weapon, get_last_bullets } = require("unitCustomization")
let { USEROPT_WEAPONS, USEROPT_BULLETS0
} = require("%scripts/options/optionsExtNames.nut")

return {
  getSavedBullets = @(unitName, groupIdx)
    get_unit_option(unitName, USEROPT_BULLETS0 + groupIdx) ?? get_last_bullets(unitName, groupIdx)

  function getSavedWeapon(unitName) {
    let savedWeapon = get_unit_option(unitName, USEROPT_WEAPONS) ?? get_last_weapon(unitName)
    let availableWeapons = getAircraftByName(unitName)
      ?.getWeapons().map(@(w) w.name)
    return availableWeapons?.contains(savedWeapon)
      ? savedWeapon
      : ""
  }
}