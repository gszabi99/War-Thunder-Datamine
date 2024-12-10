let bullets_locId_by_caliber = persist("bullets_locId_by_caliber", @() [])
let modifications_locId_by_caliber = persist("modifications_locId_by_caliber", @() [])
let crosshair_icons = persist("crosshair_icons", @() [])
let thermovision_colors = persist("thermovision_colors", @() [])

return {
  get_bullets_locId_by_caliber = @() freeze(bullets_locId_by_caliber)
  set_bullets_locId_by_caliber = @(v) bullets_locId_by_caliber.replace(v)
  get_modifications_locId_by_caliber = @() freeze(modifications_locId_by_caliber)
  set_modifications_locId_by_caliber = @(v) modifications_locId_by_caliber.replace(v)
  get_crosshair_icons = @() freeze(crosshair_icons)
  set_crosshair_icons = @(v) crosshair_icons.replace(v)
  get_thermovision_colors = @() freeze(thermovision_colors)
  set_thermovision_colors = @(v) thermovision_colors.replace(v)
 }

