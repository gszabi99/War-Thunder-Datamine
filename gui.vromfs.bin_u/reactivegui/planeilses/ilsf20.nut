from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked
let { baseLineWidth, mpsToKnots, metrToFeet, metrToNavMile, degToRad } = require("%rGui/planeIlses/ilsConstants.nut")
let { Tangage, Altitude, Speed, Mach, Overload, Roll, CompassValue, Aoa,
 MaxOverload } = require("%rGui/planeState/planeFlyState.nut")
let { IlsColor, IlsLineScale, IlsPosSize, TvvMark, BombCCIPMode, BombingMode,
 CannonMode, RocketMode, TargetPosValid, RadarTargetDist, DistToTarget, TargetPos,
 RadarTargetDistRate, RadarTargetPos, RadarTargetPosValid, AimLockPos, AimLockValid,
 DistToSafety, TimeBeforeBombRelease, AimLockDist } = require("%rGui/planeState/planeToolsState.nut")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { cvt } = require("dagor.math")
let { cos, sin, PI, floor, abs } = require("%sqstd/math.nut")
let string = require("string")
let { GunBullets0, GunBullets1, ShellCnt, CurWeaponName } = require("%rGui/planeState/planeWeaponState.nut")
let { AamLaunchZoneDistMinVal, AamLaunchZoneDistMaxVal } = require("%rGui/radarState.nut")
let { cancelBombing, bombFallingLine } = require("%rGui/planeIlses/commonElements.nut")

let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)
let isCCIPMode = Computed(@() CannonMode.get() || BombCCIPMode.get() || RocketMode.get())
let hasRadarTarget = Computed(@() RadarTargetDist.get() >= 0.0)

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let angle = abs(num) > 10 ? min(abs(num) - 10, 20) * degToRad : 0
  return {
    size = const [pw(70), ph(50)]
    pos = [pw(15), 0]
    children = [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        commands = [
          (num == 0 ? [VECTOR_LINE, -10, 0, 40, 0] : []),
          (num == 0 ? [VECTOR_LINE, 60, 0, 110, 0] : []),
          (num > 0 ? [VECTOR_LINE, 12, 0, 40, 40 * sin(angle)] : []),
          (num > 0 ? [VECTOR_LINE, 60, 40 * sin(angle), 88, 0] : []),
          (num != 0 ? [VECTOR_LINE, 88, 0, 88, 5 * sign] : []),
          (num != 0 ? [VECTOR_LINE, 12, 0, 12, 5 * sign] : []),
          (num < 0 ? [VECTOR_LINE, 12, 0, 16, -4 * sin(angle)] : []),
          (num < 0 ? [VECTOR_LINE, 20, -8 * sin(angle), 24, -12 * sin(angle)] : []),
          (num < 0 ? [VECTOR_LINE, 28, -16 * sin(angle), 32, -20 * sin(angle)] : []),
          (num < 0 ? [VECTOR_LINE, 36, -24 * sin(angle), 40, -28 * sin(angle)] : []),
          (num < 0 ? [VECTOR_LINE, 88, 0, 84, -4 * sin(angle)] : []),
          (num < 0 ? [VECTOR_LINE, 80, -8 * sin(angle), 76, -12 * sin(angle)] : []),
          (num < 0 ? [VECTOR_LINE, 72, -16 * sin(angle), 68, -20 * sin(angle)] : []),
          (num < 0 ? [VECTOR_LINE, 64, -24 * sin(angle), 60, -28 * sin(angle)] : []),
        ]
      },
      (num != 0 ? @() {
        size = SIZE_TO_CONTENT
        pos = [pw(90), ph(-5)]
        watch = IlsColor
        rendObj = ROBJ_TEXT
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        fontSize = 35
        font = Fonts.hud
        text = num.tostring()
      } : null),
      (num != 0 ? @() {
        size = const [pw(20), SIZE_TO_CONTENT]
        pos = [pw(-10), ph(-5)]
        watch = IlsColor
        rendObj = ROBJ_TEXT
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        fontSize = 35
        font = Fonts.hud
        text = num.tostring()
        halign = ALIGN_RIGHT
      } : null)
    ]
  }
}

function pitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generateFunc(num))
  }
  return {
    size = [width * 0.75, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.get()) * 0.05]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get()) * 0.1]
      }
    }
  }
}

