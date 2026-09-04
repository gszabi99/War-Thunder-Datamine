from "%rGui/planeState/planeWeaponState.nut" import ShellFPVModeValid, ShellFPVTargetX, ShellFPVTargetY, ShellFPVHasTarget, ShellFPVMaxZoom, ShellFPVCameraLimX, ShellFPVCameraLimY
  , ShellFPVAnglesLocked, ShellFPVTimeOfFlight
from "%rGui/globals/ui_library.nut" import *

const baseColor = Color(255, 255, 255, 255)
const blackColor = Color(0, 0, 0, 255)
const redColor = Color(255, 0, 0, 255)
const baseLineWidth = 4
const baseFontSize = 40

let crosshairBlackOutline = {
  size = FLEX
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = 0.5 * baseLineWidth
  fillColor = 0
  color = blackColor
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  commands = [
    [VECTOR_LINE, 0, 0, 30, 0],
    [VECTOR_LINE, 0, 0, 0, 30],
    [VECTOR_LINE, 0, 100, 30, 100],
    [VECTOR_LINE, 0, 100, 0, 70],
    [VECTOR_LINE, 100, 0, 100, 30],
    [VECTOR_LINE, 100, 0, 70, 0],
    [VECTOR_LINE, 100, 100, 100, 70],
    [VECTOR_LINE, 100, 100, 70, 100],

    [VECTOR_LINE, 51, 90, 51, 60],
    [VECTOR_LINE, 51, 10, 51, 40],
    [VECTOR_LINE, 10, 51, 40, 51],
    [VECTOR_LINE, 60, 51, 90, 51],
  ]
}

let crosshair = {
  size = const [ph(10), ph(10)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  fillColor = 0
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  commands = [
    [VECTOR_LINE, 1, 1, 30, 1],
    [VECTOR_LINE, 1, 1, 1, 30],
    [VECTOR_LINE, 1, 99, 30, 99],
    [VECTOR_LINE, 1, 99, 1, 70],
    [VECTOR_LINE, 99, 1, 99, 30],
    [VECTOR_LINE, 99, 1, 70, 1],
    [VECTOR_LINE, 99, 99, 99, 70],
    [VECTOR_LINE, 99, 99, 70, 99],

    [VECTOR_LINE, 50, 90, 50, 60],
    [VECTOR_LINE, 50, 10, 50, 40],
    [VECTOR_LINE, 10, 50, 40, 50],
    [VECTOR_LINE, 60, 50, 90, 50],
  ]
  children = crosshairBlackOutline
}


let target = @() {
  size = const [ph(4), ph(4)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = 0
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, -100, -100, -20, -20],
    [VECTOR_LINE, 100, 100, 20, 20],
    [VECTOR_LINE, -100, 100, -20, 20],
    [VECTOR_LINE, 100, -100, 20, -20],
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [ShellFPVTargetX.get(), ShellFPVTargetY.get()]
    }
  }
}


let noSignal = {
  size = FLEX
  rendObj = ROBJ_TEXT
  color = redColor
  font = Fonts.hud
  fontSize = baseFontSize
  text = "NO SIGNAL"
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
}

let timeOfFlight = @() {
  watch = ShellFPVTimeOfFlight
  size = SIZE_TO_CONTENT
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  pos = const [0, ph(7)]
  rendObj = ROBJ_TEXT
  color = baseColor
  font = Fonts.hud
  fontSize = baseFontSize
  text = ShellFPVTimeOfFlight.get() >= 0.0 ? $"{ShellFPVTimeOfFlight.get().tointeger()}{loc("measureUnits/seconds")}" : ""
}

let area = @() {
  watch = [ShellFPVMaxZoom]
  size = [pw(100 * ShellFPVMaxZoom.get()), ph(100 * ShellFPVMaxZoom.get())]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = 0
  lineWidth = 0.5 * baseLineWidth
  commands = [
    [VECTOR_LINE, 100, 100, 85, 100],
    [VECTOR_LINE, 100, 100, 100, 80],
    [VECTOR_LINE, 0, 0, 0, 20],
    [VECTOR_LINE, 0, 0, 15, 0],
    [VECTOR_LINE, 0, 100, 15, 100],
    [VECTOR_LINE, 0, 100, 0, 80],
    [VECTOR_LINE, 100, 0, 100, 20],
    [VECTOR_LINE, 100, 0, 85, 0],
  ]
}

let angleLimits = @() {
  watch = [ShellFPVCameraLimX, ShellFPVCameraLimY]
  size = const [pw(14), ph(14)]
  pos = const [pw(43), ph(73)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = 0
  lineWidth = 0.5 * baseLineWidth
  commands = [
    [VECTOR_LINE, 100, 100, 85, 100],
    [VECTOR_LINE, 100, 100, 100, 80],
    [VECTOR_LINE, 0, 0, 0, 20],
    [VECTOR_LINE, 0, 0, 15, 0],
    [VECTOR_LINE, 0, 100, 15, 100],
    [VECTOR_LINE, 0, 100, 0, 80],
    [VECTOR_LINE, 100, 0, 100, 20],
    [VECTOR_LINE, 100, 0, 85, 0],

    [VECTOR_LINE, 50 * (1 + ShellFPVCameraLimX.get()) + 1, 50 * (1 - ShellFPVCameraLimY.get()), 50 * (1 + ShellFPVCameraLimX.get()) + 3, 50 * (1 - ShellFPVCameraLimY.get())],
    [VECTOR_LINE, 50 * (1 + ShellFPVCameraLimX.get()) - 1, 50 * (1 - ShellFPVCameraLimY.get()), 50 * (1 + ShellFPVCameraLimX.get()) - 3, 50 * (1 - ShellFPVCameraLimY.get())],
    [VECTOR_LINE, 50 * (1 + ShellFPVCameraLimX.get()), 50 * (1 - ShellFPVCameraLimY.get()) + 2, 50 * (1 + ShellFPVCameraLimX.get()), 50 * (1 - ShellFPVCameraLimY.get()) + 5],
    [VECTOR_LINE, 50 * (1 + ShellFPVCameraLimX.get()), 50 * (1 - ShellFPVCameraLimY.get()) - 2, 50 * (1 + ShellFPVCameraLimX.get()), 50 * (1 - ShellFPVCameraLimY.get()) - 5],
  ]
}

let page = @(){
  watch = [ShellFPVModeValid, ShellFPVHasTarget, ShellFPVAnglesLocked]
  size = FLEX
  children = [
    ShellFPVModeValid.get() ? crosshair : noSignal,
    ShellFPVModeValid.get() ? area : null,
    ShellFPVModeValid.get() ? angleLimits : null,
    ShellFPVHasTarget.get() && !ShellFPVAnglesLocked.get() ? target : null,
    ShellFPVModeValid.get() ? timeOfFlight : null
  ]
}

return page
