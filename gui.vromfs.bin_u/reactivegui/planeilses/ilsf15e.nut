from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked
let u = require("%sqStdLibs/helpers/u.nut")

let { Speed, Aoa, Tangage, Roll, BarAltitude, ClimbSpeed, CompassValue, Mach, Overload,
 Gear } = require("%rGui/planeState/planeFlyState.nut")
let { IlsColor, IlsLineScale, TargetPos, RadarTargetPos, RadarTargetPosValid, RadarTargetDist,
 RadarTargetAngle, RadarTargetVel, TargetPosValid, IlsPosSize, RadarTargetDistRate, BombCCIPMode,
 TvvMark, CannonMode, DistToTarget, BombingMode, AimLockPos, AimLockValid, TimeBeforeBombRelease,
 RadarTargetHeight, AirCannonMode } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet, degToRad, metrToNavMile, radToDeg } = require("ilsConstants.nut")
let { format } = require("string")
let { cos, sin, PI, abs } = require("%sqstd/math.nut")
let { cvt } = require("dagor.math")
let { RadarModeNameId, modeNames, ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax,
 AamLaunchZoneDistMin, AamLaunchZoneDistMax, DistanceMax,
 AamLaunchZoneDistDgftMax, AamLaunchZoneDistDgftMin, AamLaunchZoneDist } = require("%rGui/radarState.nut")

let { GuidanceLockResult, GuidanceType } = require("guidanceConstants")
let { FwdPoint, AdlPoint, CurWeaponName, CurWeaponGidanceType, ShellCnt,
  BulletImpactPoints1, BulletImpactPoints2, BulletImpactLineEnable } = require("%rGui/planeState/planeWeaponState.nut")
let { AamTimeToHit } = require("%rGui/airState.nut")
let { IlsTrackerVisible, GuidanceLockState, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")

let isAamAvailable = Computed(@() GuidanceLockState.value >= GuidanceLockResult.RESULT_STANDBY)
let isAamReady = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)



let SpeedValue = Computed(@() (Speed.get() * mpsToKnots).tointeger())
let speed = @(){
  watch = IlsColor
  rendObj = ROBJ_FRAME
  pos = [pw(10), ph(30)]
  size = const [pw(10), ph(5)]
  color = IlsColor.get()
  borderWidth = baseLineWidth * IlsLineScale.get() * 0.5
  children = @(){
    watch = SpeedValue
    size = flex()
    rendObj = ROBJ_TEXT
    color = IlsColor.get()
    fontSize = 45
    padding = const [0, 2]
    text = SpeedValue.get().tostring()
    halign = ALIGN_RIGHT
    valign = ALIGN_CENTER
  }
}

let AoaValue = Computed(@() (Aoa.get() * 10.0).tointeger())
let aoa = @(){
  watch = IlsColor
  size = const [pw(10), ph(5)]
  pos = [pw(10), ph(35)]
  color = IlsColor.get()
  flow = FLOW_HORIZONTAL
  halign = ALIGN_RIGHT
  children = [
    @(){
      size = FLEX_V
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = "A"
      valign = ALIGN_CENTER
    }
    @(){
      watch = AoaValue
      size = FLEX_V
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = format("% 3.1f", AoaValue.get() * 0.1)
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
    }
  ]
}


































let MachValue = Computed(@() (Mach.get() * 1000).tointeger())
let OverloadValue = Computed(@() (Overload.get() * 10).tointeger())
let machAndOverload = @() {
  watch = Gear
  size = flex()
  children = Gear.get() < 0.5 ? [
    @(){
      watch = [IlsColor, MachValue]
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [Mach.get() < 1.0 ? pw(11) : pw(9), ph(62)]
      color = IlsColor.get()
      fontSize = 35
      text = MachValue.get() >= 1000.0 ? format("%.3f", Mach.get()) : format(".%03d", MachValue.get())
    },
    @(){
      watch = [IlsColor, OverloadValue]
      size = SIZE_TO_CONTENT
      pos = [pw(5), ph(65)]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = format("%.1f 9.0G", OverloadValue.get() * 0.1)
    }
  ] : null
}

