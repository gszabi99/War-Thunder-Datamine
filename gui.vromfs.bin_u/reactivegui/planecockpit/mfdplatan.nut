from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked
let { TurretYaw, TurretPitch } = require("%rGui/airState.nut")
let { cvt } = require("dagor.math")
let { AimLockDist, AimLockValid, RocketMode, BombingMode, TimeBeforeBombRelease } = require("%rGui/planeState/planeToolsState.nut")
let { get_local_unixtime, unixtime_to_local_timetbl } = require("dagor.time")
let string = require("string")
let { IsTargetTracked } = require("%rGui/hud/targetTrackerState.nut")
let { CurWeaponName } = require("%rGui/planeState/planeWeaponState.nut")

let baseColor = Color(70, 255, 0)
let baseLineWidth = 3
let baseFontSize = 15
let whiteColor = Color(255, 255, 255)

let crosshair = @(){
  watch = IsTargetTracked
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  color = whiteColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 50, 50, 50, 50],
    [VECTOR_LINE, 35, 40, 37, 40],
    [VECTOR_LINE, 35, 40, 35, 42],
    [VECTOR_LINE, 65, 40, 63, 40],
    [VECTOR_LINE, 65, 40, 65, 42],
    [VECTOR_LINE, 35, 60, 37, 60],
    [VECTOR_LINE, 35, 60, 35, 58],
    [VECTOR_LINE, 65, 60, 63, 60],
    [VECTOR_LINE, 65, 60, 65, 58]
  ]
  children = !IsTargetTracked.get() ? {
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = whiteColor
    lineWidth = baseLineWidth
    commands = [
      [VECTOR_LINE, 0, 50, 47, 50],
      [VECTOR_LINE, 53, 50, 100, 50],
      [VECTOR_LINE, 50, 0, 50, 47],
      [VECTOR_LINE, 50, 53, 50, 100]
    ]
  } : {
    size = [pw(14), ph(10)]
    pos = [pw(43), ph(45)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = whiteColor
    lineWidth = baseLineWidth
    commands = [
      [VECTOR_LINE, 0, 50, 30, 50],
      [VECTOR_LINE, 70, 50, 100, 50],
      [VECTOR_LINE, 50, 0, 50, 30],
      [VECTOR_LINE, 50, 70, 50, 100],
      [VECTOR_LINE, 10, 15, 30, 15],
      [VECTOR_LINE, 10, 15, 10, 35],
      [VECTOR_LINE, 90, 15, 70, 15],
      [VECTOR_LINE, 90, 15, 90, 35],
      [VECTOR_LINE, 10, 85, 30, 85],
      [VECTOR_LINE, 10, 85, 10, 65],
      [VECTOR_LINE, 90, 85, 70, 85],
      [VECTOR_LINE, 90, 85, 90, 65]
    ]
  }
}

let TurretYawMarkPos = Computed(@() (TurretYaw.get() * 100.0).tointeger())
let turretYaw = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(20), ph(3)]
  pos = [pw(40), ph(10)]
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 0, 100, 100, 100],
    [VECTOR_LINE, 0, 0, 0, 100],
    [VECTOR_LINE, 50, 0, 50, 100],
    [VECTOR_LINE, 100, 0, 100, 100]
  ]
  children = @(){
    watch = TurretYawMarkPos
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = baseColor
    lineWidth = baseLineWidth
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_POLY, TurretYawMarkPos.get(), 100, TurretYawMarkPos.get() - 8, 30, TurretYawMarkPos.get() + 8, 30]
    ]
  }
}

let TurretPitchMarkPos = Computed(@() 5 + cvt(-160.0 + TurretPitch.get() * 160.0, 0, -160, 0, 95).tointeger())
let turretPitch = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(40)]
  pos = [pw(90), ph(48)]
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 0, 0, 0, 100],
    [VECTOR_LINE, 0, 0, 100, 0],
    [VECTOR_LINE, 0, 100, 100, 100],
    [VECTOR_LINE, 0, 5, 100, 5]
  ]
  children = @(){
    watch = TurretPitchMarkPos
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = baseColor
    lineWidth = baseLineWidth
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_POLY, 0, TurretPitchMarkPos.get(), 60, TurretPitchMarkPos.get() - 4, 60, TurretPitchMarkPos.get() + 4]
    ]
  }
}

