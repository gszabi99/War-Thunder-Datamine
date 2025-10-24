from "%rGui/globals/ui_library.nut" import *

let { GimbalSize, GimbalX, GimbalY, GimbalVisible, GuidanceLockState,
  TrackerSize, TrackerX, TrackerY, TrackerVisible, GuidanceLockSnr,
  AamSightShadowOpacity, AamSightOpacity, AamSightLineWidthFactor, AamSightShadowLineWidthFactor } = require("%rGui/rocketAamAimState.nut")
let { relativCircle, isDarkColor } = require("%rGui/style/airHudStyle.nut")

let math = require("%sqstd/math.nut")

let { GuidanceLockResult } = require("guidanceConstants")

let gimbalLines = {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  fillColor = 0
  commands = [[VECTOR_ELLIPSE, 0, 0, 100, 100]]
}

let aamAimGimbal = @(color_watched, alert_color_watched) function() {
  if (!GimbalVisible.get())
    return { watch = GimbalVisible }

  let linesWidth = hdpx(LINE_WIDTH * AamSightLineWidthFactor.get())
  let shadowLineWidth = hdpx(LINE_WIDTH * AamSightShadowLineWidthFactor.get())

  let colorGimbal =
      (GuidanceLockSnr.get() > 1.0) || (GuidanceLockSnr.get() < 0.0 && GuidanceLockState.get() >= GuidanceLockResult.RESULT_TRACKING)
      ? alert_color_watched.get() : color_watched.get()

  let shadowOpacity = isDarkColor(colorGimbal) ? AamSightShadowOpacity.get() * 0.3  : AamSightShadowOpacity.get()

  let shadowLines = gimbalLines.__merge({
    lineWidth = shadowLineWidth
    color = isDarkColor(colorGimbal) ? Color(255, 255, 255, 255) : Color(0, 0, 0, 255)
    opacity = shadowOpacity
  })

  let lines = gimbalLines.__merge({
    lineWidth = linesWidth
    color = colorGimbal
    opacity = AamSightOpacity.get()
  })

  return {
    size = [GimbalSize.get(), GimbalSize.get()]
    pos = [GimbalX.get(), GimbalY.get()]
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

  if (!TrackerVisible.get())
    return { watch = TrackerVisible }

  local snrDb = 10.0 * math.log(clamp(GuidanceLockSnr.get(), 0.1, 10.0)) / math.log(10.0)

  let colorTracker =
      (GuidanceLockSnr.get() > 1.0) || (GuidanceLockSnr.get() < 0.0 && GuidanceLockState.get() >= GuidanceLockResult.RESULT_TRACKING)
      ? alert_color_watched.get() : color_watched.get()

  local lines = trackerLines.__merge({
    lineWidth = hdpx(LINE_WIDTH * AamSightLineWidthFactor.get())
    color = colorTracker
    opacity = AamSightOpacity.get()
  })

  local shadowLines = trackerLines.__merge({
    lineWidth = hdpx(LINE_WIDTH * AamSightShadowLineWidthFactor.get())
    color = isDarkColor(colorTracker) ? Color(255, 255, 255, 255) : Color(0, 0, 0, 255)
    opacity = isDarkColor(colorTracker) ? AamSightShadowOpacity.get() * 0.3  : AamSightShadowOpacity.get()
  })

  let children = [shadowLines, lines]

  if (GuidanceLockSnr.get() >= 0.0) {
    local linesSNR = trackerLines.__merge({
      lineWidth = hdpx(LINE_WIDTH * AamSightLineWidthFactor.get())
      color = colorTracker
      opacity = AamSightOpacity.get()
      commands = relativCircle((snrDb + 10.0) * 0.05, 105)
    })

    local shadowLinesSNR = linesSNR.__merge({
      lineWidth = hdpx(LINE_WIDTH * AamSightShadowLineWidthFactor.get())
      color = isDarkColor(colorTracker) ? Color(255, 255, 255, 255) : Color(0, 0, 0, 255)
      opacity = isDarkColor(colorTracker) ? AamSightShadowOpacity.get() * 0.3  : AamSightShadowOpacity.get()
    })

    children.append(shadowLinesSNR, linesSNR)
  }

  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [TrackerSize.get(), TrackerSize.get()]
    pos = [TrackerX.get(), TrackerY.get()]
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