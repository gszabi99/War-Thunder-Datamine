from "%rGui/globals/ui_library.nut" import *

let gbuAimState = require("guidedBombsAimState.nut")
let opticWeaponAim = require("opticWeaponAim.nut")

let gbuAimTracker = @(color_watched) opticWeaponAim(gbuAimState.TrackerSize, gbuAimState.TrackerX, gbuAimState.TrackerY, gbuAimState.GuidanceLockState, gbuAimState.TrackerVisible, color_watched)

return gbuAimTracker