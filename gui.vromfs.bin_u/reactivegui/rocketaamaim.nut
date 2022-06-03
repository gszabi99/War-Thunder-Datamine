let {GimbalSize, GimbalX, GimbalY, GimbalVisible, GuidanceLockState,
  TrackerSize, TrackerX, TrackerY, TrackerVisible, GuidanceLockSnr} = require("rocketAamAimState.nut")
let {backgroundColor, relativCircle} = require("style/airHudStyle.nut")

let {log} = require("%sqstd/math.nut")

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

  local lines = @() ({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH)
    fillColor = Color(0,0,0,0)
    color = is_background ? backgroundColor
        : GuidanceLockSnr.value < 0.0 ?
          GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING ? alert_color_watched.value
          : color_watched.value
        : GuidanceLockSnr.value > 1.0 ? alert_color_watched.value
      : color_watched.value
    commands = circle
  })

  local shadowLines = @() ({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH + 2)
    fillColor = Color(0,0,0,0)
    color = Color(0, 0, 0, 120)
    commands = circle
  })

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(9.75), sh(9.75)]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    fillColor = Color(0, 0, 0, 0)
    watch = [GimbalX, GimbalY, GimbalVisible, GuidanceLockState,
      GimbalSize, color_watched, alert_color_watched, GuidanceLockSnr]
    transform = {
      translate = [GimbalX.value, GimbalY.value]
      children = [shadowLines, lines]
    }
    children = [shadowLines, lines]
  }
}

let aamAimTracker = @(color_watched, alert_color_watched, is_background) function() {

  if(!TrackerVisible.value)
    return { watch = TrackerVisible }
  let circle = [[VECTOR_ELLIPSE, 0, 0, TrackerSize.value, TrackerSize.value]]

  local snrDb = 10.0 * log(clamp(GuidanceLockSnr.value, 0.1, 10.0)) / log(10.0)

  local lines = @() ({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH)
    fillColor = Color(0,0,0,0)
    color = is_background ? backgroundColor
      : GuidanceLockSnr.value < 0.0 ?
        GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING ? alert_color_watched.value
        : color_watched.value
      : GuidanceLockSnr.value > 1.0 ? alert_color_watched.value
    : color_watched.value
    commands = circle
  })

  local shadowLines = @() ({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH + 2)
    fillColor = Color(0,0,0,0)
    color = Color(0, 0, 0, 120)
    commands = circle
  })

  local linesSNR = @() ({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH)
    fillColor = Color(0,0,0,0)
    color = is_background ? backgroundColor
      : GuidanceLockSnr.value < 0.0 ?
        GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING ? alert_color_watched.value
        : color_watched.value
      : GuidanceLockSnr.value > 1.0 ? alert_color_watched.value
    : color_watched.value
    commands = relativCircle((snrDb + 10.0) * 0.05, TrackerSize.value + TrackerSize.value * 0.10)
  })

  local shadowLinesSNR = @() ({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH + 2)
    fillColor = Color(0,0,0,0)
    color = Color(0, 0, 0, 120)
    commands = relativCircle((snrDb + 10.0) * 0.05, TrackerSize.value + TrackerSize.value * 0.10)
  })

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(9.75), sh(9.75)]
    fillColor = Color(0, 0, 0, 0)
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    watch = [TrackerX, TrackerY, TrackerVisible, GuidanceLockState,
      TrackerSize, color_watched, alert_color_watched, GuidanceLockSnr]
    transform = {
      translate = [TrackerX.value, TrackerY.value]
    }
    children = GuidanceLockSnr.value < 0.0 ?
      [shadowLines, lines]
      :  [shadowLines, shadowLinesSNR, lines, linesSNR]
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