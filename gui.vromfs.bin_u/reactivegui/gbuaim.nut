from "%rGui/globals/ui_library.nut" import *

let aimState = require("guidedBombsAimState.nut")
let opticWeaponAim = require("opticWeaponAim.nut")

let gbuAimTracker =
  @(color_watched, alert_color_watched, show_tps_sight = true) opticWeaponAim(
  aimState.TrackerSize, aimState.TrackerX, aimState.TrackerY,
  aimState.GuidanceLockState, aimState.GuidanceLockStateBlinked, aimState.TrackerVisible,
  color_watched, alert_color_watched, show_tps_sight, aimState.PointIsTarget
)
return gbuAimTracker