from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked
let { baseLineWidth, mpsToKmh, weaponTriggerName } = require("%rGui/planeIlses/ilsConstants.nut")
let { IlsColor, IlsLineScale, TargetPosValid, TargetPos, RocketMode, BombCCIPMode,
 AimLockPos, AimLockValid, AimLockDist, DistToTarget, IlsPosSize} = require("%rGui/planeState/planeToolsState.nut")
let { Roll, ClimbSpeed, Tangage, Speed, Altitude, CompassValue } = require("%rGui/planeState/planeFlyState.nut")
let string = require("string")
let { compassWrap } = require("%rGui/planeIlses/ilsCompasses.nut")
let { CurWeaponName, ShellCnt, SelectedTrigger, SelectedWeapSlot, TriggerPulled } = require("%rGui/planeState/planeWeaponState.nut")
let { IsHighRateOfFire, RocketsSalvo, BombsSalvo, IsAgmLaunchZoneVisible,
 IlsAtgmLaunchEdge1X, IlsAtgmLaunchEdge1Y, IlsAtgmLaunchEdge2X, IlsAtgmLaunchEdge2Y,
 IlsAtgmLaunchEdge3X, IlsAtgmLaunchEdge3Y, IlsAtgmLaunchEdge4X, IlsAtgmLaunchEdge4Y,
 IsInsideLaunchZoneYawPitch, IsInsideLaunchZoneDist, TurretYaw } = require("%rGui/airState.nut")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { setInterval, clearTimer } = require("dagor.workcycle")
let { round } = require("math")

let AtgmMode = Computed(@() SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER)
let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)

let rollIndicator = @(){
  watch = IlsColor
  size = static [pw(25), ph(25)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.get()
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, -100, 0, -80, 0],
    [VECTOR_LINE, 100, 0, 80, 0],
    [VECTOR_LINE, -86.6, 50, -69.3, 40],
    [VECTOR_LINE, -50, 86.6, -40, 69.3],
    [VECTOR_LINE, 50, 86.6, 40, 69.3],
    [VECTOR_LINE, 86.6, 50, 69.3, 40],
    [VECTOR_LINE, -86.9, 23.3, -77.3, 20.7],
    [VECTOR_LINE, 86.9, 23.3, 77.3, 20.7],
    [VECTOR_LINE, 63.6, 63.6, 56.6, 56.6],
    [VECTOR_LINE, -63.6, 63.6, -56.6, 56.6],
    [VECTOR_LINE, 0, 0, 0, 0]
  ]
  children = [
    {
      size = static [pw(70), ph(70)]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * IlsLineScale.get()
      color = IlsColor.get()
      commands = [
        [VECTOR_LINE, -100, 0, -60, 0],
        [VECTOR_LINE, -60, 0, -50, 10],
        [VECTOR_LINE, -50, 10, -40, 0],
        [VECTOR_LINE, -40, 0, -20, 0],
        [VECTOR_LINE, 20, 0, 40, 0],
        [VECTOR_LINE, 60, 0, 50, 10],
        [VECTOR_LINE, 50, 10, 40, 0],
        [VECTOR_LINE, 60, 0, 100, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = Roll.get()
          pivot = [0, 0]
        }
      }
    }
  ]
}

let ClimbSpeedDir = Computed(@() ClimbSpeed.get() >= 0.0 ? 1 : -1)
let ClimbSpeedVal = Computed(@() (ClimbSpeed.get() * 10.0).tointeger())
let climbSpeed = @(){
  size = static [pw(10), ph(4)]
  pos = [pw(78), ph(46)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
  halign = ALIGN_RIGHT
  valign = ALIGN_CENTER
  commands = [
    [VECTOR_RECTANGLE, 0, 0, 100, 100]
  ]
  children = [
    @(){
      watch = ClimbSpeedDir
      size = flex()
      pos = [0, ClimbSpeedDir.get() > 0 ? 0 : ph(100)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = [
        [VECTOR_LINE, 20, ClimbSpeedDir.get() * -20, 80, ClimbSpeedDir.get() * -20],
        [VECTOR_LINE, 20, ClimbSpeedDir.get() * -20, 50, ClimbSpeedDir.get() * -60],
        [VECTOR_LINE, 80, ClimbSpeedDir.get() * -20, 50, ClimbSpeedDir.get() * -60]
      ]
    }
    @(){
      watch = ClimbSpeedVal
      size = SIZE_TO_CONTENT
      pos = [0, ph(10)]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      font = Fonts.ils31
      text = string.format("%.1f", ClimbSpeed.get())
    }
  ]
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
        color = IlsColor.get()
        fontSize = 35
        font = Fonts.ils31
        padding = static [0, 10]
        text = num.tostring()
      } : null),
      {
        size = [pw(num % 10 == 0 ? 40 : 20), flex()]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = [
          (num != 0 ? [VECTOR_LINE, 0, 30, 0, num > 0 ? 50 : 10] : []),
          (num > 0 ? [VECTOR_LINE_DASHED, 0, 30, 100, 30, 10, 15] : [VECTOR_LINE, 0, 30, 100, 30])
        ]
      }
    ]
  }
}

