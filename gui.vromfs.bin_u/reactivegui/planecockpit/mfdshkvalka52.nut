from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked

let { Roll, ClimbSpeed, Speed, Altitude, Tangage, CompassValue, Overload } = require("%rGui/planeState/planeFlyState.nut")
let { mpsToKmh, weaponTriggerName } = require("%rGui/planeIlses/ilsConstants.nut")
let string = require("string")
let { TargetRadius } = require("%rGui/hud/targetTrackerState.nut")
let { AimLockDist, AimLockValid, RocketMode, BombCCIPMode, MfdCameraZoom } = require("%rGui/planeState/planeToolsState.nut")
let { IsInsideLaunchZoneYawPitch, IsInsideLaunchZoneDist, TurretYaw, TurretPitch,
 RocketsSalvo, BombsSalvo } = require("%rGui/airState.nut")
let { degToRad } = require("%sqstd/math_ex.nut")
let { sin, cos, PI, fabs, round } = require("math")
let { cvt } = require("dagor.math")
let { CurWeaponName, ShellCnt, SelectedTrigger, HasOperatedShell } = require("%rGui/planeState/planeWeaponState.nut")
let { GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")

let baseColor = Color(10, 255, 10)
let baseLineWidth = 3
let baseFontSize = 15
let whiteColor = Color(255, 255, 255)

let frame = {
  size = flex()
  children = [
    {
      pos = [0, 0]
      size = static [pw(100), ph(12)]
      rendObj = ROBJ_SOLID
      color = Color(0, 0, 0)
    }
    {
      pos = [0, 0]
      size = static [pw(12), ph(100)]
      rendObj = ROBJ_SOLID
      color = Color(0, 0, 0)
    }
    {
      pos = [0, ph(88)]
      size = static [pw(100), ph(12)]
      rendObj = ROBJ_SOLID
      color = Color(0, 0, 0)
    }
    {
      pos = [pw(88), 0]
      size = static [pw(12), ph(100)]
      rendObj = ROBJ_SOLID
      color = Color(0, 0, 0)
    }
  ]
}

let ClimbSpeedDir = Computed(@() ClimbSpeed.get() >= 0.0 ? 1 : -1)
let ClimbSpeedVal = Computed(@() (ClimbSpeed.get() * 10.0).tointeger())
let climbSpeed = @(){
  size = static [pw(7), ph(4)]
  pos = [pw(80), ph(48)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = Color(0, 0, 0)
  lineWidth = baseLineWidth * 0.5
  halign = ALIGN_RIGHT
  valign = ALIGN_CENTER
  padding = static [0, 2]
  commands = [
    [VECTOR_RECTANGLE, 0, 0, 100, 100]
  ]
  children = [
    @(){
      watch = ClimbSpeedDir
      size = flex()
      pos = [0, ClimbSpeedDir.get() > 0 ? 0 : ph(100)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      fillColor = Color(0, 0, 0)
      lineWidth = baseLineWidth * 0.5
      commands = [
        [VECTOR_POLY, 5, ClimbSpeedDir.get() * -20, 95, ClimbSpeedDir.get() * -20, 50, ClimbSpeedDir.get() * -100, 5, ClimbSpeedDir.get() * -20]
      ]
    }
    @(){
      watch = ClimbSpeedVal
      size = SIZE_TO_CONTENT
      pos = [0, ph(10)]
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      font = Fonts.ils31
      text = string.format("%.1f", ClimbSpeed.get())
    }
  ]
}

let airSymbol = @(){
  size = static [pw(70), ph(70)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth
  color = baseColor
  commands = [
    [VECTOR_LINE, -100, 0, -70, 0],
    [VECTOR_LINE, -70, 0, -70, 10],
    [VECTOR_LINE, 100, 0, 70, 0],
    [VECTOR_LINE, 70, 0, 70, 10]
  ]
}

let airSymbolWrap = {
  size = static [pw(30), ph(33)]
  pos = [pw(50), ph(50)]
  children = airSymbol
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      rotate = Roll.get()
      pivot = [0, 0]
    }
  }
}

let horizontMarks = {
  size = static [pw(76), ph(80)]
  pos = [pw(12), ph(10)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 12, 50, 19, 50],
    [VECTOR_LINE, 81, 50, 88, 50]
  ]
}

let TargetRadiusVal = Computed(@() AimLockValid.get() ? TargetRadius.get().tointeger() : 10)
let targetMark = @(){
  watch = TargetRadiusVal
  size = [TargetRadiusVal.get(), TargetRadiusVal.get()]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = Color(255, 255, 255)
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, -100, -100, 100, -100],
    [VECTOR_LINE, 100, -100, 100, 100],
    [VECTOR_LINE, 100, 100, -100, 100],
    [VECTOR_LINE, -100, -100, -100, 100],
    [VECTOR_COLOR, Color(0, 0, 0)],
    [VECTOR_LINE_DASHED, -100, -100, 100, -100, 15, 15],
    [VECTOR_LINE_DASHED, 100, -100, 100, 100, 15, 15],
    [VECTOR_LINE_DASHED, 100, 100, -100, 100, 15, 15],
    [VECTOR_LINE_DASHED, -100, -100, -100, 100, 15, 15],
    [VECTOR_LINE_DASHED, 0, 0, 0, 100, 15, 15]
  ]
}

