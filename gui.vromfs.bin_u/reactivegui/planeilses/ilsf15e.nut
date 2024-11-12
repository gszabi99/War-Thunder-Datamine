from "%rGui/globals/ui_library.nut" import *

let { Speed, Aoa, Tangage, Roll, BarAltitude, CompassValue, Mach, Overload,
 Altitude } = require("%rGui/planeState/planeFlyState.nut")
let { IlsColor, IlsLineScale, TargetPos, RadarTargetPos, RadarTargetPosValid, RadarTargetDist,
 TargetPosValid, IlsPosSize, RadarTargetDistRate, BombCCIPMode, TvvMark, CannonMode,
 RocketMode, DistToTarget, BombingMode, AimLockPos, AimLockValid, TimeBeforeBombRelease,
 RadarTargetHeight, AirCannonMode, RadarTargetAngle } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet, degToRad, metrToNavMile, radToDeg } = require("ilsConstants.nut")
let { format } = require("string")
let { cos, sin, PI, abs, acos } = require("%sqstd/math.nut")
let { cvt } = require("dagor.math")
let { AamLaunchZoneDistMin, AamLaunchZoneDistMax, DistanceMax,
 AamLaunchZoneDistDgftMax, AamLaunchZoneDistDgftMin, AamLaunchZoneDist } = require("%rGui/radarState.nut")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { AdlPoint, BulletImpactPoints1, BulletImpactPoints2, BulletImpactLineEnable } = require("%rGui/planeState/planeWeaponState.nut")

let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let isCCIPMode = Computed(@() BombCCIPMode.value || RocketMode.value || CannonMode.value)
let hasRadarTarget = Computed(@() RadarTargetDist.get() >= 0.0 || (isCCIPMode.get() && TargetPosValid.get()))

let SpeedValue = Computed(@() (Speed.get() * mpsToKnots).tointeger())
let speed = @(){
  watch = IlsColor
  rendObj = ROBJ_FRAME
  pos = [pw(10), ph(30)]
  size = [pw(10), ph(5)]
  color = IlsColor.get()
  borderWidth = baseLineWidth * IlsLineScale.get() * 0.5
  children = @(){
    watch = SpeedValue
    size = flex()
    rendObj = ROBJ_TEXT
    color = IlsColor.get()
    fontSize = 45
    padding = [0, 2]
    text = SpeedValue.get().tostring()
    halign = ALIGN_RIGHT
    valign = ALIGN_CENTER
  }
}