function pitch(height) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generatePitchLine(num))
  }

  return {
    size = flex()
    pos = [0, height * 0.2]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (91.5 - Tangage.get()) * 0.008]
      }
    }
  }
}

function pitchWrap(width, height) {
  return {
    size = [width * 0.15, height * 0.4]
    pos = [width * 0.08, height * 0.3]
    clipChildren = true
    children = pitch(height)
  }
}

let SpeedVal = Computed(@() round(Speed.get() * mpsToKmh).tointeger())
let speed = @() {
  watch = SpeedVal
  pos = [pw(20), ph(17)]
  size = flex()
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  font = Fonts.ils31
  fontSize = 50
  text = SpeedVal.get().tostring()
}

let AltitudeVal = Computed(@() Altitude.get().tointeger() )
let altitude = {
  size = static [pw(10), ph(4)]
  pos = [pw(70), ph(17)]
  flow = FLOW_HORIZONTAL
  halign = ALIGN_RIGHT
  children = [
    @(){
      watch = AltitudeVal
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      font = Fonts.ils31
      fontSize = 50
      text = AltitudeVal.get().tostring()
      padding = static [0, 3]
    }
    @(){
      rendObj = ROBJ_VECTOR_CANVAS
      size = ph(30)
      pos = [0, ph(70)]
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.7
      commands = [
        [VECTOR_LINE, 0, 0, 100, 0],
        [VECTOR_LINE, 0, 0, 0, 100]
      ]
    }
  ]
}

let generateCompassMark = function(num, _elemWidth, _font) {
  local textVal = num % 30 == 0 ? (num / 10).tostring() : ""
  if (num == 180)
    textVal = "S"
  if (num == 0)
    textVal = "N"
  if (num == 90)
    textVal = "E"
  if (num == 270)
    textVal = "W"
  return {
    size = static [pw(5), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * IlsLineScale.get() * 0.5, baseLineWidth * (num % 10 == 0 ? 4 : 2)]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        hplace = ALIGN_CENTER
      }
      @() {
        watch = IlsColor
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        hplace = ALIGN_CENTER
        fontSize = 30
        font = Fonts.hud
        text = textVal
      }
    ]
  }
}


