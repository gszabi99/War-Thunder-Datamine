from "%rGui/globals/ui_library.nut" import *

let { Speed, CompassValue, Altitude } = require("%rGui/planeState/planeFlyState.nut")
let { abs } = require("%sqstd/math.nut")
let { cvt } = require("dagor.math")
let { AimLockYaw, AimLockPitch, AimLockValid, AimLockDist, HmdGunTargeting } = require("%rGui/planeState/planeToolsState.nut")
let { mpsToKnots, metrToFeet, weaponTriggerName } = require("%rGui/planeIlses/ilsConstants.nut")
let string = require("string")
let { ShellCnt, SelectedTrigger } = require("%rGui/planeState/planeWeaponState.nut")
let { AgmTimeToHit, IsLaserDesignatorEnabled, IsInsideLaunchZoneYawPitch, TurretYaw, TurretPitch,
 AgmLaunchZoneYawMin, AgmLaunchZoneYawMax, AgmLaunchZonePitchMin } = require("%rGui/airState.nut")

let baseColor = Color(255, 255, 255, 255)
let baseFontSize = 16
let baseLineWidth = 1

let CompassInt = Computed(@() ((360.0 + CompassValue.value) % 360.0).tointeger())
let generateCompassMark = function(num, width) {
  local text = num % 30 == 0 ? (num / 10).tostring() : ""
  if (num == 90)
    text = "E"
  else if (num == 180)
    text = "S"
  else if (num == 270)
    text = "W"
  else if (num == 0)
    text = "N"
  return {
    size = [width * 0.05, ph(100)]
    flow = FLOW_VERTICAL
    children = [
      {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        hplace = ALIGN_CENTER
        fontSize = baseFontSize
        font = Fonts.hud
        text = text
        behavior = Behaviors.RtPropUpdate
        update = @() {
          opacity = abs(num - CompassInt.value) < 20 ? 0.0 : 1.0
        }
      }
      {
        size = [baseLineWidth * 1.5, baseLineWidth * (num % 30 == 0 ? 10 : 4)]
        rendObj = ROBJ_SOLID
        color = baseColor
        hplace = ALIGN_CENTER
      }
    ]
  }
}

function compass(width, generateFunc) {
  let children = []
  let step = 10.0

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    let num = (i * step) % 360

    children.append(generateFunc(num, width))
  }
  let getOffset = @() (360.0 + CompassValue.value) * 0.005 * width
  return {
    size = flex()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [-getOffset() + 0.475 * width, 0]
      }
    }
    flow = FLOW_HORIZONTAL
    children = children
  }
}

function compassWrap(width, height, generateFunc) {
  return {
    size = [width * 0.5, height]
    pos = [width * 0.25, height * 0.05]
    clipChildren = true
    children = [
      compass(width * 0.5, generateFunc)
      {
        rendObj = ROBJ_SOLID
        color = baseColor
        size = [baseLineWidth * 2.0, ph(3)]
        pos = [width * 0.25 - baseLineWidth, baseFontSize + baseLineWidth * 10]
      }
    ]
  }
}

let compassVal = @(){
  size = [pw(8), ph(8)]
  pos = [pw(46), ph(2)]
  watch = CompassInt
  rendObj = ROBJ_TEXT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  color = baseColor
  font = Fonts.hud
  fontSize = baseFontSize * 1.4
  text = CompassInt.value.tostring()
}

let hmdPosX = Computed(@() cvt(AimLockYaw.value, -100.0, 100.0, 0.0, 80.0).tointeger())
let hmdPosY = Computed(@() cvt(AimLockPitch.value, 15.0, -45.0, 0.0, 66.7).tointeger())
function fieldOfRegard(width, height) {
  return {
    rendObj = ROBJ_BOX
    size = [ph(30), ph(10)]
    pos = [width * 0.5 - height * 0.15, ph(85)]
    fillColor = Color(0, 0, 0, 0)
    borderColor = baseColor
    borderWidth = baseLineWidth
    children = [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = baseColor
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_LINE, 50, 1, 50, 10],
          [VECTOR_LINE, 50, 90, 50, 99],
          [VECTOR_LINE, 12.5, 0, 12.5, 10],
          [VECTOR_LINE, 12.5, 90, 12.5, 100],
          [VECTOR_LINE, 87.5, 0, 87.5, 10],
          [VECTOR_LINE, 87.5, 90, 87.5, 100],
          [VECTOR_LINE, 1, 30, 5, 30],
          [VECTOR_LINE, 95, 30, 99, 30]
        ]
        children =
        @(){
          watch = [hmdPosX, hmdPosY]
          size = [pw(16.7), ph(33.3)]
          pos = [pw(hmdPosX.value), ph(hmdPosY.value)]
          rendObj = ROBJ_BOX
          fillColor = Color(0, 0, 0, 0)
          borderColor = baseColor
          borderWidth = baseLineWidth * 0.8
        }
      }
    ]
  }
}

let losReticle = {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 39, 50, 48, 50],
    [VECTOR_LINE, 52, 50, 61, 50],
    [VECTOR_LINE, 50, 42, 50, 48],
    [VECTOR_LINE, 50, 52, 50, 58]
  ]
  children = [
    @(){
      watch = AimLockValid
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      lineWidth = baseLineWidth
      commands = AimLockValid.value ? [
        [VECTOR_LINE, 44, 44, 47, 47],
        [VECTOR_LINE, 56, 44, 53, 47],
        [VECTOR_LINE, 44, 56, 47, 53],
        [VECTOR_LINE, 56, 56, 53, 53]
      ] : null
    }
  ]
}

let flir = {
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(10), ph(20)]
  color = baseColor
  font = Fonts.hud
  fontSize = baseFontSize
  text = "FLIR"
}