let AoaValue = Computed(@() (Aoa.get() * 10.0).tointeger())
let aoa = @(){
  watch = [AoaValue, IlsColor]
  size = [pw(10), ph(5)]
  pos = [pw(10), ph(35)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 35
  text = format("%.1f", AoaValue.get() * 0.1)
  halign = ALIGN_RIGHT
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let angle = max(abs(num), 0) * degToRad
  return {
    size = [pw(50), ph(50)]
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
        size = [pw(20), SIZE_TO_CONTENT]
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
    size = [pw(50), ph(50)]
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
        size = [pw(4), ph(4)]
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
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

let BarAltValue = Computed(@() (BarAltitude.get() * metrToFeet).tointeger())
let barAlt = @(){
  watch = IlsColor
  rendObj = ROBJ_FRAME
  pos = [pw(80), ph(30)]
  size = [pw(12), ph(5)]
  color = IlsColor.get()
  borderWidth = baseLineWidth * IlsLineScale.get() * 0.5
  flow = FLOW_HORIZONTAL
  halign = ALIGN_RIGHT
  children = [
    @(){
      watch = BarAltValue
      size = [SIZE_TO_CONTENT, flex()]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 45
      text = (BarAltValue.get() / 1000).tostring()
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
    }
    @(){
      watch = BarAltValue
      size = [SIZE_TO_CONTENT, flex()]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      padding = [0, 2]
      text = format("%03d", BarAltValue.get() % 1000)
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
    }
  ]
}

let rollIndicator = @(){
  watch = IlsColor
  pos = [pw(50), ph(60)]
  size = [pw(35), ph(35)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
  commands = [
    [VECTOR_LINE, 0, 90, 0, 95],
    [VECTOR_LINE, 90 * sin(10 * degToRad), 90 * cos(10 * degToRad), 95 * sin(10 * degToRad), 95 * cos(10 * degToRad)],
    [VECTOR_LINE, 90 * sin(20 * degToRad), 90 * cos(20 * degToRad), 95 * sin(20 * degToRad), 95 * cos(20 * degToRad)],
    [VECTOR_LINE, 90 * sin(30 * degToRad), 90 * cos(30 * degToRad), 100 * sin(30 * degToRad), 100 * cos(30 * degToRad)],
    [VECTOR_LINE, 90 * sin(45 * degToRad), 90 * cos(45 * degToRad), 95 * sin(45 * degToRad), 95 * cos(45 * degToRad)],
    [VECTOR_LINE, 90 * sin(60 * degToRad), 90 * cos(60 * degToRad), 100 * sin(60 * degToRad), 100 * cos(60 * degToRad)],
    [VECTOR_LINE, 90 * sin(-10 * degToRad), 90 * cos(-10 * degToRad), 95 * sin(-10 * degToRad), 95 * cos(-10 * degToRad)],
    [VECTOR_LINE, 90 * sin(-20 * degToRad), 90 * cos(-20 * degToRad), 95 * sin(-20 * degToRad), 95 * cos(-20 * degToRad)],
    [VECTOR_LINE, 90 * sin(-30 * degToRad), 90 * cos(-30 * degToRad), 100 * sin(-30 * degToRad), 100 * cos(-30 * degToRad)],
    [VECTOR_LINE, 90 * sin(-45 * degToRad), 90 * cos(-45 * degToRad), 95 * sin(-45 * degToRad), 95 * cos(-45 * degToRad)],
    [VECTOR_LINE, 90 * sin(-60 * degToRad), 90 * cos(-60 * degToRad), 100 * sin(-60 * degToRad), 100 * cos(-60 * degToRad)]
  ]
  children = {
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
    //watch = isAAMMode
    size = [width * 0.5, height * 0.1]
    pos = [width * 0.25, height * 0.1]
    clipChildren = true
    children = /*!isAAMMode.value ?*/ [
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
    ]/* : null*/
  }
}

let MachValue = Computed(@() (Mach.get() * 1000).tointeger())
let mach = @(){
  watch = [IlsColor, MachValue]
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  pos = [Mach.get() < 1.0 ? pw(11) : pw(9), ph(62)]
  color = IlsColor.get()
  fontSize = 35
  text = MachValue.get() >= 1000.0 ? format("%.3f", Mach.get()) : format(".%03d", MachValue.get())
}

let OverloadValue = Computed(@() (Overload.get() * 10).tointeger())
let overload = @(){
  watch = OverloadValue
  size = SIZE_TO_CONTENT
  pos = [pw(5), ph(65)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 35
  text = format("%.1f 9.0G", OverloadValue.get() * 0.1)
}

let AltValue = Computed(@() (Altitude.get() * metrToFeet).tointeger())
let radarAlt = @(){
  watch = IlsColor
  pos = [pw(80), ph(38)]
  size = [pw(12), ph(5)]
  color = IlsColor.get()
  flow = FLOW_HORIZONTAL
  halign = ALIGN_RIGHT
  children = [
    {
      size = [SIZE_TO_CONTENT, flex()]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = "R "
      valign = ALIGN_CENTER
    }
    @(){
      watch = AltValue
      size = [SIZE_TO_CONTENT, flex()]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 45
      text = (AltValue.get() / 1000).tostring()
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
    }
    @(){
      watch = AltValue
      size = [SIZE_TO_CONTENT, flex()]
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      padding = [0, 2]
      text = format("%03d", BarAltValue.get() % 1000)
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
    }
  ]
}

let radarReticle = @() {
  watch = RadarTargetPosValid
  size = flex()
  children = RadarTargetPosValid.get() ?
  [
    @() {
      watch = IlsColor
      size = [pw(7), ph(7)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = [
        [VECTOR_RECTANGLE, -50, -50, 100, 100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = RadarTargetPos
        }
      }
    }
  ] : null
}

let isDGFTMode = Computed(@() isAAMMode.get() && RadarTargetPosValid.get())
let IsLaunchZoneVisible = Computed(@() isDGFTMode.get() && AamLaunchZoneDistMax.get() > 0.0)
let MaxDistLaunch = Computed(@() (DistanceMax.get() * 1000.0 * metrToNavMile).tointeger())
let MaxLaunchPos = Computed(@() ((1.0 - AamLaunchZoneDistMax.get()) * 100.0).tointeger())
let MinLaunchPos = Computed(@() ((1.0 - AamLaunchZoneDistMin.get()) * 100.0).tointeger())
let IsDgftLaunchZoneVisible = Computed(@() AamLaunchZoneDistDgftMax.get() > 0.0)
let MaxLaunchDgftPos = Computed(@() ((1.0 - AamLaunchZoneDistDgftMax.get()) * 100.0).tointeger())
let MinLaunchDgftPos = Computed(@() ((1.0 - AamLaunchZoneDistDgftMin.get()) * 100.0).tointeger())
let RadarClosureSpeed = Computed(@() (RadarTargetDistRate.get() * mpsToKnots * -1.0).tointeger())
let launchZone = @(){
  watch = IsLaunchZoneVisible
  size = [pw(8), ph(30)]
  pos = [pw(74), ph(30)]
  children = IsLaunchZoneVisible.get() ? [
    @(){
      watch = AamLaunchZoneDist
      size = flex()
      pos = [pw(-100), ph((1.0 - AamLaunchZoneDist.get()) * 100.0)]
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
          size = [pw(20), ph(5)]
          color = IlsColor.get()
          lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
          commands = [
            [VECTOR_LINE, 0, 0, 100, 50],
            [VECTOR_LINE, 0, 100, 100, 50]
          ]
        }
      ]
    },
    {
      size = [pw(25), flex()]
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
        {
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
            @() {
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
            },
          ]
        }
      ]
    }
  ] : null
}

let aamReticle = @(){
  watch = [isAAMMode, IlsTrackerVisible]
  size = flex()
  children = isAAMMode.get() && IlsTrackerVisible.get() ? @(){
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    size = [pw(20), ph(20)]
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
    fillColor = Color(0, 0, 0, 0)
    commands = [
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
    ]
    children = hasRadarTarget.get() ? @(){
      watch = IlsColor
      size = [pw(120), ph(120)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = [
        [VECTOR_LINE, 0, 83, 0, 100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = acos(-RadarTargetAngle.get()) * radToDeg
          pivot = [0, 0]
        }
      }
    } : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [IlsTrackerX.get(), IlsTrackerY.get()]
      }
    }
  } : null
}

let adlMarker = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(2), ph(2)]
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