let BarAltValue = Computed(@() (BarAltitude.get() * metrToFeet).tointeger())
let baroAlt = @(){
  watch = IlsColor
  rendObj = ROBJ_FRAME
  pos = [pw(80), ph(30)]
  size = const [pw(12), ph(5)]
  color = IlsColor.get()
  borderWidth = baseLineWidth * IlsLineScale.get() * 0.5
  flow = FLOW_HORIZONTAL
  halign = ALIGN_RIGHT
  children = [
    @(){
      watch = BarAltValue
      size = FLEX_V
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 45
      text = (BarAltValue.get() / 1000).tostring()
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
    }
    @(){
      watch = BarAltValue
      size = FLEX_V
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      padding = const [0, 2]
      text = format("%03d", BarAltValue.get() % 1000)
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
    }
  ]
}

let ClimbRateValue = Computed(@() (ClimbSpeed.get() * metrToFeet * 60.0).tointeger())
let climbRate = @(){
  watch = [IlsColor, Gear]
  pos = [pw(80), ph(35)]
  size = const [pw(12), ph(5)]
  color = IlsColor.get()
  flow = FLOW_HORIZONTAL
  halign = ALIGN_RIGHT
  children = Gear.get() > 0.5 ? [
    {
      size = FLEX_V
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = "VV "
      valign = ALIGN_CENTER
    }
    @(){
      watch = ClimbRateValue
      size = FLEX_V
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      padding = const [0, 2]
      text = format("% 5d", ClimbRateValue.get())
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
    }
  ] : null
}














































let fwdMarker = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(2), ph(2)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
  commands = [
    [VECTOR_LINE, -120, 0, -80, 0, -40, 40, 0, 0, 40, 40, 80, 0, 120, 0]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [FwdPoint[0], FwdPoint[1]]
    }
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

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let angle = max(abs(num), 0) * degToRad
  return {
    size = const [pw(50), ph(50)]
    pos = [pw(25), 0]
    children = [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        color = IlsColor.value
        commands = [
          (num == 0 ? [VECTOR_LINE, -10, 0, 40, 0] : []),
          (num == 0 ? [VECTOR_LINE, 60, 0, 110, 0] : []),
          (num == 0 ? [VECTOR_LINE, 110, 0, 110, 5] : []),
          (num == 0 ? [VECTOR_LINE, -10, 0, -10, 5] : []),
          (num > 0 ? [VECTOR_LINE, 12, 0, 40, 40 * sin(angle)] : []),
          (num > 0 ? [VECTOR_LINE, 60, 40 * sin(angle), 88, 0] : []),
          (num != 0 ? [VECTOR_LINE, 88, 0, 88, 5 * sign] : []),
          (num != 0 ? [VECTOR_LINE, 12, 0, 12, 5 * sign] : []),
          (num < 0 ? [VECTOR_LINE_DASHED, 12, 0, 40, -28 * sin(angle), 10, 10] : []),
          (num < 0 ? [VECTOR_LINE_DASHED, 64, -28 * sin(angle), 88, 0, 10, 10] : [])
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
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 40, 40],
          [VECTOR_LINE, -100, 0, -40, 0],
          [VECTOR_LINE, 100, 0, 40, 0],
          [VECTOR_LINE, 0, -80, 0, -40]
        ],
        animations = [
          { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.25, loop = true, trigger = "aoa_limit" }
        ]
      }
      pitchWrap(width, height)
    ]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      let aoaLim = 0.35 * width
      if (abs(TvvMark[0] - 0.5 * width) > aoaLim || abs(TvvMark[1] - 0.5 * height) > aoaLim)
        anim_start("aoa_limit")
      else
        anim_request_stop("aoa_limit")
      let tvvMarkLim = [0.5 * width + clamp(TvvMark[0] - 0.5 * width, -aoaLim, aoaLim),
                        0.5 * height + clamp(TvvMark[1] - 0.5 * height, -aoaLim, aoaLim)]
      return {
        transform = {
          translate = tvvMarkLim
        }
      }
    }
  }
}