function pitchWrap(width, height) {
  return {
    size = const [pw(50), ph(50)]
    pos = [pw(-37.5), 0]
    children = pitch(width, height, generatePitchLine)
  }
}

function tvvLinked(width, height) {
  return {
    size = flex()
    children = [
      @(){
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = const [pw(4), ph(4)]
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 40, 40],
          [VECTOR_LINE, -100, 0, -40, 0],
          [VECTOR_LINE, 100, 0, 40, 0],
          [VECTOR_LINE, 0, -80, 0, -40]
        ]
      }
      pitchWrap(width, height)
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TvvMark
      }
    }
  }
}

let showGunReticle = Computed(@() !BombingMode.get() && !isAAMMode.get() && !BombCCIPMode.get())
let hasDistSector = Computed(@() RadarTargetDist.get() >= 0.0 || ((CannonMode.get() || RocketMode.get()) && TargetPosValid.get()))
let radarTargetDistSector = Computed(@() cvt((CannonMode.get() || RocketMode.get() ? DistToTarget.get() : RadarTargetDist.get()), 0.0, 3657.6, -90.0, 269.0).tointeger())
let gunReticle = @() {
  watch = showGunReticle
  size = ph(8)
  children = showGunReticle.get() ? [
    @(){
      watch = [hasDistSector]
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 85, 85],
        [VECTOR_LINE, 0, -85, 0, -100],
        [VECTOR_LINE, 42.5, -73.6, 50, -86.6],
        [VECTOR_LINE, 73.6, -42.5, 86.6, -50],
        [VECTOR_LINE, 0, 85, 0, 100],
        [VECTOR_LINE, 42.5, 73.6, 50, 86.6],
        [VECTOR_LINE, 73.6, 42.5, 86.6, 50],
        [VECTOR_LINE, -85, 0, -100, 0],
        [VECTOR_LINE, -42.5, 73.6, -50, 86.6],
        [VECTOR_LINE, -73.6, 42.5, -86.6, 50],
        [VECTOR_LINE, -42.5, -73.6, -50, -86.6],
        [VECTOR_LINE, -73.6, -42.5, -86.6, -50],
        [VECTOR_LINE, 85, 0, 100, 0],
        [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get() * 3.0],
        [VECTOR_LINE, 0, 0, 0, 0]
      ]
      children = hasDistSector.get() ? @(){
        watch = radarTargetDistSector
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_SECTOR, 0, 0, 80, 80, -90, radarTargetDistSector.get()],
          [VECTOR_LINE, 80 * cos(PI * radarTargetDistSector.get() / 180.), 80 * sin(PI * radarTargetDistSector.get() / 180.),
           70 * cos(PI * radarTargetDistSector.get() / 180.), 70 * sin(PI * radarTargetDistSector.get() / 180.)]
        ]
      } : null
    }
  ] : null
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = TargetPos.get()
    }
  }
}

let altValueThousand = Computed(@() (Altitude.get() * metrToFeet / 1000.0).tointeger())
let altValueMod = Computed(@() ((Altitude.get() * metrToFeet % 1000.0)/10.0).tointeger())
let altCompressed = {
  size = const [pw(12), ph(5)]
  pos = [pw(83), ph(30)]
  children = [
    {
      size = flex()
      flow = FLOW_HORIZONTAL
      halign = ALIGN_RIGHT
      padding = const [0, 10]
      children = [
        @(){
          watch = altValueThousand
          size = SIZE_TO_CONTENT
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          padding = const [10, 5]
          font = Fonts.hud
          fontSize = 45
          text = altValueThousand.get().tostring()
        }
        @(){
          watch = altValueMod
          size = SIZE_TO_CONTENT
          pos = [0, 18]
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          font = Fonts.hud
          fontSize = 35
          text = string.format("%03d", altValueMod.get() * 10)
        }
      ]
    }
    @(){
      watch = IlsColor
      rendObj = ROBJ_FRAME
      size = flex()
      color = IlsColor.get()
      borderWidth = baseLineWidth * IlsLineScale.get() * 0.5
    }
  ]
}

let speedKnots = Computed(@() (Speed.get() * mpsToKnots).tointeger())
let speed = @(){
  watch = IlsColor
  size = const [pw(12), ph(5)]
  pos = [0, ph(30)]
  rendObj = ROBJ_FRAME
  color = IlsColor.get()
  borderWidth = baseLineWidth * IlsLineScale.get() * 0.5
  children = @(){
    watch = speedKnots
    size = flex()
    halign = ALIGN_CENTER
    padding= const [10, 0]
    rendObj = ROBJ_TEXT
    color = IlsColor.get()
    fontSize = 45
    font = Fonts.hud
    text = string.format("%03d", speedKnots.get())
  }
}

