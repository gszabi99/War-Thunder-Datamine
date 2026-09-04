import "string" as string
from "%rGui/planeState/planeFlyState.nut" import Roll, Altitude, Tangage
from "%rGui/planeIlses/ilsConstants.nut" import baseLineWidth
from "%rGui/planeState/planeToolsState.nut" import AimLockDist, AimLockValid
from "%rGui/airState.nut" import TurretYaw, TurretPitch, IsInsideLaunchZoneYawPitch, IsInsideLaunchZoneDist
from "%rGui/hud/targetTrackerState.nut" import TargetRadius
from "math" import fabs
from "%rGui/globals/ui_library.nut" import *

const blackColor = Color(0, 0, 0, 255)
local curLineWidth = baseLineWidth
local fontScale = 1.0

let airSymbol = @(){
  size = const [pw(70), ph(70)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = curLineWidth
  color = blackColor
  commands = [
    [VECTOR_LINE, -100, 0, -30, 0],
    [VECTOR_LINE, -40, 0, -40, 10],
    [VECTOR_LINE, 100, 0, 30, 0],
    [VECTOR_LINE, 40, 0, 40, 10]
  ]
}

let airSymbolWrap = {
  size = const [pw(30), ph(30)]
  pos = const [pw(50), ph(50)]
  children = airSymbol
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      rotate = Roll.get()
      pivot = [0, 0]
    }
  }
}

let AltValue = Computed(@() (Altitude.get() / 10.0).tointeger() * 10)
let altitude = @() {
  watch = AltValue
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = const [pw(80), ph(20)]
  color = blackColor
  fontSize = 65 * fontScale
  font = Fonts.ils31
  text = string.format("%dр", AltValue.get())
}

let TangageAbsInt = Computed(@() fabs(Tangage.get()).tointeger())
function pitch(height) {
  return {
    size = FLEX
    children = [
      {
        size = FLEX
        rendObj = ROBJ_VECTOR_CANVAS
        color = blackColor
        lineWidth = curLineWidth
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_LINE_DASHED, 25, 0, 75, 0, 30 * curLineWidth / baseLineWidth, 25 * curLineWidth / baseLineWidth],
          [VECTOR_RECTANGLE, 16, -2.5, 8, 5]
        ]
        children = [
          @(){
            watch = TangageAbsInt
            size = const [pw(8), ph(5)]
            pos = const [pw(16), ph(-2.5)]
            rendObj = ROBJ_TEXT
            fontSize = 50 * fontScale
            halign = ALIGN_RIGHT
            color = blackColor
            padding = const [0, 5]
            text = TangageAbsInt.get().tostring()
          }
        ]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, height * (0.5 - Tangage.get() * 0.01)]
      }
    }
  }
}

let TurretPitchPos = Computed(@() ((1.0 - TurretPitch.get()) * 100.0).tointeger())
let laserPitch = @(){
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [FLEX, ph(50)]
  pos = const [0, ph(25)]
  lineWidth = curLineWidth
  color = blackColor
  commands = [
    [VECTOR_LINE, 0, 0, 5, 0],
    [VECTOR_LINE, 0, 10, 3, 10],
    [VECTOR_LINE, 0, 20, 10, 20],
    [VECTOR_LINE, 0, 30, 3, 30],
    [VECTOR_LINE, 0, 40, 5, 40],
    [VECTOR_LINE, 0, 50, 3, 50],
    [VECTOR_LINE, 0, 60, 5, 60],
    [VECTOR_LINE, 0, 70, 3, 70],
    [VECTOR_LINE, 0, 80, 5, 80],
    [VECTOR_LINE, 0, 90, 3, 90],
    [VECTOR_LINE, 0, 100, 5, 100]
  ]
  children = [
    @(){
      watch = TurretPitchPos
      rendObj = ROBJ_VECTOR_CANVAS
      size = const [pw(3), ph(4)]
      pos = [pw(5), ph(TurretPitchPos.get())]
      color = blackColor
      lineWidth = curLineWidth
      commands = [
        [VECTOR_LINE, 0, 0, 100, -100],
        [VECTOR_LINE, 0, 0, 100, 100],
        [VECTOR_LINE, 100, 100, 100, -100]
      ]
    }
  ]
}

let TurretYawPos = Computed(@() ((1.0 - TurretYaw.get()) * 100.0).tointeger())
let laserYaw = @(){
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(50), FLEX]
  pos = const [pw(25), 0]
  lineWidth = curLineWidth
  color = blackColor
  commands = [
    [VECTOR_LINE, 0, 5, 0, 0],
    [VECTOR_LINE, 12.5, 3, 12.5, 0],
    [VECTOR_LINE, 25, 5, 25, 0],
    [VECTOR_LINE, 37.5, 3, 37.5, 0],
    [VECTOR_LINE, 50, 5, 50, 0],
    [VECTOR_LINE, 62.5, 3, 62.5, 0],
    [VECTOR_LINE, 75, 5, 75, 0],
    [VECTOR_LINE, 87.5, 3, 87.5, 0],
    [VECTOR_LINE, 100, 5, 100, 0]
  ]
  children = [
    @(){
      watch = TurretYawPos
      rendObj = ROBJ_VECTOR_CANVAS
      size = const [pw(4), ph(3)]
      pos = [pw(TurretYawPos.get()), ph(5)]
      color = blackColor
      lineWidth = curLineWidth
      commands = [
        [VECTOR_LINE, 0, 0, 100, 100],
        [VECTOR_LINE, 0, 0, -100, 100],
        [VECTOR_LINE, 100, 100, -100, 100]
      ]
    }
  ]
}