let CompassVal = Computed(@() ((CompassValue.get() + 360.0) % 360.0).tointeger())
let compass = function(width, height) {
  return @() {
    size = flex()
    children = [
      compassWrap(width, height, 0.11, generateCompassMark, 1.0, 5.0, false, 5)
      @() {
        watch = IlsColor
        size = static [pw(1), ph(2)]
        pos = [pw(50), ph(8.5)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = [
          [VECTOR_LINE, 0, 100, -100, 0],
          [VECTOR_LINE, 0, 100, 100, 0],
          [VECTOR_LINE, 100, 0, -100, 0]
        ]
      }
      {
        size = [pw(60), baseLineWidth * IlsLineScale.get() * 0.5]
        pos = [pw(20), ph(10.8)]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
      }
      @(){
        size = static [pw(10), ph(4)]
        pos = [pw(45), ph(3.8)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        commands = [
          [VECTOR_RECTANGLE, 0, 0, 100, 100]
        ]
        children = [@(){
          watch = CompassVal
          size = SIZE_TO_CONTENT
          pos = [0, ph(10)]
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          fontSize = 40
          font = Fonts.ils31
          text = CompassVal.get().tostring()
        }]
      }
    ]
  }
}

let GunMode = Computed(@() !RocketMode.get() && !BombCCIPMode.get() && !AtgmMode.get() && !isAAMMode.get())
let DistValue = Computed(@() string.format("%.1f", (AtgmMode.get() || (GunMode.get() && AimLockValid.get()) ? AimLockDist.get() : DistToTarget.get()) / 1000.0))
let GunHasShell = Computed(@() GunMode.get() && ShellCnt.get() > 0)
let SpiMode = Computed(@() GunMode.get() && AimLockValid.get())
let reticle = @() {
  size = flex()
  watch = [TargetPosValid, AimLockValid, AtgmMode, isAAMMode, GunMode]
  children = !isAAMMode.get() && (AtgmMode.get() || (GunMode.get() && AimLockValid.get()) ? AimLockValid.get() : TargetPosValid.get()) ? [
    @(){
      size = ph(2)
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      fillColor = Color(0, 0, 0, 0)
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100],
        [VECTOR_LINE, 0, 0, 0, 0]
      ]
      children = [
        {
          size = SIZE_TO_CONTENT
          pos = [pw(130), ph(-90)]
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          fontSize = 40
          font = Fonts.ils31
          text = GunHasShell.get() ? "ПР" : ""
          behavior = Behaviors.RtPropUpdate
          update = @(){
            text = GunHasShell.get() && (!SpiMode.get() || AimLockPos[0] > IlsPosSize[2] * 0.35 ) ? "ПР" : ""
          }
        }
        @(){
          watch = DistValue
          size = SIZE_TO_CONTENT
          pos = [pw(-150), ph(-300)]
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          fontSize = 40
          font = Fonts.ils31
          text = GunMode.get() ? DistValue.get().tostring() : ""
        }
      ]
      animations = [
        { prop = AnimProp.opacity, from = 1, to = -1, duration = 0.5, loop = true, easing = InOutSine, trigger = "reticle_limit" }
      ]
      behavior = Behaviors.RtPropUpdate
      update = function() {
        local target = AtgmMode.get() || (GunMode.get() && AimLockValid.get()) ? AimLockPos : [TargetPos.get()[0], TargetPos.get()[1]]
        let leftBorder = IlsPosSize[2] * 0.04
        let rightBorder = IlsPosSize[2] * 0.9
        let topBorder = IlsPosSize[3] * 0.02
        let bottomBorder = IlsPosSize[3] * 0.95
        if (target[0] < leftBorder || target[0] > rightBorder || target[1] < topBorder || target[1] > bottomBorder)
          anim_start("reticle_limit")
        else
          anim_request_stop("reticle_limit")
        target = [clamp(target[0], leftBorder, rightBorder), clamp(target[1], topBorder, bottomBorder)]
        return {
          color = IlsColor.get()
          transform = {
            translate = target
          }
        }
      }
    }
  ] : null
}

let spiLimits = @(){
  watch = SpiMode
  size = flex()
  children = SpiMode.get() ? [
    {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = [
        [VECTOR_LINE, 35, 0, 35, 100]
      ]
    }
  ] : null
}

let shellName = @(){
  watch = [IlsColor, CurWeaponName, GunMode, SpiMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(70), ph(82)]
  color = IlsColor.get()
  fontSize = 35
  font = Fonts.ils31
  text = SpiMode.get() ? "ППУ" : GunMode.get() ? "НПУ" :
   (CurWeaponName.get() && CurWeaponName.get() != "" ? loc_checked(string.format("%s/ils_28", CurWeaponName.get())) : "")
}

let shellCnt = @() {
  watch = [IlsColor, ShellCnt]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(82)]
  color = IlsColor.get()
  fontSize = 35
  font = Fonts.ils31
  text = ShellCnt.get()
}

let rateOfFire = @() {
  watch = GunMode
  size = flex()
  children = GunMode.get() ? [
    @() {
      watch = [IlsColor, IsHighRateOfFire]
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(78), ph(85)]
      color = IlsColor.get()
      fontSize = 35
      font = Fonts.ils31
      text = IsHighRateOfFire.get() ? "БТ" : "МТ"
    }
  ] : null
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
  pos = [pw(62), ph(85)]
  color = IlsColor.get()
  fontSize = 35
  font = Fonts.ils31
  text = burstLenStr.get()
}