let aoaVal = Computed(@() (Aoa.get() * 10.0).tointeger())
let aoa = @(){
  watch = aoaVal
  pos = [pw(1), ph(60)]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 35
  text = string.format("A %.1f", aoaVal.get() * 0.1)
}


let machVal = Computed(@() (Mach.get() * 100.0).tointeger())
let mach = @(){
  watch = aoaVal
  pos = [pw(1), ph(64)]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 35
  text = string.format("M %.2f", machVal.get() * 0.01)
}

let gVal = Computed(@() (Overload.get() * 10.0).tointeger())
let g = @(){
  watch = gVal
  pos = [pw(1), ph(68)]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 35
  text = string.format("G %.1f", gVal.get() * 0.1)
}


let distTarget = Computed(@() RadarTargetDist.get() >= 0.0 ? (RadarTargetDist.get() * metrToNavMile * 10.0).tointeger() : -1)
let targetDist = @(){
  watch = distTarget
  pos = [pw(85), ph(63)]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 35
  text = distTarget.get() < 0 ? "" : string.format("RNG %.1f", distTarget.get() * 0.1)
}

let targetRadSpeedVal = Computed(@() hasRadarTarget.get() ? (RadarTargetDistRate.get() * mpsToKnots * -1.0).tointeger() : 0)
let targetRadSpeed = @(){
  watch = [targetRadSpeedVal, hasRadarTarget]
  pos = [pw(85), ph(60)]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 35
  text = hasRadarTarget.get() ? string.format("VC %d", targetRadSpeedVal.get()) : ""
}

let bulletsCount = @(){
  watch = [isAAMMode, RocketMode, BombCCIPMode, BombingMode, CannonMode]
  size = flex()
  children = !isAAMMode.get() && !BombCCIPMode.get() && !BombingMode.get() ? @(){
    watch = [GunBullets0, GunBullets1, CannonMode, RocketMode]
    rendObj = ROBJ_TEXT
    pos = CannonMode.get() || RocketMode.get() ? [pw(78), ph(65)] : [pw(36), ph(80)]
    size = SIZE_TO_CONTENT
    color = IlsColor.get()
    font = Fonts.hud
    fontSize = 35
    text = RocketMode.get() ? "RKT" : string.format(CannonMode.get() ? "%03d GUN %03d" : "%03d   GUN   %03d", GunBullets0.get(), GunBullets1.get())
  } : null
}

let aamCount = @(){
  watch = isAAMMode
  size = flex()
  children = isAAMMode.get() ? @(){
    watch = [ShellCnt, CurWeaponName]
    rendObj = ROBJ_TEXT
    pos = [pw(47), ph(80)]
    size = SIZE_TO_CONTENT
    color = IlsColor.get()
    font = Fonts.hud
    fontSize = 35
    text = string.format("%s%d",
     CurWeaponName.get() && CurWeaponName.get() != "" ? loc_checked(string.format("%s/f_20", CurWeaponName.get())) : "",
     ShellCnt.get())
  } : null
}

