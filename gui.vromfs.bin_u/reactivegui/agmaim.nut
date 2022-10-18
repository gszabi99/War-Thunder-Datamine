from "%rGui/globals/ui_library.nut" import *

let agmAimState = require("agmAimState.nut")
let opticWeaponAim = require("opticWeaponAim.nut")

let agmAimTracker = @(color_watched, is_background) opticWeaponAim(agmAimState.TrackerSize, agmAimState.TrackerX, agmAimState.TrackerY, agmAimState.GuidanceLockState, agmAimState.TrackerVisible, color_watched, is_background)

return agmAimTracker