let IsInnerSlot = Computed(@() SelectedWeapSlot.get() == 3 || SelectedWeapSlot.get() == 4)
let selectedStation = @(){
  watch = [RocketMode, AtgmMode, isAAMMode, CurWeaponName, GunMode, SelectedWeapSlot]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(75), ph(85)]
  color = IlsColor.get()
  fontSize = 35
  font = Fonts.ils31
  text = AtgmMode.get() ? loc_checked(string.format("%s/ils_28_st", CurWeaponName.get())) : isAAMMode.get() ? "ППС" : RocketMode.get() || BombCCIPMode.get() ? (IsInnerSlot.get() ? "ВНУТР" : "ВНЕШ") : ""
}

function agmLaunchZone(width, height) {
  return @() {
    watch = [AtgmMode, IsAgmLaunchZoneVisible]
    size = flex()
    children = AtgmMode.get() && IsAgmLaunchZoneVisible.get() ? @(){
      watch = [IlsAtgmLaunchEdge1X, IlsAtgmLaunchEdge2X, IlsColor]
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      commands = [
        [VECTOR_LINE, IlsAtgmLaunchEdge1X.get() / width * 100.0, IlsAtgmLaunchEdge1Y.get() / height * 100.0, IlsAtgmLaunchEdge2X.get() / width * 100.0, IlsAtgmLaunchEdge2Y.get() / height * 100.0],
        [VECTOR_LINE, IlsAtgmLaunchEdge2X.get() / width * 100.0, IlsAtgmLaunchEdge2Y.get() / height * 100.0, IlsAtgmLaunchEdge4X.get() / width * 100.0, IlsAtgmLaunchEdge4Y.get() / height * 100.0],
        [VECTOR_LINE, IlsAtgmLaunchEdge3X.get() / width * 100.0, IlsAtgmLaunchEdge3Y.get() / height * 100.0, IlsAtgmLaunchEdge4X.get() / width * 100.0, IlsAtgmLaunchEdge4Y.get() / height * 100.0],
        [VECTOR_LINE, IlsAtgmLaunchEdge3X.get() / width * 100.0, IlsAtgmLaunchEdge3Y.get() / height * 100.0, IlsAtgmLaunchEdge1X.get() / width * 100.0, IlsAtgmLaunchEdge1Y.get() / height * 100.0]
      ]
    } : null
  }
}

let atgmLaunchPermitted = @() {
  watch = [AtgmMode, IsInsideLaunchZoneYawPitch, IsInsideLaunchZoneDist, RocketMode, SpiMode, AimLockValid]
  size = flex()
  children = (AtgmMode.get() && IsInsideLaunchZoneYawPitch.get() && IsInsideLaunchZoneDist.get()) ||
    (AtgmMode.get() && !AimLockValid.get() && ShellCnt.get() > 0) ||
    (RocketMode.get() && !AtgmMode.get() && ShellCnt.get() > 0) ?
    @() {
      watch = IlsColor
      size = flex()
      rendObj = ROBJ_TEXT
      pos = [pw(48), ph(78)]
      color = IlsColor.get()
      fontSize = 45
      font = Fonts.hud
      text = "ПР"
    }
  : null
}

let pilotControl = @() {
  watch = TriggerPulled
  size = flex()
  children = TriggerPulled.get() ? [
    {
      size = ph(2)
      pos= [pw(27), ph(88)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.75
      fillColor = Color(0, 0, 0, 0)
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100],
        [VECTOR_LINE, -70.7, -70.7, 70.7, 70.7],
        [VECTOR_LINE, -70.7, 70.7, 70.7, -70.7]
      ]
    }
  ] : null
}

let distToTarget = @() {
  size = flex()
  watch = [GunMode, isAAMMode, AtgmMode, AimLockValid]
  children = !GunMode.get() && !isAAMMode.get() && (!AtgmMode.get() || AimLockValid.get()) ? [
    @() {
      watch = DistValue
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(47), ph(82)]
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.hud
      text = DistValue.get()
    }
  ] : null
}

let aamReticle = @() {
  watch = [isAAMMode, IlsTrackerVisible]
  size = flex()
  children = isAAMMode.get() && IlsTrackerVisible.get() ? [
    {
      size = ph(5)
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [IlsTrackerX.get(), IlsTrackerY.get()]
        }
      }
    }
  ] : null
}