let tadsLabel = {
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(15), ph(86)]
  color = baseColor
  font = Fonts.hud
  fontSize = baseFontSize
  text = "TADS"
}

let fxdLabel = @(){
  watch = SelectedTrigger
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(78), ph(86)]
  color = baseColor
  font = Fonts.hud
  fontSize = baseFontSize
  text = SelectedTrigger.get() != weaponTriggerName.ROCKETS_TRIGGER && SelectedTrigger.get() != weaponTriggerName.AGM_TRIGGER &&
   HmdGunTargeting.get() ? "PHS" : "FXD"
}

let distVal = Computed(@() AimLockDist.value.tointeger())
let distance = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.value ? @(){
    watch = distVal
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    pos = [pw(24), ph(86)]
    color = baseColor
    font = Fonts.hud
    fontSize = baseFontSize
    text = string.format("*%d", AimLockDist.value.tointeger())
  } : null
}

let speedVal = Computed(@() (Speed.value * mpsToKnots).tointeger())
let speed = @(){
  watch = speedVal
  size = [pw(6), ph(3)]
  pos = [pw(28), ph(82)]
  rendObj = ROBJ_TEXT
  color = baseColor
  font = Fonts.hud
  fontSize = baseFontSize
  halign = ALIGN_RIGHT
  text = speedVal.value.tointeger()
}

let altVal = Computed(@() (Altitude.value * metrToFeet * (Altitude.value > 15.24 ? 0.1 : 1.0)).tointeger())
let altVisible = Computed(@() altVal.value < 143)
let altitude = @(){
  watch = altVisible
  size = flex()
  children = altVisible.value ? @(){
    watch = altVal
    size = SIZE_TO_CONTENT
    pos = [pw(65), ph(82)]
    rendObj = ROBJ_TEXT
    color = baseColor
    font = Fonts.hud
    fontSize = baseFontSize
    text = Altitude.value > 15.24 ? altVal.value.tointeger() * 10 : altVal.value.tointeger()
  } : null
}

let selectedWeapon = @(){
  watch = SelectedTrigger
  size = flex()
  pos = [pw(66), ph(86)]
  rendObj = ROBJ_TEXT
  color = baseColor
  font = Fonts.hud
  fontSize = baseFontSize
  text = SelectedTrigger.value == weaponTriggerName.ROCKETS_TRIGGER ? "PRKT" : (SelectedTrigger.value == weaponTriggerName.AGM_TRIGGER ? "PMSL" : "PGUN")
}

let weaponStatus = @(){
  watch = SelectedTrigger
  size = flex()
  pos = [pw(66), ph(90)]
  children = SelectedTrigger.value == weaponTriggerName.AGM_TRIGGER ?
    @(){
      watch = [AimLockValid, AgmTimeToHit, IsLaserDesignatorEnabled]
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      text = AgmTimeToHit.value > 0 ? (!IsLaserDesignatorEnabled.value ? "LASE 1 TRGT" : string.format("HF TOF=%d", AgmTimeToHit.value)) :
       (AimLockValid.value ? "PRI CHAN TRK" : "HI NORM")
    } :
    @(){
      watch = ShellCnt
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      text = string.format("ROUNDS  %d", ShellCnt.value)
    }
}

let yawLimit = Computed(@() TurretYaw.value > AgmLaunchZoneYawMax.value || TurretYaw.value < AgmLaunchZoneYawMin.value)
let inhibit = @(){
  watch = IsInsideLaunchZoneYawPitch
  size = flex()
  children = !IsInsideLaunchZoneYawPitch.value ?
    @(){
      watch = yawLimit
      size = [pw(20), ph(5)]
      pos = [pw(40), ph(78)]
      rendObj = ROBJ_TEXT
      color = baseColor
      halign = ALIGN_CENTER
      font = Fonts.hud
      fontSize = baseFontSize
      text = yawLimit.value ? "YAW LIMIT" : "PITCH LIMIT"
    } : null
}

function constraintBox(width, height) {
  return @(){
    watch = SelectedTrigger
    size = flex()
    children = SelectedTrigger.value == weaponTriggerName.AGM_TRIGGER ? @(){
      watch = AimLockValid
      rendObj = ROBJ_VECTOR_CANVAS
      size = [ph(10), ph(10)]
      color = baseColor
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth
      commands = !AimLockValid.value ?
        [
          [VECTOR_LINE_DASHED, -20, -20, 20, -20, 3, 3],
          [VECTOR_LINE_DASHED, 20, -20, 20, 20, 3, 3],
          [VECTOR_LINE_DASHED, 20, 20, -20, 20, 3, 3],
          [VECTOR_LINE_DASHED, -20, -20, -20, 20, 3, 3]
        ] :
        [
          [VECTOR_RECTANGLE, -50, -50, 100, 100]
        ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = AgmLaunchZoneYawMax.value != 0.5 ?
           [width * 0.5 + (TurretYaw.value - 0.5) / (AgmLaunchZoneYawMax.value - 0.5) * height * 0.2,
            height - (TurretPitch.value - AgmLaunchZonePitchMin.value) * height * 0.18] :
           [width * 0.5, height * (1.0 - TurretPitch.value * 0.18)]
        }
      }
    } : null
  }
}

function tads(width, height, is_apache) {
  return {
    size = [width, height]
    children = [
      compassWrap(width, height, generateCompassMark),
      compassVal,
      fieldOfRegard(width, height),
      losReticle,
      (is_apache ? flir : null),
      speed,
      altitude,
      (is_apache ? tadsLabel : null),
      distance,
      (is_apache ? fxdLabel : null),
      selectedWeapon,
      weaponStatus,
      inhibit,
      constraintBox(width, height)
    ]
  }
}

return tads