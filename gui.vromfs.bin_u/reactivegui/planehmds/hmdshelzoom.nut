from "%rGui/globals/ui_library.nut" import *

let {GuidanceLockResult} = require("%rGui/guidanceConstants.nut")
let {IlsColor, IlsLineScale} = require("%rGui/planeState/planeToolsState.nut")
let {GuidanceLockState, HmdDesignation, HmdFovMult} = require("%rGui/rocketAamAimState.nut")

let {baseLineWidth} = require("hmdConstants.nut")

let function crosshair(width, _height) {
  return @() {
    watch = [ HmdFovMult, HmdDesignation, GuidanceLockState ]
    size = [width * 0.05 * HmdFovMult.value, width * 0.05 * HmdFovMult.value]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    fillColor = Color(0, 0, 0, 0)
    commands =
      HmdDesignation.value && GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING ?
        [
          [VECTOR_ELLIPSE, 0, 0, 25, 25],
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_LINE, 0, -25, 0, -100],
          [VECTOR_LINE, 0,  25, 0,  100],
          [VECTOR_LINE, -25, 0, -100, 0],
          [VECTOR_LINE,  25, 0,  100, 0]
        ] :
        [
          [VECTOR_ELLIPSE, 0, 0, 25, 25],
          [VECTOR_ELLIPSE, 0, 0, 50, 50]
        ]
  }
}

let function shelZoom(width, height) {
  return {
    size = [width, height]
    pos = [0.5 * width, 0.5 * height]
    children = crosshair(width, height)
  }
}

return shelZoom