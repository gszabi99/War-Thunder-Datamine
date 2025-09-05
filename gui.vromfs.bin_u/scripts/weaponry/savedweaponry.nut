from "%scripts/dagui_library.nut" import *

let { get_unit_option } = require("guiOptions")
let { get_last_weapon, get_last_bullets } = require("unitCustomization")
let { USEROPT_WEAPONS, USEROPT_BULLETS0
} = require("%scripts/options/optionsExtNames.nut")

return {
  function getSavedBullets(unitName, groupIdx) {
    let fromOptions = get_unit_option(unitName, USEROPT_BULLETS0 + groupIdx)
    return (fromOptions && type(fromOptions) == "string")
      ? fromOptions
      : get_last_bullets(unitName, groupIdx)
  }

  function getSavedWeapon(unitName) {
    let savedWeapon = get_unit_option(unitName, USEROPT_WEAPONS) ?? get_last_weapon(unitName)
    let availableWeapons = getAircraftByName(unitName)
      ?.getWeapons().map(@(w) w.name)
    return availableWeapons?.contains(savedWeapon)
      ? savedWeapon
      : ""
  }
}