let aamMode = @() {
  watch = [isAAMMode, RocketMode, BombCCIPMode]
  size = static [pw(100), SIZE_TO_CONTENT]
  pos = [0, ph(78)]
  halign = ALIGN_CENTER
  children = isAAMMode.get() && !RocketMode.get() && !BombCCIPMode.get() ? [
    @() {
      watch = GuidanceLockState
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      font = Fonts.ils31
      fontSize = 45
      text = GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING ? "ПР" :
       GuidanceLockState.get() == GuidanceLockResult.RESULT_LOCKING ? "ГОТОВ" :
       GuidanceLockState.get() <= GuidanceLockResult.RESULT_WARMING_UP ? "НАКОЛИ НИП" : ""
    }
  ] : null
}

let TAMark = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.get() ? [
    @(){
      size = SIZE_TO_CONTENT
      pos = [pw(23), ph(23)]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      font = Fonts.ils31
      fontSize = 40
      text = "ТА ИД"
    }
  ] : null
}

let maneuverDir = Watched(0)
function updManeuverDir() {
  maneuverDir.set(TurretYaw.get() <= 0 ? 1 : TurretYaw.get() >= 1.0 ? -1 : 0)
}
let maneuverOrientation = @() {
  watch = [AimLockValid, maneuverDir]
  size = flex()
  pos= [pw(48), ph(88)]
  function onAttach() {
    updManeuverDir()
    setInterval(1.0, updManeuverDir)
  }
  onDetach = @() clearTimer(updManeuverDir)
  children = AimLockValid.get() && maneuverDir.get() != 0 ? [
    @() {
      watch = maneuverDir
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      size = static [pw(5), ph(5)]
      commands = maneuverDir.get() > 0 ? [
        [VECTOR_LINE, 0, 0, 40, 0],
        [VECTOR_LINE, 0, 0, 20, 20],
        [VECTOR_LINE, 0, 0, 20, -20]
      ] : [
        [VECTOR_LINE, 100, 0, 60, 0],
        [VECTOR_LINE, 100, 0, 80, 20],
        [VECTOR_LINE, 100, 0, 80, -20]
      ]
      children = [
        {
          size = SIZE_TO_CONTENT
          pos = [0, ph(30)]
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          font = Fonts.ils31
          fontSize = 40
          text = "ОМ"
        }
      ]
    }
  ] : null
}

let aimLockPosMark = @() {
  watch = [AimLockValid, AtgmMode, GunMode]
  size = flex()
  children = !AtgmMode.get() && AimLockValid.get() && !GunMode.get() ? [
    @(){
      watch = IlsColor
      size = pw(2)
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, -100, -100, -30, -30],
        [VECTOR_LINE, -100, 100, -30, 30],
        [VECTOR_LINE, 100, 100, 30, 30],
        [VECTOR_LINE, 100, -100, 30, -30]
      ]
      animations = [
        { prop = AnimProp.opacity, from = 1, to = -1, duration = 0.5, loop = true, easing = InOutSine, trigger = "aim_lock_limit" }
      ]
      behavior = Behaviors.RtPropUpdate
      update = function() {
        local target = AimLockPos
        let leftBorder = IlsPosSize[2] * 0.08
        let rightBorder = IlsPosSize[2] * 0.9
        let topBorder = IlsPosSize[3] * 0.04
        let bottomBorder = IlsPosSize[3] * 0.95
        if (target[0] < leftBorder || target[0] > rightBorder || target[1] < topBorder || target[1] > bottomBorder)
          anim_start("aim_lock_limit")
        else
          anim_request_stop("aim_lock_limit")
        target = [clamp(target[0], leftBorder, rightBorder), clamp(target[1], topBorder, bottomBorder)]
        return {
          transform = {
            translate = target
          }
        }
      }
    }
  ] : null
}

function Ils28K(width, height) {
  return {
    size = [width, height]
    children = [
      rollIndicator
      climbSpeed
      pitchWrap(width, height)
      speed
      altitude
      compass(width, height)
      reticle
      shellName
      shellCnt
      rateOfFire
      burstLength
      agmLaunchZone(width, height)
      atgmLaunchPermitted
      distToTarget
      aamReticle
      aamMode
      selectedStation
      pilotControl
      TAMark
      maneuverOrientation
      aimLockPosMark
      spiLimits
    ]
  }
}

return Ils28K