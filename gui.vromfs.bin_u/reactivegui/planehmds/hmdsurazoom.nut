from "%rGui/globals/ui_library.nut" import *

let { IlsColor, IlsLineScale, RadarTargetDist } = require("%rGui/planeState/planeToolsState.nut")
let { GuidanceLockState, HmdDesignation} = require("%rGui/rocketAamAimState.nut")
let { HmdSensorDesignation } = require("%rGui/radarState.nut")
let { isInVr } = require("%rGui/style/screenState.nut")
let { Speed, Altitude } = require("%rGui/planeState/planeFlyState.nut")
let { mpsToKmh } = require("%rGui/planeIlses/ilsConstants.nut")
let { round } = require("math")
let string = require("string")
let { GuidanceLockResult, GuidanceType } = require("guidanceConstants")
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
          [VECTOR_ELLIPSE, 0, 0, 25, 25],
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_LINE, 0, -15, 0, -85],
          [VECTOR_LINE, 0,  15, 0,  85],
          [VECTOR_LINE, -15, 0, -85, 0],
          [VECTOR_LINE,  15, 0,  85, 0]
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
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_LINE, 0, -19, 0, -85],
          [VECTOR_LINE, 0,  19, 0,  85],
          [VECTOR_LINE, -19, 0, -85, 0],
          [VECTOR_LINE,  19, 0,  85, 0]
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

let SpeedVal = Computed(@() round(Speed.get() * mpsToKmh).tointeger())
let speed = @() {
  watch = SpeedVal
  pos = [pw(-4.8), ph(-2.2)]
  size = flex()
  rendObj = ROBJ_TEXT
  color = Color(202, 30, 10, 120)
  font = Fonts.hud
  fontSize = 19
  text = SpeedVal.get().tostring()
}

let AltitudeValKm = Computed(@() (Altitude.get()/1000).tointeger() )
let AltitudeValM = Computed(@() (Altitude.get()%1000).tointeger() )
let altitude = {
  size = const [pw(10), ph(4)]
  pos = [pw(-5.6), ph(-4.8)]
  flow = FLOW_HORIZONTAL
  halign = ALIGN_RIGHT
  children = [
    @(){
      watch = AltitudeValKm
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = Color(202, 30, 10, 120)
      font = Fonts.hud
      fontSize = 19
      text = AltitudeValKm.get().tostring()
    }
    @(){
      watch = AltitudeValM
      size = SIZE_TO_CONTENT
      pos = [pw(-5), ph(-15)]
      rendObj = ROBJ_TEXT
      color = Color(202, 30, 10, 120)
      font = Fonts.hud
      fontSize = 16
      text = AltitudeValM.get() < 1000 ? string.format("%03d", AltitudeValM.get() % 1000) : string.format("%2d,%03d", AltitudeValM.get() / 1000, AltitudeValM.get() % 1000)
    }
  ]
}

let HaveRadarTarget = Computed(@() RadarTargetDist.get() > 0)
let radarTargetData = @(){
  pos = const [pw(0.3), ph(6.8)]
  size = const [pw(10), ph(4)]
  watch = HaveRadarTarget
  flow = FLOW_VERTICAL
  children = HaveRadarTarget.get() ? [
    @(){
      rendObj = ROBJ_TEXT
      watch = RadarTargetDist
      text = string.format("%d", round(RadarTargetDist.get() * 0.001))
      color = Color(202, 30, 10, 120)
      font = Fonts.hud
      fontSize = 19
    }
   ] : null
}

function SuraZoom(width, height) {
  return {
    size = [width, height]
    pos = [0.5 * width, 0.5 * height]
    children = [
      crosshair(width, height)
      speed
      altitude
      radarTargetData
    ]
  }
}

return SuraZoom