let aamMark = @(){
  watch = IlsTrackerVisible
  size = flex()
  children = IlsTrackerVisible.get() ? @(){
    watch = [IlsColor, hasRadarTarget]
    size = const [pw(10), ph(10)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 100, 100]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [IlsTrackerX.get(), IlsTrackerY.get()]
      }
    }
    children = [
      (hasRadarTarget.get() ? @(){
          watch = radarTargetDistSector
          rendObj = ROBJ_VECTOR_CANVAS
          size = flex()
          color = IlsColor.get()
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth
          commands = [
            [VECTOR_SECTOR, 0, 0, 95, 95, -90, radarTargetDistSector.get()],
            [VECTOR_LINE, 95 * cos(PI * radarTargetDistSector.get() / 180.), 95 * sin(PI * radarTargetDistSector.get() / 180.),
            85 * cos(PI * radarTargetDistSector.get() / 180.), 85 * sin(PI * radarTargetDistSector.get() / 180.)]
          ]
        }
      : null),
      (hasRadarTarget.get() ? {
          rendObj = ROBJ_VECTOR_CANVAS
          size = flex()
          color = IlsColor.get()
          fillColor = Color(0, 0, 0, 0)
          commands = [
            [VECTOR_POLY, 0, -100, 10, -115, -10, -115]
          ]
          behavior = Behaviors.RtPropUpdate
          update = @() {
            transform = {
              rotate = cvt(AamLaunchZoneDistMinVal.get(), 0.0, 3657.6, 0.0, 359.0)
              pivot = [0, 0]
            }
          }
        }
      : null),
      (hasRadarTarget.get() ? {
          rendObj = ROBJ_VECTOR_CANVAS
          size = flex()
          color = IlsColor.get()
          fillColor = Color(0, 0, 0, 0)
          commands = [
            [VECTOR_POLY, 0, -100, 10, -115, -10, -115]
          ]
          behavior = Behaviors.RtPropUpdate
          update = @() {
            transform = {
              rotate = cvt(AamLaunchZoneDistMaxVal.get(), 0.0, 3657.6, 0.0, 359.0)
              pivot = [0, 0]
            }
          }
        }
      : null),
      @(){
        watch = GuidanceLockState
        size = const [pw(200), SIZE_TO_CONTENT]
        pos = [pw(-100), ph(120)]
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        halign = ALIGN_CENTER
        font = Fonts.hud
        fontSize = 35
        text = GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING ? "SHOOT" : ""
      }
    ]
  } : null
}

let MaxOverloadWatch = Computed(@() (floor(MaxOverload.get() * 10.0)).tointeger())
let maxOverload = @() {
  watch = [MaxOverloadWatch, IlsColor]
  size = flex()
  pos = [pw(1), ph(72)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 35
  text = string.format("G %.1f", MaxOverloadWatch.get() / 10.0)
  children = {
    rendObj = ROBJ_FRAME
    size = const [35, 40]
    pos = [-5, -5]
    color = IlsColor.get()
    borderWidth = baseLineWidth * IlsLineScale.get() * 0.5
  }
}

function radarMark(width, height) {
  return @() {
    watch = RadarTargetPosValid
    size = flex()
    children = RadarTargetPosValid.get() ? @(){
      watch = IlsColor
      size = const [pw(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_RECTANGLE, -50, -50, 100, 100]
      ]
      animations = [
        { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, loop = true, trigger = "radar_target_out_of_limit" }
      ]
      behavior = Behaviors.RtPropUpdate
      update = function() {
        let reticleLim = [0.47 * width, 0.47 * height]
        if (abs(RadarTargetPos[0] - 0.5 * width) > reticleLim[0] || abs(RadarTargetPos[1] - 0.5 * height) > reticleLim[1])
          anim_start("radar_target_out_of_limit")
        else
          anim_request_stop("radar_target_out_of_limit")
        let RadarTargetPosLim =  [
            0.5 * width + clamp(RadarTargetPos[0] - 0.5 * width, -reticleLim[0], reticleLim[0]),
            0.5 * height + clamp(RadarTargetPos[1] - 0.5 * height, -reticleLim[1], reticleLim[1])
        ]
        return {
          transform = {
            translate = RadarTargetPosLim
          }
        }
      }
    } : null
  }
}

let generateCompassMark = function(num, width) {
  return {
    size = [width * 0.2, ph(100)]
    children = [
      {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        hplace = ALIGN_CENTER
        fontSize = 35
        font = Fonts.hud
        text = num % 10 == 0 ? string.format("%03d", num) : ""
      }
      {
        size = [baseLineWidth * IlsLineScale.get(), baseLineWidth * (num % 10 == 0 ? 3 : 2)]
        pos = [0, baseLineWidth * (num % 10 == 0 ? 6 : 7)]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        hplace = ALIGN_CENTER
      }
    ]
  }
}

function compass(width, generateFunc) {
  let children = []
  let step = 5.0

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    let num = (i * step) % 360

    children.append(generateFunc(num, width))
  }

  let getOffset = @() (360.0 + CompassValue.get()) * 0.04 * width
  return {
    size = flex()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [-getOffset() + 0.4 * width, 0]
      }
    }
    flow = FLOW_HORIZONTAL
    children = children
  }
}

function compassWrap(width, height, generateFunc) {
  return {
    size = [width * 0.5, height * 0.1]
    pos = [width * 0.25, height * 0.05]
    clipChildren = true
    children = [
      compass(width * 0.5, generateFunc)
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_LINE, 50, 60, 48, 80],
          [VECTOR_LINE, 50, 60, 52, 80]
        ]
      }
    ]
  }
}