let DistToTraget = Computed(@() (AimLockDist.get() / 100).tointeger())
let distToTraget = @(){
  watch = AimLockValid
  size = FLEX
  children = AimLockValid.get() ? [
    @(){
      watch = DistToTraget
      size = SIZE_TO_CONTENT
      pos = const [pw(47), ph(80)]
      rendObj = ROBJ_TEXT
      color = blackColor
      font = Fonts.ils31
      fontSize = 65 * fontScale
      text = string.format("%.1f", DistToTraget.get() / 10.0)
    }
  ] : null
}

let TAMark = @(){
  watch = AimLockValid
  size = FLEX
  children = AimLockValid.get() ? [
    @(){
      size = SIZE_TO_CONTENT
      pos = const [pw(70), ph(17)]
      rendObj = ROBJ_TEXT
      color = blackColor
      font = Fonts.ils31
      fontSize = 50 * fontScale
      text = "ТА"
    }
  ] : null
}

let TargetRadiusVal = Computed(@() AimLockValid.get() ? TargetRadius.get().tointeger() : 10)
let targetMark = @(){
  watch = TargetRadiusVal
  size = [TargetRadiusVal.get(), TargetRadiusVal.get()]
  pos = const [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = blackColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = curLineWidth
  commands = [
    [VECTOR_LINE_DASHED, -100, -100, 100, -100, 15 * curLineWidth / baseLineWidth, 15 * curLineWidth / baseLineWidth],
    [VECTOR_LINE_DASHED, 100, -100, 100, 100, 15 * curLineWidth / baseLineWidth, 15 * curLineWidth / baseLineWidth],
    [VECTOR_LINE_DASHED, 100, 100, -100, 100, 15 * curLineWidth / baseLineWidth, 15 * curLineWidth / baseLineWidth],
    [VECTOR_LINE_DASHED, -100, -100, -100, 100, 15 * curLineWidth / baseLineWidth, 15 * curLineWidth / baseLineWidth],
    [VECTOR_LINE_DASHED, 0, 0, 0, 100, 15 * curLineWidth / baseLineWidth, 15 * curLineWidth / baseLineWidth]
  ]
}

let AltMarkPos = Computed(@()(100.0 - Altitude.get()).tointeger())
let lowAltitude = @(){
  size = const [FLEX, ph(60)]
  pos = const [0, ph(20)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = blackColor
  lineWidth = curLineWidth
  commands = [
    [VECTOR_LINE, 97, 0, 97, 100],
    [VECTOR_LINE, 97, 0, 100, 0],
    [VECTOR_LINE, 97, 10, 98.5, 10],
    [VECTOR_LINE, 97, 20, 98.5, 20],
    [VECTOR_LINE, 97, 30, 98.5, 30],
    [VECTOR_LINE, 97, 40, 98.5, 40],
    [VECTOR_LINE, 97, 50, 100, 50],
    [VECTOR_LINE, 97, 60, 98.5, 60],
    [VECTOR_LINE, 97, 70, 98.5, 70],
    [VECTOR_LINE, 97, 80, 98.5, 80],
    [VECTOR_LINE, 97, 90, 98.5, 90],
    [VECTOR_LINE, 97, 100, 100, 100]
  ]
  children = [
    @(){
      watch = AltMarkPos
      size = const [pw(2), ph(5)]
      pos = [pw(95), ph(AltMarkPos.get())]
      rendObj = ROBJ_VECTOR_CANVAS
      color = blackColor
      lineWidth = curLineWidth
      commands = [
        [VECTOR_LINE, 100, 0, 0, -100],
        [VECTOR_LINE, 100, 0, 0, 100],
        [VECTOR_LINE, 0, 100, 0, -100]
      ]
    },
    @(){
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(93), ph(-8)]
      color = blackColor
      font = Fonts.ils31
      fontSize = 50 * fontScale
      text = "100"
    }
  ]
}

let AltitudeMode = Computed(@() Altitude.get() > 100.0)
let altitudeMark = @(){
  watch = AltitudeMode
  size = FLEX
  children = [
    AltitudeMode.get() ? altitude : lowAltitude
  ]
}

let atgmLaunchPermitted = @() {
  watch = [IsInsideLaunchZoneYawPitch, IsInsideLaunchZoneDist]
  size = FLEX
  children = IsInsideLaunchZoneYawPitch.get() && IsInsideLaunchZoneDist.get() ?
    @() {
      size = FLEX
      rendObj = ROBJ_TEXT
      pos = const [pw(48), ph(70)]
      color = blackColor
      fontSize = 65 * fontScale
      font = Fonts.ils31
      text = "ПР"
    }
  : null
}

function Skval(width, height, line_width, font_scale) {
  curLineWidth = baseLineWidth * line_width
  fontScale = font_scale
  return {
    size = [width, height]
    children = [
      airSymbolWrap,
      pitch(height),
      laserPitch,
      laserYaw,
      distToTraget,
      TAMark,
      targetMark,
      altitudeMark,
      atgmLaunchPermitted
    ]
  }
}

return Skval