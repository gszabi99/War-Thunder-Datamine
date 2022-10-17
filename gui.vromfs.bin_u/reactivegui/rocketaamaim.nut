let {GimbalSize, GimbalX, GimbalY, GimbalVisible, GuidanceLockState,
  TrackerSize, TrackerX, TrackerY, TrackerVisible, GuidanceLockSnr,
  AamSightShadowOpacity, AamSightOpacity, AamSightLineWidthFactor, AamSightShadowLineWidthFactor} = require("rocketAamAimState.nut")
let {backgroundColor, relativCircle, isDarkColor} = require("style/airHudStyle.nut")

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

  let linesWidth = hdpx(LINE_WIDTH * AamSightLineWidthFactor.value)
  let shadowLineWidth = hdpx(LINE_WIDTH * AamSightShadowLineWidthFactor.value)

  let colorGimbal =  is_background ? backgroundColor
      : GuidanceLockSnr.value < 0.0 ?
        GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING ? alert_color_watched.value
        : color_watched.value
      : GuidanceLockSnr.value > 1.0 ? alert_color_watched.value
    : color_watched.value

  let shadowOpacity = isDarkColor(colorGimbal) ? AamSightShadowOpacity.value * 0.3  : AamSightShadowOpacity.value

  local lines = @() ({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = linesWidth
    fillColor = Color(0,0,0,0)
    color = colorGimbal
    commands = circle
    opacity = AamSightOpacity.value
  })

  local shadowLines = @() ({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = shadowLineWidth
    fillColor = Color(0,0,0,0)
    color = isDarkColor(colorGimbal) ? Color(255,255,255, 255) : Color(0,0,0,255)
    opacity = shadowOpacity
    commands = circle
  })

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(9.75), sh(9.75)]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    fillColor = Color(0, 0, 0, 0)
    watch = [GimbalX, GimbalY, GimbalVisible, GuidanceLockState,
      GimbalSize, color_watched, alert_color_watched, GuidanceLockSnr,
      AamSightShadowLineWidthFactor, AamSightLineWidthFactor,
      AamSightOpacity, AamSightShadowOpacity]
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

  local snrDb = 10.0 * log(clamp(GuidanceLockSnr.value, 0.1, 10.0)) / log(10.0)

  let circle = [[VECTOR_ELLIPSE, 0, 0, TrackerSize.value, TrackerSize.value]]

  let colorTracker =  is_background ? backgroundColor
  : GuidanceLockSnr.value < 0.0 ?
  GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING ? alert_color_watched.value
  : color_watched.value
  : GuidanceLockSnr.value > 1.0 ? alert_color_watched.value
  : color_watched.value

  local lines = @() ({
    watch = [AamSightLineWidthFactor, AamSightOpacity]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH * AamSightLineWidthFactor.value)
    fillColor = Color(0,0,0,0)
    color = colorTracker
    opacity = AamSightOpacity.value
    commands = circle
  })

  local shadowLines = @() ({
    watch = [AamSightShadowLineWidthFactor, AamSightShadowOpacity]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH * AamSightShadowLineWidthFactor.value)
    fillColor = Color(0,0,0,0)
    color = isDarkColor(colorTracker) ? Color(255,255,255, 255) : Color(0,0,0, 255)
    opacity = isDarkColor(colorTracker) ? AamSightShadowOpacity.value * 0.3  : AamSightShadowOpacity.value
    commands = circle
  })

  local linesSNR = @() ({
    watch = [AamSightLineWidthFactor, AamSightOpacity]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH * AamSightLineWidthFactor.value)
    fillColor = Color(0,0,0,0)
    color = colorTracker
    opacity = AamSightOpacity.value
    commands = relativCircle((snrDb + 10.0) * 0.05, TrackerSize.value + TrackerSize.value * 0.05, 72)
  })

  local shadowLinesSNR = @() ({
    watch = [AamSightShadowLineWidthFactor, AamSightShadowOpacity]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH * AamSightShadowLineWidthFactor.value)
    fillColor = Color(0,0,0,0)
    color = isDarkColor(colorTracker) ? Color(255,255,255, 255) : Color(0,0,0,255)
    opacity = isDarkColor(colorTracker) ? AamSightShadowOpacity.value * 0.3  : AamSightShadowOpacity.value
    commands = relativCircle((snrDb + 10.0) * 0.05, TrackerSize.value + TrackerSize.value * 0.05, 72)
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