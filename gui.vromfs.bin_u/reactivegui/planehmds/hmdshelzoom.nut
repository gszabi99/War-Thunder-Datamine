from "%rGui/globals/ui_library.nut" import *

let { GuidanceLockResult, GuidanceType } = require("guidanceConstants")
let { IlsColor, IlsLineScale } = require("%rGui/planeState/planeToolsState.nut")
let { GuidanceLockState, HmdDesignation} = require("%rGui/rocketAamAimState.nut")
let { HmdSensorDesignation } = require("%rGui/radarState.nut")
let { isInVr } = require("%rGui/style/screenState.nut")
let { CurWeaponGidanceType } = require("%rGui/planeState/planeWeaponState.nut")

let { baseLineWidth } = require("%rGui/planeHmds/hmdConstants.nut")

function crosshair(width, _height) {
  return @() {
    watch = [ HmdDesignation, HmdSensorDesignation, GuidanceLockState, IlsColor ]
    size = [width * 0.05, width * 0.05]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_VECTOR_CANVAS
    color = isInVr ? Color(202, 30, 10, 120) : Color(202, 30, 10, 100)
    lineWidth = baseLineWidth * IlsLineScale.get()
    fillColor = Color(0, 0, 0, 0)
    commands =
      HmdSensorDesignation.get() ||
      (HmdDesignation.get() &&
      GuidanceLockState.get() >= GuidanceLockResult.RESULT_TRACKING && CurWeaponGidanceType.get() == GuidanceType.TYPE_OPTICAL ?
        [
          [VECTOR_ELLIPSE, 0, 0, 30, 30],
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_LINE, 0, -15, 0, -65],
          [VECTOR_LINE, 0,  15, 0,  65],
          [VECTOR_LINE, -15, 0, -65, 0],
          [VECTOR_LINE,  15, 0,  65, 0]
        ]
      : (GuidanceLockState.get() >= GuidanceLockResult.RESULT_WARMING_UP && CurWeaponGidanceType.get() == GuidanceType.TYPE_OPTICAL ?
        [
          [VECTOR_SECTOR, 0, 0, 50, 50, 5, 85],
          [VECTOR_SECTOR, 0, 0, 50, 50, 95, 175],
          [VECTOR_SECTOR, 0, 0, 50, 50, 185, 270],
          [VECTOR_SECTOR, 0, 0, 50, 50, 280, 355],
          [VECTOR_SECTOR, 0, 0, 30, 30, 7, 83],
          [VECTOR_SECTOR, 0, 0, 30, 30, 98, 172],
          [VECTOR_SECTOR, 0, 0, 30, 30, 188, 267],
          [VECTOR_SECTOR, 0, 0, 30, 30, 283, 352]
        ]
      : [
          [VECTOR_ELLIPSE, 0, 0, 30, 30],
          [VECTOR_ELLIPSE, 0, 0, 50, 50]
        ]))
    animations = [
      { prop = AnimProp.opacity, from = 1, to = -1, duration = 0.5, play = GuidanceLockState.get() >= GuidanceLockResult.RESULT_WARMING_UP && GuidanceLockState.get() < GuidanceLockResult.RESULT_TRACKING, loop = true, trigger = "RESULT_WARMING_UP" }
    ]
    behavior = Behaviors.RtPropUpdate
    update = function() {
        if (GuidanceLockState.get() >= GuidanceLockResult.RESULT_WARMING_UP && GuidanceLockState.get() < GuidanceLockResult.RESULT_TRACKING)
          anim_start("RESULT_WARMING_UP")
        else
          anim_request_stop("RESULT_WARMING_UP")
    }
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