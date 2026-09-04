import "string" as string
from "%rGui/airState.nut" import TurretYaw
from "%rGui/planeState/planeFlyState.nut" import Speed, Altitude, Mach
from "%rGui/planeState/planeToolsState.nut" import AimLockDist, AimLockValid, DistToTarget, RocketMode, BombingMode, AirCannonMode, RadarTargetDist, AtgmTargetDist, IlsAtgmLocked
from "%rGui/planeIlses/ilsConstants.nut" import mpsToKmh
from "%rGui/hud/targetTrackerState.nut" import IsTargetTracked
from "%rGui/rocketAamAimState.nut" import IlsTrackerVisible, GuidanceLockState
from "guidanceConstants" import GuidanceLockResult
from "dagor.math" import cvt
from "%rGui/globals/ui_library.nut" import *

const baseColor = Color(70, 255, 0)
const whiteColor = Color(255, 255, 255)
const frameColor = Color(0, 50, 200, 255)
const baseLineWidth = 2
const baseFontSize = 14

const MIG_BAR_THICK = 5.0
const MIG_SIDE_THICK = 4.0
const MIG_SIDE_INSET = 11.2

let SpeedKmh = Computed(@() (Speed.get() * mpsToKmh).tointeger())
let AltM = Computed(@() Altitude.get().tointeger())
let MachVal = Computed(@() Mach.get())
let OlsWeaponMode = Computed(@() AirCannonMode.get() ? "ВВ" : (RocketMode.get() ? "ВП" : (BombingMode.get() ? "ВП" : "")))
let IsLocked = Computed(@() IsTargetTracked.get() || AimLockValid.get() || IlsAtgmLocked.get() || (GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY && IlsTrackerVisible.get()))

let crosshair = {
  size = FLEX
  rendObj = ROBJ_VECTOR_CANVAS
  color = whiteColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 44, 50, 48, 50],
    [VECTOR_LINE, 52, 50, 56, 50],
    [VECTOR_LINE, 50, 44, 50, 48],
    [VECTOR_LINE, 50, 52, 50, 56]
  ]
}

let lockFrame = @() {
  watch = IsLocked
  size = FLEX
  children = IsLocked.get() ? {
    size = FLEX
    rendObj = ROBJ_VECTOR_CANVAS
    color = whiteColor
    lineWidth = baseLineWidth
    commands = [
      [VECTOR_LINE, 40, 42, 44, 42],
      [VECTOR_LINE, 40, 42, 40, 45],
      [VECTOR_LINE, 60, 42, 56, 42],
      [VECTOR_LINE, 60, 42, 60, 45],
      [VECTOR_LINE, 40, 58, 44, 58],
      [VECTOR_LINE, 40, 58, 40, 55],
      [VECTOR_LINE, 60, 58, 56, 58],
      [VECTOR_LINE, 60, 58, 60, 55]
    ]
  } : null
}

let TurretYawMarkPos = Computed(@() (TurretYaw.get() * 100.0).tointeger())
let turretYaw = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(30), ph(4)]
  pos = const [pw(35), ph(5)]
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 0, 80, 100, 80],
    [VECTOR_LINE, 0, 60, 0, 80],
    [VECTOR_LINE, 25, 60, 25, 80],
    [VECTOR_LINE, 50, 60, 50, 80],
    [VECTOR_LINE, 75, 60, 75, 80],
    [VECTOR_LINE, 100, 60, 100, 80]
  ]
  children = @() {
    watch = TurretYawMarkPos
    rendObj = ROBJ_VECTOR_CANVAS
    size = FLEX
    color = baseColor
    lineWidth = baseLineWidth
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_POLY, TurretYawMarkPos.get(), 80, TurretYawMarkPos.get() - 6, 95, TurretYawMarkPos.get() + 6, 95]
    ]
  }
}

let CurDistM = Computed(function() {
  if (AtgmTargetDist.get() > 10.0)
    return AtgmTargetDist.get()
  if (AimLockDist.get() > 10.0)
    return AimLockDist.get()
  if (DistToTarget.get() > 10.0)
    return DistToTarget.get()
  if (RadarTargetDist.get() > 10.0)
    return RadarTargetDist.get()
  return 0.0
})
let DistValid = Computed(@() CurDistM.get() > 10.0)
let DistMarkPos = Computed(@() cvt(CurDistM.get() * 0.001, 0.0, 10.0, 100, 0).tointeger())
let distScale = {
  size = const [pw(3), ph(65)]
  pos = const [pw(21), ph(18)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 100, 0, 100, 100],
    [VECTOR_LINE, 0, 0, 100, 0],
    [VECTOR_LINE, 50, 10, 100, 10],
    [VECTOR_LINE, 0, 20, 100, 20],
    [VECTOR_LINE, 50, 30, 100, 30],
    [VECTOR_LINE, 0, 40, 100, 40],
    [VECTOR_LINE, 50, 50, 100, 50],
    [VECTOR_LINE, 0, 60, 100, 60],
    [VECTOR_LINE, 50, 70, 100, 70],
    [VECTOR_LINE, 0, 80, 100, 80],
    [VECTOR_LINE, 50, 90, 100, 90],
    [VECTOR_LINE, 0, 100, 100, 100]
  ]
  children = [
    { rendObj = ROBJ_TEXT, pos = const [pw(-350), ph(-3)], size = const [pw(300), SIZE_TO_CONTENT], color = baseColor, font = Fonts.ils31, fontSize = baseFontSize - 2, text = "10", halign = ALIGN_RIGHT }
    { rendObj = ROBJ_TEXT, pos = const [pw(-350), ph(17)], size = const [pw(300), SIZE_TO_CONTENT], color = baseColor, font = Fonts.ils31, fontSize = baseFontSize - 2, text = "8", halign = ALIGN_RIGHT }
    { rendObj = ROBJ_TEXT, pos = const [pw(-350), ph(37)], size = const [pw(300), SIZE_TO_CONTENT], color = baseColor, font = Fonts.ils31, fontSize = baseFontSize - 2, text = "6", halign = ALIGN_RIGHT }
    { rendObj = ROBJ_TEXT, pos = const [pw(-350), ph(57)], size = const [pw(300), SIZE_TO_CONTENT], color = baseColor, font = Fonts.ils31, fontSize = baseFontSize - 2, text = "4", halign = ALIGN_RIGHT }
    { rendObj = ROBJ_TEXT, pos = const [pw(-350), ph(77)], size = const [pw(300), SIZE_TO_CONTENT], color = baseColor, font = Fonts.ils31, fontSize = baseFontSize - 2, text = "2", halign = ALIGN_RIGHT }
    { rendObj = ROBJ_TEXT, pos = const [pw(-350), ph(97)], size = const [pw(300), SIZE_TO_CONTENT], color = baseColor, font = Fonts.ils31, fontSize = baseFontSize - 2, text = "0", halign = ALIGN_RIGHT }
    @() {
      watch = [DistMarkPos, DistValid]
      size = const [pw(200), ph(3)]
      pos = [pw(100), ph(DistMarkPos.get())]
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth
      commands = DistValid.get() ? [
        [VECTOR_LINE, 0, 0, 20, 0],
        [VECTOR_POLY, 20, 0, 50, -100, 50, -40, 100, -40, 100, 40, 50, 40, 50, 100]
      ] : []
    }
  ]
}

