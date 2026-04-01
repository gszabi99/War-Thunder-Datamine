from "%rGui/globals/ui_library.nut" import *

let aimState = require("%rGui/agmAimState.nut")
let { opticWeaponAim, opticWeaponSight } = require("%rGui/opticWeaponAim.nut")

let dummyAlertColor = Watched(Color(230, 0, 0, 240))

let agmAimTracker =
  @(color_watched, alert_color_watched = dummyAlertColor, show_tps_sight = true) function() {
    return {
      children = [
        opticWeaponAim(
          aimState.TrackerSize, aimState.TrackerX, aimState.TrackerY,
          aimState.GuidanceLockState, aimState.GuidanceLockStateBlinked, aimState.TrackerVisible, aimState.IsAntiRadiation,
          aimState.TrackedTargetName, aimState.IsTrackerLoosingIcon,
          color_watched, alert_color_watched, show_tps_sight, aimState.PointIsTarget
        )
        opticWeaponSight(
          aimState.SightSize, aimState.SightX, aimState.SightY, aimState.SightVisible,
          aimState.GuidanceLockState, show_tps_sight
        )
      ]
    }
  }

return agmAimTracker