let atgmLaunchPermitted = @() {
  watch = [IsInsideLaunchZoneYawPitch, IsInsideLaunchZoneDist]
  size = flex()
  children = IsInsideLaunchZoneYawPitch.get() && IsInsideLaunchZoneDist.get() ?
    @() {
      size = flex()
      rendObj = ROBJ_TEXT
      pos = [pw(48), ph(73)]
      color = baseColor
      fontSize = 30
      font = Fonts.ils31
      text = "ПР"
    }
  : null
}

let DistToTarget = Computed(@() (AimLockDist.get() / 10).tointeger())
let distToTarget = @(){
  watch = AimLockValid
  size = static [pw(16), ph(8)]
  pos = [pw(42), ph(79)]
  rendObj = ROBJ_SOLID
  color = Color(0, 0, 0)
  halign = ALIGN_RIGHT
  valign = ALIGN_BOTTOM
  padding = static [0, 5]
  children = AimLockValid.get() ? [
    @(){
      watch = DistToTarget
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = 35
      text = string.format("%.2f", DistToTarget.get() / 100.0)
    }
  ] : null
}

let SpeedValue = Computed(@() round(Speed.get() * mpsToKmh).tointeger())
let speed = @() {
  size = SIZE_TO_CONTENT
  pos = [pw(35), ph(12)]
  valign = ALIGN_BOTTOM
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      watch = SpeedValue
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ils31
      fontSize = 30
      text = SpeedValue.get().tointeger()
    }
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      text = "км/ч"
    }
  ]
}

let AltValue = Computed(@() Altitude.get().tointeger())
let altitude = @() {
  watch = AltValue
  size = SIZE_TO_CONTENT
  pos = [pw(60), ph(12)]
  rendObj = ROBJ_TEXT
  color = baseColor
  font = Fonts.ils31
  fontSize = 30
  text = AltValue.get().tointeger()
}