let rollIndicator = @(){
  watch = IlsColor
  pos = [pw(50), ph(60)]
  size = const [pw(35), ph(35)]
  children = [
    {
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = [
        [VECTOR_LINE, 0, 90, 0, 95],
        [VECTOR_LINE, 90 * sin(10 * degToRad), 90 * cos(10 * degToRad), 95 * sin(10 * degToRad), 95 * cos(10 * degToRad)],
        [VECTOR_LINE, 90 * sin(20 * degToRad), 90 * cos(20 * degToRad), 95 * sin(20 * degToRad), 95 * cos(20 * degToRad)],
        [VECTOR_LINE, 90 * sin(30 * degToRad), 90 * cos(30 * degToRad), 100 * sin(30 * degToRad), 100 * cos(30 * degToRad)],
        [VECTOR_LINE, 90 * sin(60 * degToRad), 90 * cos(60 * degToRad), 100 * sin(60 * degToRad), 100 * cos(60 * degToRad)],
        [VECTOR_LINE, 90 * sin(-10 * degToRad), 90 * cos(-10 * degToRad), 95 * sin(-10 * degToRad), 95 * cos(-10 * degToRad)],
        [VECTOR_LINE, 90 * sin(-20 * degToRad), 90 * cos(-20 * degToRad), 95 * sin(-20 * degToRad), 95 * cos(-20 * degToRad)],
        [VECTOR_LINE, 90 * sin(-30 * degToRad), 90 * cos(-30 * degToRad), 100 * sin(-30 * degToRad), 100 * cos(-30 * degToRad)],
        [VECTOR_LINE, 90 * sin(-60 * degToRad), 90 * cos(-60 * degToRad), 100 * sin(-60 * degToRad), 100 * cos(-60 * degToRad)]
      ]
    },
    {
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = IlsColor.get()
      lineWidth = baseLineWidth * 2 * IlsLineScale.get() * 0.5
      commands = [
        [VECTOR_LINE, 90 * sin(45 * degToRad), 90 * cos(45 * degToRad), 95 * sin(45 * degToRad), 95 * cos(45 * degToRad)],
        [VECTOR_LINE, 90 * sin(-45 * degToRad), 90 * cos(-45 * degToRad), 95 * sin(-45 * degToRad), 95 * cos(-45 * degToRad)]
      ]
    },
    {
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      fillColor = Color(0, 0, 0, 0)
      commands = [
        [VECTOR_POLY, 0, 88, -3, 80, 3, 80]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = -Roll.get()
          pivot = [0.0, 0.0]
        }
      }
    }
  ]
}



let generateCompassMark = function(num, width) {
  return {
    size = [width * 0.15, ph(100)]
    flow = FLOW_VERTICAL
    children = [
      {
        size = SIZE_TO_CONTENT
        pos = [0, baseLineWidth * 3]
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        hplace = ALIGN_CENTER
        fontSize = 30
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      {
        size = [baseLineWidth * IlsLineScale.get() * 0.5, baseLineWidth * 2]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        hplace = ALIGN_CENTER
      }
    ]
  }
}

function compass(width, generateFunc) {
  let children = []
  let step = 2.0

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    let num = (i * step) % 360

    children.append(generateFunc(num, width))
  }

  let getOffset = @() (360.0 + CompassValue.get()) * 0.075 * width
  return {
    size = flex()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [-getOffset() + 1.25 * width, 0]
      }
    }
    flow = FLOW_HORIZONTAL
    children = children
  }
}

function compassWrap(width, height, generateFunc) {
  return {
    
    size = [width * 0.5, height * 0.1]
    pos = [width * 0.25, height * 0.1]
    clipChildren = true
    children =  [
      compass(width * 0.2, generateFunc)
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = [
          [VECTOR_LINE, 0, 40, 100, 40],
          [VECTOR_LINE, 50, 40, 49, 60],
          [VECTOR_LINE, 50, 40, 51, 60]
        ]
      }
    ]
  }
}