let ccipMode = @(){
  watch = [isCCIPMode, BombingMode]
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  pos = [pw(78), ph(60)]
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 35
  text = isCCIPMode.get() ? "CCIP" : BombingMode.get() ? "AUTO" : ""
}

let bombImpactLine = @() {
  watch = [BombCCIPMode, TargetPosValid]
  size = flex()
  children = BombCCIPMode.get() && TargetPosValid.get() ? [
    @() {
      watch = [TargetPos, IlsColor]
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, TvvMark[0] / IlsPosSize[2] * 100, TvvMark[1] / IlsPosSize[2] * 100,
          TargetPos.get()[0] / IlsPosSize[2] * 100,
          TargetPos.get()[1] / IlsPosSize[2] * 100]
      ]
    }
    {
      size = const [pw(2), ph(2)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, -100, 0, -40, 0],
        [VECTOR_LINE, 100, 0, 40, 0],
        [VECTOR_LINE, 0, -100, 0, -40],
        [VECTOR_LINE, 0, 100, 0, 40]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.get()[0], TargetPos.get()[1]]
        }
      }
    }
  ] : null
}

let aimLockPos = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.get() ? @(){
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    size = const [pw(2), ph(2)]
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
    commands = [
      [VECTOR_POLY, -100, 0, 0, -100, 100, 0, 0, 100]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = AimLockPos
      }
    }
  } : null
}

let pullupAnticipPos = Computed(@() clamp(0.35 + DistToSafety.get() * 0.001, 0.1, 0.5))
function pullupAnticipation(height) {
  return @() {
    watch = [IlsColor, pullupAnticipPos]
    size = const [pw(10), ph(2)]
    pos = [pw(10), height * pullupAnticipPos.get()]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_LINE, -80, 100, -20, 100],
      [VECTOR_LINE, 80, 100, 20, 100],
      [VECTOR_LINE, -80, 100, -100, 0],
      [VECTOR_LINE, 80, 100, 100, 0]
    ]
  }
}

let lowerCuePos = Computed(@() clamp(0.4 - TimeBeforeBombRelease.get() * 0.02667, 0.0, 0.5))
function lowerSolutionCue(height) {
  return @() {
    watch = [IlsColor, lowerCuePos]
    size = [pw(20), baseLineWidth * IlsLineScale.get()]
    pos = [pw(0), lowerCuePos.get() * height - baseLineWidth * 0.5 * IlsLineScale.get()]
    rendObj = ROBJ_SOLID
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
  }
}

function rotatedBombReleaseReticle(width, height) {
  return {
    size = flex()
    children = [
      pullupAnticipation(height)
      lowerSolutionCue(height)
      {
        size = const [pw(20), flex()]
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        children = bombFallingLine()
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.get()[0] - width * 0.1, height * 0.1]
        rotate = -Roll.get()
        pivot = [0.1, TargetPos.get()[1] / height - 0.1]
      }
    }
  }
}

let secBeforeBombRelease = Computed(@() TimeBeforeBombRelease.get().tointeger())
let timerCCRP = @(){
  watch = secBeforeBombRelease
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  pos = [pw(78), ph(64)]
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 35
  text = string.format("SEC %d", secBeforeBombRelease.get())
}

let aimLockDistMile = Computed(@() (AimLockDist.get() * metrToNavMile * 10.0).tointeger())
let aimLockDist = @(){
  watch = aimLockDistMile
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  pos = [pw(78), ph(68)]
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 35
  text = string.format("TGT %.1f", aimLockDistMile.get() * 0.1)
}

function bombingMode(width, height) {
  return @(){
    watch = BombingMode
    size = [width, height]
    children = BombingMode.get() ? [
      rotatedBombReleaseReticle(width, height)
      cancelBombing(20, 20)
      timerCCRP
      aimLockDist
    ] : null
  }
}

function ilsF20(width, height) {
  return {
    size = [width, height]
    children = [
      tvvLinked(width, height)
      gunReticle
      altCompressed
      speed
      aoa
      mach
      g
      targetDist
      bulletsCount
      aamCount
      aamMark
      targetRadSpeed
      maxOverload
      radarMark(width, height)
      compassWrap(width, height, generateCompassMark)
      ccipMode
      bombImpactLine
      aimLockPos
      bombingMode(width, height)
    ]
  }
}

return ilsF20