let labels = {
  size = flex()
  children = [
    {
      rendObj = ROBJ_VECTOR_CANVAS
      pos = [pw(3), ph(5.5)]
      size = static [pw(94), ph(89)]
      color = whiteColor
      fillColor = Color(0, 0, 0, 0)
      lineWidth = 1
      commands = [
        [VECTOR_RECTANGLE, 0, 0, 100, 100]
      ]
    }
    {
      rendObj = ROBJ_SOLID
      color = baseColor
      size = static [pw(6), ph(3)]
      pos = [pw(83), ph(2)]
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(12), ph(2)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ПЛТ"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(24), ph(2)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "НВГ"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(36), ph(2)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ОВО"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(48), ph(2)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "БКС"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(60), ph(2)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "БКО"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(72), ph(2)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "РЛС"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(84), ph(2)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ОПС"
    }
    {
      rendObj = ROBJ_SOLID
      color = baseColor
      size = static [pw(8), ph(3)]
      pos = [pw(82), ph(95)]
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(12), ph(95)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ОПЦ1"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(24), ph(95)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "СКАН"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(36), ph(95)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "СКЛО"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(48), ph(95)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ПУ"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(60), ph(95)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "НАБЛ"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(72), ph(95)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "АС"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(84), ph(95)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ПКС"
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(5)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "Т\nВ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(15)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "Т\nР\nС\nФ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(32)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "У\nЛ\n1"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(46)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "Р\nМ\nК"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(60)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "К\nО\nР\nР"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(77)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "П\nР\nЦ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(88)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "2\nЦ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(97.5), ph(3)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = 14
      text = "С\nТ\nО\nП"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(97.5), ph(17)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = 14
      text = "С\nВ\nР"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(97.5), ph(30)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = 14
      text = "Ш\nР\nС"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(97.5), ph(42)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = 14
      text = "С\nЛ\nО\nИ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(97.5), ph(56)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = 14
      text = "Н\nА\nЗ\nМ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(97.5), ph(71)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = 14
      text = "Н\nП\nД\nВ"
      behavior = Behaviors.TextArea
    }
    {
      rendObj = ROBJ_TEXTAREA
      size = SIZE_TO_CONTENT
      pos = [pw(97.5), ph(86)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = 14
      text = "А\nС\nП"
      behavior = Behaviors.TextArea
    }
  ]
}

function generateTurPitchLine(num) {
  return {
    size = static [pw(100), ph(10)]
    halign = ALIGN_RIGHT
    children = [
      {
        rendObj = ROBJ_SOLID
        size = static [pw(50), 1]
        color = baseColor
      },
      (num != 0 ? {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        pos = [0, num < 0 ? ph(10) : ph(-30)]
        color = baseColor
        font = Fonts.ils31
        fontSize = 10
        text = num.tointeger().tostring()
      } : null)
    ]
  }
}

function turretPitchGrid() {
  let children = []
  for (local i = 20.0; i >= -60.0;) {
    children.append(generateTurPitchLine(i))
    i -= i <= 10.0 && i > -10.0 ? 5 : 10
    if (i == -30.0)
      i -= 10.0
  }

  return {
    size = static [pw(3), ph(70)]
    pos = [pw(93), ph(23)]
    flow = FLOW_VERTICAL
    children = children
  }
}

function getTurretPitchOffset(pitch) {
  if (pitch > 10)
    return cvt(pitch, 20, 10, -21, -14)
  if (pitch >= -10)
    return cvt(pitch, 10, -10, -14, 14)
  if (pitch >= -20)
    return cvt(pitch, -10, -20, 14, 21)
  if (pitch >= -40)
    return cvt(pitch, -20, -40, 21, 28)
  return cvt(pitch, -40, -60, 28, 42)
}

let TurretPitchVal = Computed(@() (-90.0 + TurretPitch.get() * 180.0).tointeger())
let TurretPitchMarkPos = Computed(@() 44 + min(0, getTurretPitchOffset(TurretPitchVal.get())))
let TurretPitchMarkSize = Computed(@() fabs(getTurretPitchOffset(TurretPitchVal.get())))
let turretPitch = {
  size = flex()
  children = [
    turretPitchGrid()
    {
      size = static [1, ph(63)]
      rendObj = ROBJ_SOLID
      color = baseColor
      pos = [pw(96), ph(23)]
    }
    @() {
      watch = TurretPitchVal
      rendObj = ROBJ_TEXT
      size = static [pw(5),ph(4)]
      halign = ALIGN_RIGHT
      pos = [pw(89), ph(43)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 18
      padding = static [1, 3]
      text = TurretPitchVal.get().tostring()
    }
    {
      rendObj = ROBJ_VECTOR_CANVAS
      size = static [pw(5), ph(4)]
      pos = [pw(89), ph(43)]
      color = baseColor
      fillColor = Color(0, 0, 0, 0)
      lineWidth = 1
      commands = [
        [VECTOR_RECTANGLE, 0, 0, 100, 100]
      ]
    }
    @() {
      watch = [TurretPitchMarkPos, TurretPitchMarkSize]
      rendObj = ROBJ_SOLID
      color = baseColor
      pos = [pw(96.2), ph(TurretPitchMarkPos.get())]
      size = [baseLineWidth, ph(TurretPitchMarkSize.get())]
    }
  ]
}

function pitch(height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = i * step

    children.append(generateFunc(num))
  }

  return {
    size = flex()
    pos = [0, ph(50)]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * ((90.0 - Tangage.get()) * 0.008 - 0.01)]
      }
    }
  }
}