let haveRadatTarget = Computed(@() RadarTargetDist.get() > 0)
let radarTargetDistValue = Computed(@() (RadarTargetDist.get() * metrToNavMile * 10.0).tointeger())
let targetAltValue = Computed(@() (RadarTargetHeight.get() * metrToFeet * 0.01).tointeger())
let radarTargetParams = @(){
  watch = [haveRadatTarget]
  size = flex()
  children = haveRadatTarget.get() ? [
    @(){
      watch = targetAltValue
      pos = [pw(80), ph(56)]
      size = flex()
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = format("% 2d-%d", targetAltValue.get() * 0.1, targetAltValue.get() % 10)
    }
    @(){
      watch = RadarTargetAngle
      pos = [pw(90), ph(56)]
      size = flex()
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = format("% 2.0f%s", abs(RadarTargetAngle.get() * radToDeg * 0.1), RadarTargetAngle.get() > 0.0 ? "L" : "R")
    }
    @(){
      watch = radarTargetDistValue
      pos = [pw(80), ph(62)]
      size = flex()
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = format("R %.1f", radarTargetDistValue.get() * 0.1)
    }
    @(){
      watch = AamTimeToHit
      pos = [pw(80), ph(65)]
      size = flex()
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = AamTimeToHit.get() > 0.0 ? format("T% 2.0f SEC", AamTimeToHit.get()) : ""
    }
   ] : null
}

let angleToAcmReticlePos = 50.0 / (10.0 * degToRad)
let IsRadarAcmMode = Computed(@() RadarModeNameId.value >= 0 && (modeNames[RadarModeNameId.value] == "hud/PD ACM"))
let radarAcmReticle = @(){
  watch = IsRadarAcmMode
  size = flex()
  children = IsRadarAcmMode.get() ? @(){
    watch = [ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax]
    rendObj = ROBJ_VECTOR_CANVAS
    size = const [pw(50), ph(50)]
    pos = [pw(50), ph(50)]
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
    fillColor = Color(0, 0, 0, 0)
    commands = (ScanElevationMax.get() - ScanElevationMin.get()) > 2 * (ScanAzimuthMax.get() - ScanAzimuthMin.get()) ?
      [
        [VECTOR_LINE,
          0, -ScanElevationMin.get() * angleToAcmReticlePos,
          0, -ScanElevationMax.get() * angleToAcmReticlePos]
      ] :
      [
        [VECTOR_ELLIPSE, 0, 0,
          (ScanAzimuthMax.get()   - ScanAzimuthMin.get()  ) * angleToAcmReticlePos,
          (ScanElevationMax.get() - ScanElevationMin.get()) * angleToAcmReticlePos ]
      ]
  } : null
}

let radarReticleCmd = [ [VECTOR_RECTANGLE, -50, -50, 100, 100] ]
let radarReticleMissileReadyCmd = u.copy(radarReticleCmd)
radarReticleMissileReadyCmd.append([VECTOR_POLY, 0, 50, -25, 100, 25, 100])
let radarReticleActiveRadarMissileReadyCmd = u.copy(radarReticleMissileReadyCmd)
radarReticleActiveRadarMissileReadyCmd.append([VECTOR_POLY, 0, 120, -25, 70, 25, 70])

let AamIsInRange = Computed(@() AamLaunchZoneDist.get() < AamLaunchZoneDistMax.get())
function radarReticle(width, height) {
  return @() {
    watch = RadarTargetPosValid
    size = flex()
    children = RadarTargetPosValid.get() ?
    [
      @() {
        watch = [IlsColor, isAamAvailable, CurWeaponGidanceType, AamIsInRange]
        size = const [pw(7), ph(7)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = isAamAvailable.get() && CurWeaponGidanceType.get() != GuidanceType.TYPE_INVALID && AamIsInRange.get() ?
          (CurWeaponGidanceType.get() == GuidanceType.TYPE_ARH ? radarReticleActiveRadarMissileReadyCmd : radarReticleMissileReadyCmd) :
          radarReticleCmd
        animations = [
          { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, loop = true, trigger = "radar_target_out_of_limit" }
        ],
        behavior = Behaviors.RtPropUpdate
        update = function() {
          let reticleLim = [0.4 * width, 0.4 * height]
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
      }
    ] : null
  }
}





let adlMarker = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(2), ph(2)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
  commands = [
    [VECTOR_LINE, -100, 0, 100, 0],
    [VECTOR_LINE, 0, -100, 0, 100]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [AdlPoint[0], AdlPoint[1]]
    }
  }
}

