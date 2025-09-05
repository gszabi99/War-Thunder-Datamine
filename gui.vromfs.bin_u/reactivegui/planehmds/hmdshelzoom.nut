from "%rGui/globals/ui_library.nut" import *

let { GuidanceLockResult } = require("guidanceConstants")
let { IlsColor, IlsLineScale } = require("%rGui/planeState/planeToolsState.nut")
let { GuidanceLockState, HmdDesignation} = require("%rGui/rocketAamAimState.nut")
let { HmdSensorDesignation } = require("%rGui/radarState.nut")
let { isInVr } = require("%rGui/style/screenState.nut")

let { baseLineWidth } = require("%rGui/planeHmds/hmdConstants.nut")

function crosshair(width, _height) {
  return @() {
    watch = [ HmdDesignation, HmdSensorDesignation, GuidanceLockState, IlsColor ]
    size = [width * 0.05, width * 0.05]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_VECTOR_CANVAS
    color = isInVr ? Color(10, 255, 10, 30) : Color(10, 255, 10, 10)
    lineWidth = baseLineWidth * IlsLineScale.get()
    fillColor = Color(0, 0, 0, 0)
    commands =
      HmdSensorDesignation.get() ||
      (HmdDesignation.get() && GuidanceLockState.get() >= GuidanceLockResult.RESULT_TRACKING) ?
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

function shelZoom(width, height) {
  return {
    size = [width, height]
    pos = [0.5 * width, 0.5 * height]
    children = crosshair(width, height)
  }
}

return shelZoom