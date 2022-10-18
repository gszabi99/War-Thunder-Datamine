let gbuAimState = require("guidedBombsAimState.nut")
let opticWeaponAim = require("opticWeaponAim.nut")

let gbuAimTracker = @(color_watched, is_background) opticWeaponAim(gbuAimState.TrackerSize, gbuAimState.TrackerX, gbuAimState.TrackerY, gbuAimState.GuidanceLockState, gbuAimState.TrackerVisible, color_watched, is_background)

return gbuAimTracker