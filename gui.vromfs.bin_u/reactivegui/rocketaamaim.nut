let {GimbalSize, GimbalX, GimbalY, GimbalVisible, GuidanceLockState,
  TrackerSize, TrackerX, TrackerY, TrackerVisible} = require("rocketAamAimState.nut")
let {backgroundColor} = require("style/airHudStyle.nut")

enum GuidanceLockResult {
  RESULT_INVALID = -1
  RESULT_STANDBY = 0
  RESULT_WARMING_UP = 1
  RESULT_LOCKING = 2
  RESULT_TRACKING = 3
  RESULT_LOCK_AFTER_LAUNCH = 4
}

let aamAimGimbal = @(color_watched, alert_color_watched, is_background) function() {

  if (!GimbalVisible.value)
    return { watch = GimbalVisible }

  let circle = [[VECTOR_ELLIPSE, 0, 0, GimbalSize.value, GimbalSize.value]]

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(14.0), sh(14.0)]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    color = is_background ? backgroundColor
      : GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING ? alert_color_watched.value
      : color_watched.value
    fillColor = Color(0, 0, 0, 0)
    watch = [GimbalX, GimbalY, GimbalVisible, GuidanceLockState,
      GimbalSize, color_watched, alert_color_watched]
    transform = {
      translate = [GimbalX.value, GimbalY.value]
    }
    commands = circle
  }
}

let aamAimTracker = @(color_watched, alert_color_watched, is_background) function() {

  if(!TrackerVisible.value)
    return { watch = TrackerVisible }
  let circle = [[VECTOR_ELLIPSE, 0, 0, TrackerSize.value, TrackerSize.value]]

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(14.0), sh(14.0)]
    fillColor = Color(0, 0, 0, 0)
    color = is_background ? backgroundColor
      : GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING ? alert_color_watched.value
      : color_watched.value
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    watch = [TrackerX, TrackerY, TrackerVisible, GuidanceLockState,
      TrackerSize, color_watched, alert_color_watched]
    transform = {
      translate = [TrackerX.value, TrackerY.value]
    }
    commands = circle
  }
}


let AamAim = @(color_watched, alert_color_watched, is_background)
{
  children = [
    aamAimGimbal(color_watched, alert_color_watched, is_background)
    aamAimTracker(color_watched, alert_color_watched, is_background)
  ]
}

  return AamAim