let DistToTarget = Computed(@() AimLockDist.get() < 20000.0 ? cvt(AimLockDist.get(), 0.0, 20000.0, 100, 28.57).tointeger() : cvt(AimLockDist.get(), 20000, 40000.0, 28.57, 0).tointeger())
let targetDistance = {
  size = [pw(1.5), ph(50)]
  pos = [pw(10), ph(25)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 100, 0, 100, 100],
    [VECTOR_LINE, 0, 0, 100, 0],
    [VECTOR_LINE, 0, 7.14, 100, 7.14],
    [VECTOR_LINE, 0, 14.29, 100, 14.29],
    [VECTOR_LINE, 0, 21.43, 100, 21.43],
    [VECTOR_LINE, 0, 28.57, 100, 28.57],
    [VECTOR_LINE, 0, 35.7, 100, 35.7],
    [VECTOR_LINE, 0, 42.86, 100, 42.86],
    [VECTOR_LINE, 0, 50, 100, 50],
    [VECTOR_LINE, 0, 57.14, 100, 57.14],
    [VECTOR_LINE, 0, 64.29, 100, 64.29],
    [VECTOR_LINE, 0, 71.43, 100, 71.43],
    [VECTOR_LINE, 0, 78.57, 100, 78.57],
    [VECTOR_LINE, 0, 85.7, 100, 85.7],
    [VECTOR_LINE, 0, 92.86, 100, 92.86],
    [VECTOR_LINE, 0, 100, 100, 100]
  ]
  children = [
    {
      size = [pw(300), SIZE_TO_CONTENT]
      pos = [pw(-320), -baseFontSize * 0.5]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = baseFontSize
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = Color(255, 0, 0)
      text = "40"
      halign = ALIGN_RIGHT
    }
    {
      size = [pw(300), SIZE_TO_CONTENT]
      pos = [pw(-320), ph(12)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = baseFontSize
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = Color(255, 0, 0)
      text = "30"
      halign = ALIGN_RIGHT
    }
    {
      size = [pw(300), SIZE_TO_CONTENT]
      pos = [pw(-320), ph(26)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = baseFontSize
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = Color(255, 0, 0)
      text = "20"
      halign = ALIGN_RIGHT
    }
    {
      size = [pw(300), SIZE_TO_CONTENT]
      pos = [pw(-320), ph(40)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = baseFontSize
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = Color(255, 0, 0)
      text = "16"
      halign = ALIGN_RIGHT
    }
    {
      size = [pw(300), SIZE_TO_CONTENT]
      pos = [pw(-320), ph(55)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = baseFontSize
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = Color(255, 0, 0)
      text = "12"
      halign = ALIGN_RIGHT
    }
    {
      size = [pw(300), SIZE_TO_CONTENT]
      pos = [pw(-320), ph(69)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = baseFontSize
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = Color(255, 0, 0)
      text = "8"
      halign = ALIGN_RIGHT
    }
    {
      size = [pw(300), SIZE_TO_CONTENT]
      pos = [pw(-320), ph(83)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = baseFontSize
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = Color(255, 0, 0)
      text = "4"
      halign = ALIGN_RIGHT
    }
    {
      size = [pw(300), SIZE_TO_CONTENT]
      pos = [pw(-320), ph(97)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = baseFontSize
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "0"
      halign = ALIGN_RIGHT
    }
    @(){
      watch = DistToTarget
      size = [pw(300), ph(3)]
      pos = [pw(100), ph(DistToTarget.get())]
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_LINE, 0, 0, 30, 0],
        [VECTOR_POLY, 30, 0, 60, -100, 60, -40, 100, -40, 100, 40, 60, 40, 60, 100]
      ]
    }
  ]
}

let localTime = @() {
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  pos = [pw(78), ph(10)]
  color = baseColor
  fontSize = baseFontSize * 1.4
  font = Fonts.hud
  text = "11:22:33"
  behavior = Behaviors.RtPropUpdate
  function update() {
    let time = unixtime_to_local_timetbl(get_local_unixtime())
    return {
      text = string.format("%02d:%02d:%02d", time.hour, time.min, time.sec)
    }
  }
}

let labels = {
  size = flex()
  children = [
    {
      rendObj = ROBJ_TEXTAREA
      pos = [5, ph(23)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "Т\nВ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_FRAME
      color = baseColor
      size = [pw(3), ph(10)]
      pos = [2, ph(22)]
      borderWidth = 2
    }
    {
      rendObj = ROBJ_TEXTAREA
      pos = [5, ph(36)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "Т\nП"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      pos = [5, ph(50)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "Г\n1"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      pos = [5, ph(64)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "Г\n2"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      pos = [5, ph(76)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "К\nА\nИ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      pos = [5, ph(89)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "П\nД\nВ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      pos = [pw(97), ph(8)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "Т\nМ\nС"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      pos = [pw(97), ph(20)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "П\nД\nЦ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      pos = [pw(97), ph(48)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "С\nТ\nБ"
      behavior = Behaviors.TextArea
    }
    @(){
      watch = AimLockValid
      size = flex()
      children = AimLockValid.get() ? {
        rendObj = ROBJ_FRAME
        color = baseColor
        size = [pw(3), ph(13)]
        pos = [pw(96.5), ph(46)]
        borderWidth = 2
      } : null
    }
    {
      rendObj = ROBJ_TEXTAREA
      pos = [pw(97), ph(62)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "Т\nЧ\nН"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      pos = [pw(97), ph(76)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "М\nТ\nБ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      pos = [pw(97), ph(89)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "С\nК\nН"
      behavior = Behaviors.TextArea
    }
    {
      pos = [pw(20), ph(97)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "А С"
    }
    {
      pos = [pw(32), ph(97)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "Р С П"
    }
    {
      pos = [pw(46), ph(97)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "У П У"
    }
    {
      pos = [pw(60), ph(97)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "А Л О"
    }
    {
      pos = [pw(75), ph(97)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = 15
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      text = "П Ш"
    }
  ]
}

let shellName = @() {
  watch = [CurWeaponName, RocketMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(90)]
  color = baseColor
  fontSize = 20
  font = Fonts.ils31
  text = RocketMode.get() ? "НАР" : (CurWeaponName.get() && CurWeaponName.get() != "" ? loc_checked(CurWeaponName.get()) : "")
}

let timerValue = Computed(@() TimeBeforeBombRelease.get().tointeger())
let timerSector = Computed(@() cvt(TimeBeforeBombRelease.get(), 0.0, 60.0, -90.0, 250.0).tointeger())
let ccrpVisible = Computed(@() BombingMode.get() && TimeBeforeBombRelease.get() > 0.0)
let timerCCRP = @(){
  watch = ccrpVisible
  size = [pw(5), ph(5)]
  pos = [pw(10), ph(90)]
  children = ccrpVisible.get() ? @(){
    watch = timerSector
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = baseColor
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth
    commands = [
      [VECTOR_SECTOR, 0, 0, 100, 100, -90, timerSector.get()],
      [VECTOR_LINE, 0, -100, 0, -110]
    ]
    children = @(){
      watch = timerValue
      rendObj = ROBJ_TEXT
      size = [pw(200), ph(200)]
      pos = [pw(-100), ph(-100)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 25
      fontFx = FFT_GLOW
      fontFxFactor = 1
      fontFxColor = baseColor
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      text = timerValue.get().tostring()
    }
  } : null
}


function platan(width, height) {
  return {
    size = [width, height]
    children = [
      crosshair
      turretYaw
      turretPitch
      targetDistance
      localTime
      labels
      shellName
      timerCCRP
    ]
  }
}

return platan