function getBulletImpactLineCommand() {
  let commands = []
  for (local i = 0; i < BulletImpactPoints1.get().len() - 2; ++i) {
    let point1 = BulletImpactPoints1.get()[i]
    let point2 = BulletImpactPoints1.get()[i + 1]
    if (point1.x == -1 && point1.y == -1)
      continue
    if (point2.x == -1 && point2.y == -1)
      continue
    commands.append([VECTOR_LINE_DASHED, point1.x, point1.y, point2.x, point2.y, 10, 10])
  }
  for (local i = 0; i < BulletImpactPoints2.get().len() - 2; ++i) {
    let point1 = BulletImpactPoints2.get()[i]
    let point2 = BulletImpactPoints2.get()[i + 1]
    if (point1.x == -1 && point1.y == -1)
      continue
    if (point2.x == -1 && point2.y == -1)
      continue
    commands.append([VECTOR_LINE_DASHED, point1.x, point1.y, point2.x, point2.y, 10, 10])
  }
  return commands
}

let bulletsImpactLine = @() {
  watch = BulletImpactLineEnable
  size = flex()
  children = BulletImpactLineEnable.get() ? @() {
    watch = [BulletImpactPoints1, BulletImpactPoints2, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
    commands = getBulletImpactLineCommand()
  } : null
}

let bulletsImpactLines = @(){
  watch = [AirCannonMode, RadarTargetDist]
  size = flex()
  children = AirCannonMode.get() && RadarTargetDist.get() < 0.0 ? [
    bulletsImpactLine
    @(){
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, 0, 0, 0, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = TargetPos.get()
        }
      }
    }
  ] : null
}

let gunReticleCommands = [
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
  [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get() * 1.5],
  [VECTOR_LINE, 0, 0, 0, 0]
]

let ShowGunReticle = Computed(@() CannonMode.get() ? TargetPosValid.get() : RadarTargetDist.get() >= 0.0 && TargetPosValid.get() && (!isAamReady.get() || AirCannonMode.get()))
let HasGunTarget = Computed(@() RadarTargetDist.get() >= 0.0 || (CannonMode.get() && TargetPosValid.get()))
let GunTargetDistSector = Computed(@() cvt((CannonMode.get() ? DistToTarget.get() : RadarTargetDist.get()), 0.0, 3657.6, -90.0, 269.0).tointeger())
let gunReticle = @() {
  watch = ShowGunReticle
  size = ph(8)
  children = ShowGunReticle.get() ? [
    @(){
      watch = HasGunTarget
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = gunReticleCommands
      children = HasGunTarget.get() ? @(){
        watch = GunTargetDistSector
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = [
          [VECTOR_SECTOR, 0, 0, 80, 80, -90, GunTargetDistSector.get()],
          [VECTOR_LINE, 80 * cos(PI * GunTargetDistSector.get() / 180.), 80 * sin(PI * GunTargetDistSector.get() / 180.),
           70 * cos(PI * GunTargetDistSector.get() / 180.), 70 * sin(PI * GunTargetDistSector.get() / 180.)]
        ]
      } : null
    }
  ] : null
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = BombingMode.get() ? TvvMark : [TargetPos.get()[0], TargetPos.get()[1]]
    }
  }
}

let gunMode = @(){
  watch = [AirCannonMode, CannonMode, RadarTargetDist]
  size = flex()
  children = !CannonMode.get() && (RadarTargetDist.get() >= 0.0 || AirCannonMode.get()) ?
    @(){
      watch = [IlsColor, RadarTargetDist]
      pos = [pw(90), ph(59)]
      size = flex()
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = RadarTargetDist.get() >= 0.0 ? "GDS" : "FNL"
    } : null
}



let selectedSecondaryWeapon = @(){
  watch = [CurWeaponName, CurWeaponGidanceType]
  size = flex()
  children = CurWeaponName.get() && CurWeaponName.get() != "" && CurWeaponGidanceType.get() > GuidanceType.TYPE_INVALID ?
    @(){
      watch = [IlsColor, CurWeaponName, ShellCnt]
      pos = [pw(5), ph(59)]
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      font = Fonts.hud
      fontSize = 35
      text = CurWeaponName.get() && CurWeaponName.get() != "" ?
        format("%s%d%s", loc_checked($"{CurWeaponName.get()}/f_15e/1"), ShellCnt.get(), loc_checked($"{CurWeaponName.get()}/f_15e/2")) : format("%d", ShellCnt.get())
    } : null
}