let speedField = @() {
  watch = SpeedKmh
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  color = baseColor
  font = Fonts.ils31
  fontSize = baseFontSize
  text = SpeedKmh.get().tostring()
}

let altField = @() {
  watch = AltM
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  color = baseColor
  font = Fonts.ils31
  fontSize = baseFontSize
  text = AltM.get().tostring()
}

let machField = @() {
  watch = MachVal
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  color = baseColor
  font = Fonts.ils31
  fontSize = baseFontSize
  text = string.format("%.2f", MachVal.get())
}

let modeField = @() {
  watch = OlsWeaponMode
  rendObj = ROBJ_TEXT
  pos = const [pw(20), ph(6)]
  size = SIZE_TO_CONTENT
  color = baseColor
  font = Fonts.ils31
  fontSize = baseFontSize
  text = OlsWeaponMode.get()
}

function makeLabel(txt) {
  return {
    rendObj = ROBJ_TEXTAREA
    color = baseColor
    font = Fonts.ils31
    fontSize = baseFontSize - 2
    text = txt
    behavior = Behaviors.TextArea
    halign = ALIGN_CENTER
  }
}

function createMigFrame(displaySize) {
  let dw = displaySize[0]
  let dh = displaySize[1]
  let barH = (MIG_BAR_THICK * 0.01 * dh).tointeger()
  let barW = (MIG_SIDE_THICK * 0.01 * dw).tointeger()
  let sideInset = (MIG_SIDE_INSET * 0.01 * dw).tointeger()

  let leftLabels =  ["П\nЛ\nТ", "Н\nВ\nГ", "О\nВ\nО", "Б\nК\nС", "Б\nК\nО", "Р\nЛ\nС", "О\nП\nС"]
  let leftY =       [4.0, 16.0, 26.0, 37.0, 57.0, 68.0, 79.0]
  let rightLabels = ["Т", "П", "И\nЗ\nЛ", "С\nЛ\nЕ\nД", "Э\nК\nР", "В\nЫ\nХ"]
  let rightY =      [8.0, 20.0, 36.0, 52.0, 70.0, 80.0]

  let leftBtns = leftLabels.map(@(txt, i) {
    size = [barW, SIZE_TO_CONTENT]
    pos = [sideInset, (leftY[i] * 0.01 * dh).tointeger()]
    halign = ALIGN_CENTER
    children = makeLabel(txt)
  })

  let rightBtns = rightLabels.map(@(txt, i) {
    size = [barW, SIZE_TO_CONTENT]
    pos = [dw - sideInset - barW, (rightY[i] * 0.01 * dh).tointeger()]
    halign = ALIGN_CENTER
    children = makeLabel(txt)
  })

  return {
    size = [dw, dh]
    children = [
      {
        size = [dw, barH]
        rendObj = ROBJ_SOLID
        color = frameColor
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        padding = [0, barW]
        children = [
          { size = FLEX, children = speedField }
          { size = FLEX, halign = ALIGN_CENTER, children = machField }
          { size = FLEX, halign = ALIGN_RIGHT, children = altField }
        ]
      }
      {
        size = [dw, barH]
        rendObj = ROBJ_SOLID
        color = frameColor
        vplace = ALIGN_BOTTOM
      }
      {
        size = [barW, dh]
        pos = [sideInset, 0]
        rendObj = ROBJ_SOLID
        color = frameColor
      }
      {
        size = [barW, dh]
        pos = [dw - sideInset - barW, 0]
        rendObj = ROBJ_SOLID
        color = frameColor
      }
    ].extend(leftBtns).extend(rightBtns)
  }
}

function mfdMig35Ols(width, height) {
  return {
    size = [width, height]
    children = [
      crosshair
      lockFrame
      distScale
      turretYaw
      modeField
      createMigFrame([width, height])
    ]
  }
}

return mfdMig35Ols
