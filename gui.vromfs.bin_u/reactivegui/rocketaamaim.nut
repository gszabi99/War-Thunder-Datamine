from "%rGui/globals/ui_library.nut" import *

let { GimbalSize, GimbalX, GimbalY, GimbalVisible, GuidanceLockState,
  TrackerSize, TrackerX, TrackerY, TrackerVisible, GuidanceLockSnr,
  AamSightShadowOpacity, AamSightOpacity, AamSightLineWidthFactor, AamSightShadowLineWidthFactor } = require("rocketAamAimState.nut")
let { relativCircle, isDarkColor } = require("style/airHudStyle.nut")

let math = require("%sqstd/math.nut")

let { GuidanceLockResult } = require("guidanceConstants")

let gimbalLines = {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  fillColor = 0
  commands = [[VECTOR_ELLIPSE, 0, 0, 100, 100]]
}

let aamAimGimbal = @(color_watched, alert_color_watched) function() {
  if (!GimbalVisible.value)
    return { watch = GimbalVisible }

  let linesWidth = hdpx(LINE_WIDTH * AamSightLineWidthFactor.value)
  let shadowLineWidth = hdpx(LINE_WIDTH * AamSightShadowLineWidthFactor.value)

  let colorGimbal =
      (GuidanceLockSnr.value > 1.0) || (GuidanceLockSnr.value < 0.0 && GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING)
      ? alert_color_watched.value : color_watched.value

  let shadowOpacity = isDarkColor(colorGimbal) ? AamSightShadowOpacity.value * 0.3  : AamSightShadowOpacity.value

  let shadowLines = gimbalLines.__merge({
    lineWidth = shadowLineWidth
    color = isDarkColor(colorGimbal) ? Color(255, 255, 255, 255) : Color(0, 0, 0, 255)
    opacity = shadowOpacity
  })

  let lines = gimbalLines.__merge({
    lineWidth = linesWidth
    color = colorGimbal
    opacity = AamSightOpacity.value
  })

  return {
    size = [GimbalSize.value, GimbalSize.value]
    pos = [GimbalX.value, GimbalY.value]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    watch = [GimbalX, GimbalY, GimbalVisible, GuidanceLockState,
      GimbalSize, color_watched, alert_color_watched, GuidanceLockSnr,
      AamSightShadowLineWidthFactor, AamSightLineWidthFactor,
      AamSightOpacity, AamSightShadowOpacity]
    children = [shadowLines, lines]
  }
}

let trackerLines = {
  size = flex()
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  rendObj = ROBJ_VECTOR_CANVAS
  fillColor = 0
  commands = [[VECTOR_ELLIPSE, 0, 0, 100, 100]]
}

let aamAimTracker = @(color_watched, alert_color_watched) function() {

  if (!TrackerVisible.value)
    return { watch = TrackerVisible }

  local snrDb = 10.0 * math.log(clamp(GuidanceLockSnr.value, 0.1, 10.0)) / math.log(10.0)

  let colorTracker =
      (GuidanceLockSnr.value > 1.0) || (GuidanceLockSnr.value < 0.0 && GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING)
      ? alert_color_watched.value : color_watched.value

  local lines = trackerLines.__merge({
    lineWidth = hdpx(LINE_WIDTH * AamSightLineWidthFactor.value)
    color = colorTracker
    opacity = AamSightOpacity.value
  })

  local shadowLines = trackerLines.__merge({
    lineWidth = hdpx(LINE_WIDTH * AamSightShadowLineWidthFactor.value)
    color = isDarkColor(colorTracker) ? Color(255, 255, 255, 255) : Color(0, 0, 0, 255)
    opacity = isDarkColor(colorTracker) ? AamSightShadowOpacity.value * 0.3  : AamSightShadowOpacity.value
  })

  let children = [shadowLines, lines]

  if (GuidanceLockSnr.value >= 0.0) {
    local linesSNR = trackerLines.__merge({
      lineWidth = hdpx(LINE_WIDTH * AamSightLineWidthFactor.value)
      color = colorTracker
      opacity = AamSightOpacity.value
      commands = relativCircle((snrDb + 10.0) * 0.05, 105)
    })

    local shadowLinesSNR = linesSNR.__merge({
      lineWidth = hdpx(LINE_WIDTH * AamSightShadowLineWidthFactor.value)
      color = isDarkColor(colorTracker) ? Color(255, 255, 255, 255) : Color(0, 0, 0, 255)
      opacity = isDarkColor(colorTracker) ? AamSightShadowOpacity.value * 0.3  : AamSightShadowOpacity.value
    })

    children.append(shadowLinesSNR, linesSNR)
  }

  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [TrackerSize.value, TrackerSize.value]
    pos = [TrackerX.value, TrackerY.value]
    watch = [TrackerX, TrackerY, TrackerVisible, GuidanceLockState,
      TrackerSize, color_watched, alert_color_watched, GuidanceLockSnr,
      AamSightLineWidthFactor, AamSightOpacity, AamSightShadowLineWidthFactor, AamSightShadowOpacity]
    children
  }
}


let AamAim = @(color_watched, alert_color_watched)
{
  children = [
    aamAimGimbal(color_watched, alert_color_watched)
    aamAimTracker(color_watched, alert_color_watched)
  ]
}

return AamAim