let AseRadius = Computed(@() CurWeaponGidanceType.get() == GuidanceType.TYPE_ARH || CurWeaponGidanceType.get() == GuidanceType.TYPE_SARH ? 100 : 60)
let RadarTargetVelLen = Computed(@() 5 + (RadarTargetVel.get() * 0.001 * 20.0).tointeger())
let aamReticle = @(){
  watch = [isAamAvailable, CurWeaponGidanceType, RadarTargetDist, RadarTargetAngle]
  size = flex()
  children = isAamAvailable.get() && CurWeaponGidanceType.get() != GuidanceType.TYPE_INVALID ? @(){
    watch = [IlsColor, CurWeaponGidanceType, RadarTargetDist]
    rendObj = ROBJ_VECTOR_CANVAS
    size = const [pw(40), ph(40)]
    pos = [pw(50), ph(50)]
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
    fillColor = Color(0, 0, 0, 0)
    commands = CurWeaponGidanceType.get() == GuidanceType.TYPE_ARH ?
      [
        [VECTOR_SECTOR, 0, 0, 100, 100, 0, 9],
        [VECTOR_SECTOR, 0, 0, 100, 100, 18, 27],
        [VECTOR_SECTOR, 0, 0, 100, 100, 36, 45],
        [VECTOR_SECTOR, 0, 0, 100, 100, 54, 63],
        [VECTOR_SECTOR, 0, 0, 100, 100, 72, 81],
        [VECTOR_SECTOR, 0, 0, 100, 100, 90, 99],
        [VECTOR_SECTOR, 0, 0, 100, 100, 108, 117],
        [VECTOR_SECTOR, 0, 0, 100, 100, 126, 135],
        [VECTOR_SECTOR, 0, 0, 100, 100, 144, 153],
        [VECTOR_SECTOR, 0, 0, 100, 100, 162, 171],
        [VECTOR_SECTOR, 0, 0, 100, 100, 180, 189],
        [VECTOR_SECTOR, 0, 0, 100, 100, 198, 207],
        [VECTOR_SECTOR, 0, 0, 100, 100, 216, 225],
        [VECTOR_SECTOR, 0, 0, 100, 100, 234, 243],
        [VECTOR_SECTOR, 0, 0, 100, 100, 252, 261],
        [VECTOR_SECTOR, 0, 0, 100, 100, 270, 279],
        [VECTOR_SECTOR, 0, 0, 100, 100, 288, 297],
        [VECTOR_SECTOR, 0, 0, 100, 100, 306, 315],
        [VECTOR_SECTOR, 0, 0, 100, 100, 324, 333],
        [VECTOR_SECTOR, 0, 0, 100, 100, 342, 351]
      ] :
      (CurWeaponGidanceType.get() == GuidanceType.TYPE_SARH ?
        [
          [VECTOR_ELLIPSE, 0, 0, 100, 100]
        ] :
        [
          [VECTOR_ELLIPSE, 0, 0, 60, 60]
        ])
    children = RadarTargetDist.get() >= 0.0 ? @(){
      watch = [IlsColor, AseRadius, RadarTargetVelLen]
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = [
        [VECTOR_LINE, 0, AseRadius.get(), 0, AseRadius.get() + RadarTargetVelLen.get()]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = 180 - RadarTargetAngle.get() * radToDeg
          pivot = [0, 0]
        }
      }
    } : null
  } : null
}

let seekerReticle = @() {
  watch = [IlsTrackerVisible, GuidanceLockState]
  size = flex()
  children = IlsTrackerVisible.get() && GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ?
    @() {
      watch = IlsColor
      size = const [pw(7), ph(7)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 50, 50]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [IlsTrackerX.get(), IlsTrackerY.get()]
        }
      }
    } : null
}

