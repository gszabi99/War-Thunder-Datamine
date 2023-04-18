from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this
//!!!FIX ME: Need remove ::get_last_weapon and ::get_last_bullets at all. Currently they used for compatibility only.
let { get_unit_option } = require("guiOptions")

return {
  getSavedBullets = @(unitName, groupIdx)
    get_unit_option(unitName, ::USEROPT_BULLETS0 + groupIdx) ?? ::get_last_bullets(unitName, groupIdx)
  getSavedWeapon = @(unitName)
    get_unit_option(unitName, ::USEROPT_WEAPONS) ?? ::get_last_weapon(unitName)
}