function generatePitchLine(num) {
  return {
    size = static [flex(), ph(10)]
    flow = FLOW_HORIZONTAL
    halign = ALIGN_RIGHT
    children = [
      (num % 10 == 0 ? {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        fontSize = baseFontSize
        font = Fonts.hud
        text = string.format("%d", num)
      } : null)
      {
        pos = [0, ph(20)]
        size = [pw(num % 10 == 0 ? 30 : 15), 2]
        rendObj = ROBJ_SOLID
        color = baseColor
      }
    ]
  }
}


function pitchWrap(height) {
  return {
    size = static [pw(9), ph(40)]
    pos = [pw(1), ph(30)]
    clipChildren = true
    children = [
      pitch(height, generatePitchLine)
    ]
  }
}

let TangageValue = Computed(@() Tangage.get().tointeger())
let pitchLabels = {
  size = flex()
  children = [
    {
      size = static [pw(1), ph(1)]
      pos = [pw(11), ph(50)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      fillColor = baseColor
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_POLY, 0, 0, 100, -100, 100, 100]
      ]
    }
    @(){
      size = static [pw(5.5), ph(4)]
      pos = [pw(13), ph(48)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      fillColor = Color(0, 0, 0)
      lineWidth = baseLineWidth * 0.5
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
      padding = static [0, 2]
      commands = [
        [VECTOR_RECTANGLE, 0, 0, 100, 100]
      ]
      children = [
        @(){
          watch = TangageValue
          size = SIZE_TO_CONTENT
          pos = [0, ph(5)]
          rendObj = ROBJ_TEXT
          color = baseColor
          fontSize = baseFontSize
          font = Fonts.ils31
          text = TangageValue.get().tostring()
        }
      ]
    }
  ]
}

let optCompassVal = Computed(@() degToRad((CompassValue.get() - 180.0 + TurretYaw.get() * 180.0).tointeger()))
let opticCompass = @(){
  watch = optCompassVal
  size = ph(20)
  pos = [pw(5), ph(71)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = 1
  commands = [
    [VECTOR_ELLIPSE, 50, 50, 50, 50],
    [VECTOR_LINE, 50, 50, 50 + 50 * cos(optCompassVal.get() - PI * 0.25), 50 + 50 * sin(optCompassVal.get() - PI * 0.25)],
    [VECTOR_LINE, 50, 50, 50 + 50 * cos(optCompassVal.get() + PI * 0.25), 50 + 50 * sin(optCompassVal.get() + PI * 0.25)]
  ]
}

let AtgmMode = Computed(@() SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER)
let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)
let GunMode = Computed(@() !RocketMode.get() && !BombCCIPMode.get() && !AtgmMode.get() && !isAAMMode.get())
let shellName = @(){
  watch = [CurWeaponName, GunMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(88.5)]
  color = baseColor
  fontSize = baseFontSize
  font = Fonts.ils31
  text = GunMode.get() ? "НПУ" : (CurWeaponName.get() && CurWeaponName.get() != "" ? loc_checked(string.format("%s/ils_28", CurWeaponName.get())) : "")
}

