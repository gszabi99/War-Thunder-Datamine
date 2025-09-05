from "%rGui/globals/ui_library.nut" import *

let { GuidanceLockResult } = require("guidanceConstants")
let { IlsColor, IlsLineScale } = require("%rGui/planeState/planeToolsState.nut")
let { HmdVisibleAAM, GuidanceLockState, HmdDesignation } = require("%rGui/rocketAamAimState.nut")
let { HmdSensorVisible, HmdSensorDesignation } = require("%rGui/radarState.nut")
let { isInVr } = require("%rGui/style/screenState.nut")

let { baseLineWidth } = require("%rGui/planeHmds/hmdConstants.nut")

function crosshair(width, _height) {
  return @() {
    watch = [HmdVisibleAAM, HmdDesignation, HmdSensorVisible, HmdSensorDesignation, GuidanceLockState, IlsColor]
    size = [width * 0.05, width * 0.05]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_VECTOR_CANVAS
    color = isInVr ? Color(10, 255, 10, 30) : Color(10, 255, 10, 10)
    lineWidth = baseLineWidth * IlsLineScale.get()
    fillColor = Color(0, 0, 0, 0)
    commands =
      [
        [VECTOR_ELLIPSE, 0, 0, 25, 25],
        [VECTOR_ELLIPSE, 0, 0, 5, 5]
      ].append(HmdVisibleAAM.get() ? [VECTOR_ELLIPSE, -25, -25, 2, 2] : [])
       .append(HmdDesignation.get() && GuidanceLockState.get() >= GuidanceLockResult.RESULT_TRACKING ? [VECTOR_ELLIPSE, -25, 25, 2, 2] : [])
       .append(HmdSensorVisible.get() ? [VECTOR_ELLIPSE, 25, -25, 2, 2] : [])
       .append(HmdSensorDesignation.get() ? [VECTOR_ELLIPSE, 25, 25, 2, 2] : [])
  }
}

function vtas(width, height) {
  return {
    size = [width, height]
    pos = [0.5 * width, 0.5 * height]
    children = crosshair(width, height)
  }
}

return vtas