let MaxDistLaunch = Computed(@() (DistanceMax.get() * 1000.0 * metrToNavMile).tointeger())
let IsLaunchZoneVisible = Computed(@() isAamAvailable.get() && CurWeaponGidanceType.get() != GuidanceType.TYPE_INVALID && AamLaunchZoneDistMax.get() > 0.0)
let MaxLaunchPos = Computed(@() ((1.0 - min(AamLaunchZoneDistMax.get(), 1.0)) * 100.0).tointeger())
let MinLaunchPos = Computed(@() ((1.0 - min(AamLaunchZoneDistMin.get(), 1.0)) * 100.0).tointeger())
let IsDgftLaunchZoneVisible = Computed(@() min(AamLaunchZoneDistDgftMax.get(), 1.0) > 0.0)
let MaxLaunchDgftPos = Computed(@() ((1.0 - min(AamLaunchZoneDistDgftMax.get(), 1.0)) * 100.0).tointeger())
let MinLaunchDgftPos = Computed(@() ((1.0 - min(AamLaunchZoneDistDgftMin.get(), 1.0)) * 100.0).tointeger())
let RadarClosureSpeed = Computed(@() (RadarTargetDistRate.get() * mpsToKnots * -1.0).tointeger())
let launchZone = @(){
  watch = RadarTargetPosValid
  size = const [pw(8), ph(30)]
  pos = [pw(74), ph(30)]
  children = RadarTargetPosValid.get() ? [
    @(){
      watch = AamLaunchZoneDist
      size = flex()
      pos = [pw(-100), ph((1.0 - min(AamLaunchZoneDist.get(), 1.0)) * 100.0)]
      flow = FLOW_HORIZONTAL
      halign = ALIGN_RIGHT
      children = [
        @(){
          watch = RadarClosureSpeed
          rendObj = ROBJ_TEXT
          size = SIZE_TO_CONTENT
          color = IlsColor.get()
          fontSize = 35
          text = RadarClosureSpeed.get().tostring()
        },
        {
          rendObj = ROBJ_VECTOR_CANVAS
          size = const [pw(20), ph(5)]
          color = IlsColor.get()
          lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
          commands = [
            [VECTOR_LINE, 0, 0, 100, 50],
            [VECTOR_LINE, 0, 100, 100, 50]
          ]
        }
      ]
    },
    @(){
      size = const [pw(25), flex()]
      flow = FLOW_VERTICAL
      children = [
        @(){
          watch = MaxDistLaunch
          rendObj = ROBJ_TEXT
          size = SIZE_TO_CONTENT
          color = IlsColor.get()
          fontSize = 35
          text = MaxDistLaunch.get().tostring()
        },
        @() {
          watch = IsLaunchZoneVisible
          size = flex()
          children = [
            {
              rendObj = ROBJ_VECTOR_CANVAS
              color = IlsColor.get()
              size = flex()
              lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
              commands = [
                [VECTOR_LINE, 0, 0, 0, 100],
                [VECTOR_LINE, 0, 0, 60, 0],
                [VECTOR_LINE, 0, 100, 60, 100],
                [VECTOR_LINE, 0, 25, 60, 25],
                [VECTOR_LINE, 0, 50, 60, 50]
              ]
            },
            IsLaunchZoneVisible.value ? {
              size = flex()
              children = [
                @(){
                  watch = [MaxLaunchPos, MinLaunchPos]
                  rendObj = ROBJ_VECTOR_CANVAS
                  size = flex()
                  color = IlsColor.get()
                  lineWidth = baseLineWidth * IlsLineScale.get()
                  commands = [
                    [VECTOR_LINE, 0, MaxLaunchPos.get(), 100, MaxLaunchPos.get()]
                  ]
                },
                @(){
                  watch = IsDgftLaunchZoneVisible
                  size = flex()
                  children = IsDgftLaunchZoneVisible.get() ? [
                    @(){
                      watch = [MaxLaunchDgftPos, MinLaunchDgftPos]
                      rendObj = ROBJ_VECTOR_CANVAS
                      size = flex()
                      color = IlsColor.get()
                      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
                      commands = [
                        [VECTOR_LINE, 0, MaxLaunchDgftPos.get(), 100, MaxLaunchDgftPos.get()],
                        [VECTOR_LINE, 0, MinLaunchDgftPos.get(), 100, MinLaunchDgftPos.get()],
                        [VECTOR_LINE, 100, MaxLaunchDgftPos.get(), 100, MinLaunchDgftPos.get()]
                      ]
                    }
                  ] : null
                },
                @(){
                  watch = MaxDistLaunch
                  rendObj = ROBJ_TEXT
                  pos = [pw(100), ph(43)]
                  size = SIZE_TO_CONTENT
                  color = IlsColor.get()
                  fontSize = 35
                  text =(MaxDistLaunch.get() / 2).tostring()
                }
              ]
            } : null
          ]
        }
      ]
    }
  ] : null
}