let shellCnt = @() {
  watch = ShellCnt
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(88), ph(88.5)]
  color = baseColor
  fontSize = baseFontSize
  font = Fonts.ils31
  text = ShellCnt.get()
}


function getBurstLength(is_atgm, is_rocket, rocket_salvo, is_aam, is_bomb, bomb_salvo) {
  local name = ""
  if (is_atgm)
    name = "ДЛ"
  else if (is_rocket) {
    if (rocket_salvo < 0 || rocket_salvo > 8)
      name = "ДЛ"
    else if (rocket_salvo <= 2)
      name = "КОР"
    else if (rocket_salvo <= 8)
      name = "СР"
  }
  else if (is_bomb) {
    if (bomb_salvo < 0 || bomb_salvo > 8)
      name = "ДЛ"
    else if (bomb_salvo <= 2)
      name = "КОР"
    else if (bomb_salvo <= 8)
      name = "СР"
  }
  else if (is_aam)
    name = "БСТ"
  else
    name = "КОР"
  return name
}

let burstLenStr = Computed(@() getBurstLength(AtgmMode.get(), RocketMode.get(), RocketsSalvo.get(), isAAMMode.get(), BombCCIPMode.get(), BombsSalvo.get()) )
let burstLength = @(){
  watch = burstLenStr
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(91.5)]
  color = baseColor
  fontSize = baseFontSize
  font = Fonts.ils31
  text = burstLenStr.get()
}

let selectedStation = @(){
  watch = [RocketMode, AtgmMode, isAAMMode, CurWeaponName, GunMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(86), ph(91.5)]
  color = baseColor
  fontSize = baseFontSize
  font = Fonts.ils31
  text = AtgmMode.get() ? loc_checked(string.format("%s/ils_28_st", CurWeaponName.get())) : isAAMMode.get() ? "ППС" : RocketMode.get() || BombCCIPMode.get() ? "ВНЕТШ" : ""
}

let gunnerControl = {
  size = ph(2)
  pos= [pw(75), ph(80)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = 2
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 100, 100],
    [VECTOR_LINE, -70.7, -70.7, 70.7, 70.7],
    [VECTOR_LINE, -70.7, 70.7, 70.7, -70.7]
  ]
}

function generateTurYawLine(num) {
  return {
    size = [num % 30 == 0 && num != 120 ? pw(10) : pw(5), ph(100)]
    children = [
      {
        rendObj = ROBJ_SOLID
        size = static [1, ph(50)]
        color = baseColor
      },
      (num != 0 ? {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        pos = [num == -135 ? pw(-84) : (num == -120 ? pw(-42) : (num < 0 ? pw(-35) : baseLineWidth)), baseLineWidth]
        color = baseColor
        font = Fonts.ils31
        fontSize = 10
        text = num.tointeger().tostring()
      } : null)
    ]
  }
}

function turretYawGrid() {
  let children = []
  for (local i = -135.0; i <= 135.0;) {
    children.append(generateTurYawLine(i))
    i += i < -120.0 || i >= 120.0 ? 15 : 30
  }

  return {
    size = static [pw(84), ph(3)]
    pos = [pw(12), ph(8)]
    flow = FLOW_HORIZONTAL
    children = children
  }
}