let haveRadatTarget = Computed(@() RadarTargetDist.get() > 0)
let radarTargetDistValue = Computed(@() (RadarTargetDist.get() * metrToNavMile * 10.0).tointeger())
let targetAlt = Computed(@() (RadarTargetHeight.get() * metrToFeet * 0.01).tointeger())
let targetParam = @(){
  watch = [haveRadatTarget, BombingMode]
  size = flex()
  children = haveRadatTarget.get() && BombingMode.get() ? [
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
      watch = targetAlt
      pos = [pw(80), ph(59)]
      size = flex()
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = format("%d-%d", targetAlt.get() * 0.1, targetAlt.get() % 10)
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
let ccrp = @(){
  watch = BombingMode
  size = flex()
  children = BombingMode.get() ? [
    @(){
      watch = timeRelease
      pos = [pw(80), ph(65)]
      size = flex()
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 35
      text = format("%02d:%02d TREL", timeRelease.get() / 60, timeRelease.get() % 60)
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

let showGunReticle = Computed(@() (BombingMode.get() ? AimLockValid.get() : TargetPosValid.get()) && !isAAMMode.get() && !AirCannonMode.get())
let radarTargetDistSector = Computed(@() cvt((isCCIPMode.get() || BombingMode.get() ? DistToTarget.get() : RadarTargetDist.get()), 0.0, 3657.6, -90.0, 269.0).tointeger())
let gunReticle = @() {
  watch = showGunReticle
  size = [ph(8), ph(8)]
  children = showGunReticle.get() ? [
    @(){
      watch = [hasRadarTarget, isCCIPMode, BombingMode]
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
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
        [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get() * 1.5],
        [VECTOR_LINE, 0, 0, 0, 0]
      ]
      children = hasRadarTarget.get() ? @(){
        watch = radarTargetDistSector
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
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
      translate = BombingMode.get() ? TvvMark : [TargetPos.get()[0], TargetPos.get()[1]]
    }
  }
}

let aimLock = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.get() ? @(){
    watch = IlsColor
    size = [pw(2.5), ph(2.5)]
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
  children = BombCCIPMode.get() && TargetPosValid.get() ? @() {
    watch = [TargetPos, IlsColor]
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
    commands = [
      [VECTOR_LINE, TvvMark[0] / IlsPosSize[2] * 100, TvvMark[1] / IlsPosSize[2] * 100,
        TargetPos.get()[0] / IlsPosSize[2] * 100,
        TargetPos.get()[1] / IlsPosSize[2] * 100]
    ]
  } : null
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
  watch = [isCCIPMode, isAAMMode, BulletImpactLineEnable]
  size = flex()
  children = BulletImpactLineEnable.get() && !isCCIPMode.get() && !isAAMMode.get() ? @() {
    watch = [BulletImpactPoints1, BulletImpactPoints2, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
    commands = getBulletImpactLineCommand()
  } : null
}

let bulletsImpactLines = @(){
  watch = AirCannonMode
  size = flex()
  children = AirCannonMode.get() ? [
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

function ilsF15e(width, height) {
  return {
    size = [width, height]
    children = [
      speed
      aoa
      tvvLinked(width, height)
      barAlt
      radarAlt
      rollIndicator
      compassWrap(width, height, generateCompassMark)
      mach
      overload
      radarReticle
      launchZone
      aamReticle
      adlMarker
      targetParam
      gunReticle
      aimLock
      bombImpactLine
      ccrp
      bulletsImpactLines
    ]
  }
}

return ilsF15e