let lowerSolutionCue = @(){
  watch = IlsColor
  size = [pw(10), baseLineWidth * IlsLineScale.get() * 0.5]
  rendObj = ROBJ_SOLID
  color = IlsColor.get()
  behavior = Behaviors.RtPropUpdate
  update = function() {
    let cuePos = TimeBeforeBombRelease.get() <= 0.0 ? 0.4 : cvt(TimeBeforeBombRelease.get(), 0.0, 10.0, 0, 0.4)
    return {
      transform = {
        translate = [IlsPosSize[2] * - 0.05, TvvMark[1] - cuePos * IlsPosSize[3]]
      }
    }
  }
}

function rotatedBombReleaseReticle() {
  return {
    size = flex()
    children = [
      lowerSolutionCue,
      {
        size = flex()
        children = [
          @() {
            watch = IlsColor
            size = [baseLineWidth * IlsLineScale.get() * 0.5, flex()]
            rendObj = ROBJ_SOLID
            color = IlsColor.get()
          }
        ]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [AimLockPos[0], 0]
        rotate = -Roll.get()
        pivot = [0, AimLockPos[1] / IlsPosSize[3]]
      }
    }
  }
}

let timeRelease = Computed(@() TimeBeforeBombRelease.get().tointeger())
let isCcrpValid = Computed(@() BombingMode.get() && TimeBeforeBombRelease.get() > 0.0)
let ccrp = @(){
  watch = isCcrpValid
  size = flex()
  children = isCcrpValid.get() ? [
    @(){
      watch = timeRelease, AamTimeToHit
      pos = [pw(80), ph(65)]
      size = flex()
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = AamTimeToHit.get() <= 0.0 ? format("%02d:%02d TREL", timeRelease.get() / 60, timeRelease.get() % 60) : ""
    }
    @(){
      watch = IlsColor
      pos = [pw(80), ph(59)]
      size = flex()
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = "TGT"
    }
    rotatedBombReleaseReticle()
   ] : null
}

let spi = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.get() ? @(){
    watch = IlsColor
    size = const [pw(2.5), ph(2.5)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
    commands = [
      [VECTOR_LINE, -100, -50, -100, -100],
      [VECTOR_LINE, -50, -100, -100, -100],
      [VECTOR_LINE, 100, -50, 100, -100],
      [VECTOR_LINE, 50, -100, 100, -100],
      [VECTOR_LINE, 100, 50, 100, 100],
      [VECTOR_LINE, 50, 100, 100, 100],
      [VECTOR_LINE, -100, 50, -100, 100],
      [VECTOR_LINE, -50, 100, -100, 100],
      [VECTOR_LINE, 0, -30, -30, 0],
      [VECTOR_LINE, 0, -30, 30, 0],
      [VECTOR_LINE, 0, 30, -30, 0],
      [VECTOR_LINE, 0, 30, 30, 0],
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = AimLockPos
      }
    }
  } : null
}

let bombImpactLine = @() {
  watch = [BombCCIPMode, TargetPosValid]
  size = flex()
  children = BombCCIPMode.get() && TargetPosValid.get() ? [
    @(){
      watch = [TargetPos, IlsColor]
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = 0
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = [
        [VECTOR_LINE, TvvMark[0] / IlsPosSize[2] * 100, TvvMark[1] / IlsPosSize[2] * 100,
          TargetPos.get()[0] / IlsPosSize[2] * 100,
          TargetPos.get()[1] / IlsPosSize[2] * 100]
      ]
    },
    @(){
      size = ph(8)
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = gunReticleCommands
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.get()[0], TargetPos.get()[1]]
        }
      }
    }
  ] : null
}

function ilsF15e(width, height) {
  return {
    size = [width, height]
    children = [
      speed
      aoa
      
      machAndOverload
      baroAlt
      climbRate
      

      fwdMarker
      tvvLinked(width, height)
      rollIndicator
      compassWrap(width, height, generateCompassMark)

      radarTargetParams
      radarAcmReticle
      radarReticle(width, height)

      adlMarker
      bulletsImpactLines
      gunReticle
      gunMode

      selectedSecondaryWeapon
      aamReticle
      seekerReticle
      launchZone

      spi
      bombImpactLine
      ccrp
    ]
  }
}

return ilsF15e