let TurretYawVal = Computed(@() (-90.0 + TurretYaw.get() * 180.0).tointeger())
let TurretYawMarkPos = Computed(@() 50 + cvt(TurretYawVal.get(), -135, 0, -38, 0))
let TurretYawMarkSize = Computed(@() fabs(cvt(TurretYawVal.get(), -135, 135, -37, 37)))
let turretYaw = {
  size = flex()
  children = [
    turretYawGrid()
    {
      size = static [pw(75), 1]
      rendObj = ROBJ_SOLID
      color = baseColor
      pos = [pw(12), ph(8)]
    }
    @() {
      watch = TurretYawVal
      rendObj = ROBJ_TEXT
      size = static [pw(6),ph(4)]
      halign = ALIGN_RIGHT
      pos = [pw(47), ph(10)]
      color = baseColor
      font = Fonts.ils31
      fontSize = 18
      padding = static [1, 3]
      text = TurretYawVal.get().tostring()
    }
    {
      rendObj = ROBJ_VECTOR_CANVAS
      size = static [pw(6), ph(4)]
      pos = [pw(47), ph(10)]
      color = baseColor
      fillColor = Color(0, 0, 0, 0)
      lineWidth = 1
      commands = [
        [VECTOR_RECTANGLE, 0, 0, 100, 100]
      ]
    }
    @() {
      watch = [TurretYawMarkPos, TurretYawMarkSize]
      rendObj = ROBJ_SOLID
      color = baseColor
      pos = [pw(TurretYawMarkPos.get()), ph(7)]
      size = [pw(TurretYawMarkSize.get()), baseLineWidth]
    }
  ]
}

let TAMark = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.get() ? [
    {
      size = SIZE_TO_CONTENT
      pos = [pw(90), ph(17)]
      rendObj = ROBJ_TEXT
      color = Color(255, 255, 0)
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ЛД"
    }
  ] : null
}

let operatedMark = @(){
  watch = HasOperatedShell
  size = flex()
  children = HasOperatedShell.get() ? [
    {
      size = SIZE_TO_CONTENT
      pos = [pw(89), ph(35)]
      rendObj = ROBJ_TEXT
      color = Color(255, 255, 0)
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ЛЛКУ"
    }
  ] : null
}

let OverloadVal = Computed(@() (Overload.get() * 10.0).tointeger())
let OverloadCircleAngle = Computed(@() min((Overload.get() - 1.0) * 180.0, 359.0).tointeger() - 90)
let overload = {
  size = ph(9)
  pos = [pw(4.5), ph(15)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = whiteColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = 1
  commands = [
    [VECTOR_ELLIPSE, 50, 50, 50, 50],
    [VECTOR_ELLIPSE, 50, 50, 30, 30],
    [VECTOR_LINE, 0, 50, 20, 50],
    [VECTOR_LINE, 80, 50, 100, 50],
    [VECTOR_LINE, 50, 0, 50, 20],
    [VECTOR_LINE, 50, 80, 50, 100]
  ]
  children = [
    @(){
      watch = OverloadVal
      size = flex()
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      rendObj = ROBJ_TEXT
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = string.format("%.1f", OverloadVal.get() / 10.0)
    }
    @(){
      watch = OverloadCircleAngle
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = Color(0, 100, 255, 200)
      lineWidth = 5
      fillColor = Color(0, 0, 0, 0)
      commands = [
        [VECTOR_SECTOR, 50, 50, 40, 40, -90, OverloadCircleAngle.get()]
      ]
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(45), ph(-40)]
      rendObj = ROBJ_TEXT
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "1"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(42), ph(110)]
      rendObj = ROBJ_TEXT
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "2"
    }
  ]
}

let zoom = {
  size = static [pw(12), ph(1)]
  rendObj = ROBJ_VECTOR_CANVAS
  pos = [pw(5), ph(92)]
  color = whiteColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = 1
  commands = [
    [VECTOR_RECTANGLE, 0, 0, 100, 100]
  ]
  children = [
    @(){
      watch = MfdCameraZoom
      rendObj = ROBJ_SOLID
      size = [pw(MfdCameraZoom.get() * 100.0), 4]
      color = baseColor
    }
  ]
}

function Skval(width, height) {
  return {
    size = [width, height]
    children = [
      frame
      climbSpeed
      horizontMarks
      airSymbolWrap
      targetMark
      atgmLaunchPermitted
      distToTarget
      speed
      altitude
      labels
      pitchWrap(height)
      pitchLabels
      opticCompass
      turretPitch
      shellName
      shellCnt
      burstLength
      selectedStation
      gunnerControl
      turretYaw
      TAMark
      overload
      zoom
      operatedMark
    ]
  }
}

return Skval