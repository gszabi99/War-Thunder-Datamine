from "%rGui/globals/ui_library.nut" import *

let aimState = require("agmAimState.nut")
let opticWeaponAim = require("opticWeaponAim.nut")

let dummyAlertColor = Watched(Color(230, 0, 0, 240))

let agmAimTracker =
  @(color_watched, alert_color_watched = dummyAlertColor, show_tps_sight = true) opticWeaponAim(
  aimState.TrackerSize, aimState.TrackerX, aimState.TrackerY,
  aimState.GuidanceLockState, aimState.GuidanceLockStateBlinked, aimState.TrackerVisible,
  color_watched, alert_color_watched, show_tps_sight
)

return agmAimTracker