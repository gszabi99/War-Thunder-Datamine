from "%rGui/globals/ui_library.nut" import *

let { Tangage, BarAltitude, Speed, Mach, Overload, Roll, CompassValue } = require("%rGui/planeState/planeFlyState.nut")
let { IlsColor, IlsLineScale, TargetPos, RadarTargetPos, RadarTargetPosValid, RadarTargetDist,
 TargetPosValid, IlsPosSize, RadarTargetDistRate, BombCCIPMode, TvvMark, CannonMode,
 RocketMode, DistToTarget, BombingMode, AimLockPos, AimLockValid, TimeBeforeBombRelease } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet } = require("ilsConstants.nut")
let string = require("string")
let { cvt } = require("dagor.math")
let { cos, sin, PI } = require("%sqstd/math.nut")
let { AdlPoint, ShellCnt } = require("%rGui/planeState/planeWeaponState.nut")
let { GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { IsAamLaunchZoneVisible, AamLaunchZoneDistMinVal, AamLaunchZoneDistMaxVal } = require("%rGui/radarState.nut")

let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let isCCIPMode = Computed(@() BombCCIPMode.value || RocketMode.value || CannonMode.value)
let generateAltMark = function(num) {
  return {
    size = [pw(100), ph(7.5)]
    pos = [pw(0), 0]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * (num % 5 > 0 ? 2 : 3), baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        vplace = ALIGN_CENTER
      },
      (num % 5 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = (num * 100).tostring()
        }
      )
    ]
  }
}

function altitude(height, generateFunc) {
  let children = []

  for (local i = 650; i >= 0; i -= 1) {
    children.append(generateFunc(i))
  }

  let getOffset = @() ((65000 - BarAltitude.value * metrToFeet) * 0.0007425 - 0.48) * height
  return {
    size = [pw(100), ph(100)]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -getOffset()]
      }
    }
    children = [
      @(){
        watch = IlsColor
        size = [baseLineWidth * IlsLineScale.value, ph(4827.5)]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
      }
      {
        size = flex()
        flow = FLOW_VERTICAL
        children = children
      }
    ]
  }
}

function altWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.8, height * 0.2]
    clipChildren = true
    flow = FLOW_HORIZONTAL
    children = [
      {
        size = [pw(10), ph(5)]
        pos = [0, ph(47.5)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 0, 0, 100, 50],
          [VECTOR_LINE, 0, 100, 100, 50]
        ]
      }
      altitude(height * 0.5, generateFunc)
    ]
  }
}

let generateSpdMark = function(num) {
  let ofs = num < 10 ? pw(-30) : pw(-40)
  return {
    size = [pw(100), ph(7.5)]
    pos = [pw(50), 0]
    children = [
      (num % 5 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          pos = [ofs, 0]
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = (num * 10).tostring()
        }
      ),
      @() {
        watch = IlsColor
        pos = [baseLineWidth * (num % 5 > 0 ? 1 : 0), ph(25)]
        size = [baseLineWidth * (num % 5 > 0 ? 2 : 3), baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
      }
    ]
  }
}

function speed(height, generateFunc) {
  let children = []

  for (local i = 1000; i >= 0; i -= 10) {
    children.append(generateFunc(i / 10))
  }

  let getOffset = @() ((1000.0 - Speed.value * mpsToKnots) * 0.00745 - 0.5) * height
  return {
    size = [pw(100), ph(100)]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -getOffset()]
      }
    }
    children = [
      @(){
        watch = IlsColor
        pos = [pw(60), 0]
        size = [baseLineWidth * IlsLineScale.value, ph(745)]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
      }
      {
        size = flex()
        flow = FLOW_VERTICAL
        children = children
      }
    ]
  }
}

function speedWrap(width, height, generateFunc) {
  return @(){
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.1, height * 0.2]
    clipChildren = true
    children = [
      speed(height * 0.5, generateFunc)
      {
        size = [pw(10), ph(5)]
        pos = [pw(61), ph(47.5)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 0, 50, 100, 0],
          [VECTOR_LINE, 0, 50, 100, 100]
        ]
      }
    ]
  }
}

let adlMarker = @() {
  watch = isAAMMode
  size = flex()
  children = !isAAMMode.value ? @(){
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    size = [pw(2), ph(2)]
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, -100, 0, 100, 0],
      [VECTOR_LINE, 0, -100, 0, 100],
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [AdlPoint[0], AdlPoint[1]]
      }
    }
  } : null
}

let axisMarker = @() {
  watch = isAAMMode
  size = flex()
  children = isAAMMode.value ? @(){
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    pos = [pw(50), ph(50)]
    size = [pw(3), ph(2)]
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, -100, 0, -50, 0],
      [VECTOR_LINE, -50, 0, -25, 100],
      [VECTOR_LINE, 0, 0, -25, 100],
      [VECTOR_LINE, 100, 0, 50, 0],
      [VECTOR_LINE, 50, 0, 25, 100],
      [VECTOR_LINE, 0, 0, 25, 100]
    ]
  } : null
}

let showGunReticle = Computed(@() (BombingMode.value ? AimLockValid.value : TargetPosValid.value) && !isAAMMode.value)
let radarTargetDistSector = Computed(@() cvt((isCCIPMode.value || BombingMode.value ? DistToTarget.value : RadarTargetDist.value), 0.0, 3657.6, -90.0, 269.0).tointeger())
let hasRadarTarget = Computed(@() RadarTargetDist.value >= 0.0 || ((isCCIPMode.value || BombingMode.value) && TargetPosValid.value))
let gunReticle = @() {
  watch = showGunReticle
  size = [ph(8), ph(8)]
  children = showGunReticle.value ? [
    @(){
      watch = [hasRadarTarget, isCCIPMode, BombingMode]
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
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
        [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value * 3.0],
        [VECTOR_LINE, 0, 0, 0, 0]
      ]
      children = hasRadarTarget.value ? @(){
        watch = radarTargetDistSector
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_SECTOR, 0, 0, 80, 80, -90, radarTargetDistSector.value],
          [VECTOR_LINE, 80 * cos(PI * radarTargetDistSector.value / 180.), 80 * sin(PI * radarTargetDistSector.value / 180.),
           70 * cos(PI * radarTargetDistSector.value / 180.), 70 * sin(PI * radarTargetDistSector.value / 180.)]
        ]
      } : (!isCCIPMode.value && !BombingMode.value ? {
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_SECTOR, 0, 0, 50, 50, 10, 80],
          [VECTOR_SECTOR, 0, 0, 50, 50, 100, 170],
          [VECTOR_SECTOR, 0, 0, 50, 50, 190, 260],
          [VECTOR_SECTOR, 0, 0, 50, 50, 280, 350]
        ]
      } : null)
    }
  ] : null
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = BombingMode.value ? TvvMark : [TargetPos.value[0], TargetPos.value[1]]
    }
  }
}

let bombImpactLine = @() {
  watch = [BombCCIPMode, TargetPosValid]
  size = flex()
  children = BombCCIPMode.value && TargetPosValid.value ? @() {
    watch = [TargetPos, IlsColor]
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, TvvMark[0] / IlsPosSize[2] * 100, TvvMark[1] / IlsPosSize[2] * 100,
        TargetPos.value[0] / IlsPosSize[2] * 100,
        TargetPos.value[1] / IlsPosSize[2] * 100]
    ]
  } : null
}

let radarReticle = @() {
  watch = RadarTargetPosValid
  size = flex()
  children = RadarTargetPosValid.value ?
  [
    @() {
      watch = IlsColor
      size = [pw(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
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

let aamReticle = @() {
  watch = isAAMMode
  size = flex()
  children = isAAMMode.value ? {
    size = [ph(12), ph(12)]
    pos = [pw(50), ph(50)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 100, 100]
    ]
  } : null
}

let shellCnt = @() {
  watch = [ShellCnt, isAAMMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(15), ph(75)]
  color = IlsColor.value
  fontSize = 40
  font = Fonts.hud
  text = isAAMMode.value ? string.format("S %d", ShellCnt.value) : ShellCnt.value.tostring()
}

let machWatched = Computed(@() (Mach.value * 1000.0).tointeger())
let mach = @() {
  watch = [machWatched, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(14), ph(79)]
  color = IlsColor.value
  fontSize = 40
  font = Fonts.hud
  text = Mach.value >= 1. ? string.format("%.3f", Mach.value) : string.format(".%d", machWatched.value)
}

let overloadWatch = Computed(@() (Overload.value * 10.0).tointeger())
let overload = @() {
  watch = [overloadWatch, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(14), ph(83)]
  color = IlsColor.value
  fontSize = 40
  font = Fonts.hud
  text = string.format("%.1fG", overloadWatch.value / 10.0)
}

let distScaleVisible = Computed(@() RadarTargetDist.value > 0.0 && !BombingMode.value)
let maxLaunchDistPos = Computed(@() cvt(AamLaunchZoneDistMaxVal.value, 0.0, 18520.0, 100.0, 0.0).tointeger())
let minLaunchDistPos = Computed(@() cvt(AamLaunchZoneDistMinVal.value, 0.0, 18520.0, 100.0, 0.0).tointeger())
let RadarClosureSpeed = Computed(@() (RadarTargetDistRate.value * mpsToKnots * -0.1).tointeger())
let distScale = @(){
  watch = distScaleVisible
  size = flex()
  children = distScaleVisible.value ? {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [pw(10), ph(30)]
    pos = [pw(70), ph(30)]
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, 70, 0, 70, 100],
      [VECTOR_LINE, 70, 0, 80, 0],
      [VECTOR_LINE, 70, 25, 80, 25],
      [VECTOR_LINE, 70, 100, 80, 100],
      [VECTOR_LINE, 70, 75, 80, 75],
      [VECTOR_LINE, 70, 50, 80, 50]
    ]
    children = [
      {
        rendObj = ROBJ_TEXT
        pos = [pw(60), ph(-10)]
        size = SIZE_TO_CONTENT
        color = IlsColor.value
        fontSize = 30
        font = Fonts.hud
        text = "10"
      }
      {
        rendObj = ROBJ_TEXT
        pos = [pw(80), ph(46)]
        size = SIZE_TO_CONTENT
        color = IlsColor.value
        fontSize = 30
        font = Fonts.hud
        text = "5"
      }
      {
        size = [pw(15), ph(4)]
        pos = [pw(55), 0]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 100, 0, 0, -100],
          [VECTOR_LINE, 100, 0, 0, 100]
        ]
        children = @() {
          watch = RadarClosureSpeed
          size = [pw(350), ph(200)]
          pos = [pw(-350), ph(-100)]
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          font = Fonts.hud
          fontSize = 30
          text = (RadarClosureSpeed.value * 10.0).tointeger().tostring()
        }
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [0, cvt(RadarTargetDist.value, 0.0, 18520.0, 0.3, 0.0) * IlsPosSize[3]]
          }
        }
      }
      @() {
        watch = IsAamLaunchZoneVisible
        size = [pw(20), flex()]
        pos = [pw(70), 0]
        children = IsAamLaunchZoneVisible.value ? [
          @(){
            watch = maxLaunchDistPos
            rendObj = ROBJ_SOLID
            size = [flex(), baseLineWidth * IlsLineScale.value * 2.0]
            pos = [0, ph(maxLaunchDistPos.value)]
            color = IlsColor.value
          }
          @(){
            watch = minLaunchDistPos
            rendObj = ROBJ_SOLID
            size = [flex(), baseLineWidth * IlsLineScale.value * 2.0]
            pos = [0, ph(minLaunchDistPos.value)]
            color = IlsColor.value
          }
        ] : null
      }
    ]
  } : null
}

function generatePitchLine(num) {
  return {
    size = [pw(70), ph(50)]
    pos = [pw(15), 0]
    children = [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        commands = [
          (num == 0 ? [VECTOR_LINE, -10, 0, 40, 0] : []),
          (num == 0 ? [VECTOR_LINE, 60, 0, 110, 0] : []),
          (num > 0 ? [VECTOR_LINE, 12, 0, 40, 0] : []),
          (num > 0 ? [VECTOR_LINE, 60, 0, 88, 0] : []),
          (num != 0 ? [VECTOR_LINE, 88, 0, 88, 5] : []),
          (num != 0 ? [VECTOR_LINE, 12, 0, 12, 5] : []),
          (num < 0 ? [VECTOR_LINE, 12, 0, 16, 0] : []),
          (num < 0 ? [VECTOR_LINE, 20, 0, 24, 0] : []),
          (num < 0 ? [VECTOR_LINE, 28, 0, 32, 0] : []),
          (num < 0 ? [VECTOR_LINE, 36, 0, 40, 0] : []),
          (num < 0 ? [VECTOR_LINE, 88, 0, 84, 0] : []),
          (num < 0 ? [VECTOR_LINE, 80, 0, 76, 0] : []),
          (num < 0 ? [VECTOR_LINE, 72, 0, 68, 0] : []),
          (num < 0 ? [VECTOR_LINE, 64, 0, 60, 0] : []),
        ]
      },
      (num != 0 ? @() {
        size = SIZE_TO_CONTENT
        pos = [pw(90), ph(-5)]
        watch = IlsColor
        rendObj = ROBJ_TEXT
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        fontSize = 35
        font = Fonts.hud
        text = num.tostring()
      } : null),
      (num != 0 ? @() {
        size = [pw(20), SIZE_TO_CONTENT]
        pos = [pw(-10), ph(-5)]
        watch = IlsColor
        rendObj = ROBJ_TEXT
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
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
    size = [width * 0.5, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.05]
        rotate = -Roll.value
        pivot = [0.5, (90.0 - Tangage.value) * 0.1]
      }
    }
  }
}

function pitchWrap(width, height) {
  return {
    size = [pw(50), ph(50)]
    pos = [pw(-25), 0]
    children = pitch(width, height, generatePitchLine)
  }
}

function tvvLinked(width, height) {
  let pitchElem = pitchWrap(width, height)
  return @(){
    watch = isAAMMode
    size = flex()
    children = !isAAMMode.value ? [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = [pw(3), ph(3)]
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_LINE, -100, 0, -50, 0],
          [VECTOR_LINE, 100, 0, 50, 0],
          [VECTOR_LINE, 0, -100, 0, -50]
        ]
      }
      pitchElem
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TvvMark
      }
    }
  }
}

let generateCompassMark = function(num, width) {
  return {
    size = [width * 0.15, ph(100)]
    children = [
      {
        size = SIZE_TO_CONTENT
        pos = [0, baseLineWidth * 4]
        rendObj = ROBJ_TEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 30
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      {
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * (num % 10 == 0 ? 3 : 2)]
        pos = [0, baseLineWidth * (num % 10 == 0 ? 0 : 1)]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
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

  let getOffset = @() (360.0 + CompassValue.value) * 0.075 * width
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
  let compassElem = compass(width * 0.2, generateFunc)
  return @(){
    watch = isAAMMode
    size = [width * 0.5, height * 0.1]
    pos = [width * 0.25, height * 0.1]
    clipChildren = true
    children = !isAAMMode.value ? [
      compassElem
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 0, 19, 100, 19],
          [VECTOR_LINE, 50, 19, 48, 35],
          [VECTOR_LINE, 50, 19, 52, 35]
        ]
      }
    ] : null
  }
}

let CCRPTarget = @() {
  watch = AimLockValid
  size = [pw(3), ph(3)]
  children = AimLockValid.value ? {
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_RECTANGLE, -50, -50, 100, 100]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [AimLockPos[0], AimLockPos[1]]
      }
    }
  } : null
}

let lowerSolutionCue = @(){
  watch = IlsColor
  size = [pw(10), baseLineWidth * IlsLineScale.value]
  rendObj = ROBJ_SOLID
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  behavior = Behaviors.RtPropUpdate
  update = function() {
    let cuePos = TimeBeforeBombRelease.value <= 0.0 ? 0.4 : cvt(TimeBeforeBombRelease.value, 0.0, 10.0, 0, 0.4)
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
            size = [baseLineWidth * IlsLineScale.value, flex()]
            rendObj = ROBJ_SOLID
            color = IlsColor.value
            lineWidth = baseLineWidth * IlsLineScale.value
          }
        ]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [AimLockPos[0], 0]
        rotate = -Roll.value
        pivot = [0, AimLockPos[1] / IlsPosSize[3]]
      }
    }
  }
}

let SecondsToRelease = Computed(@() TimeBeforeBombRelease.value.tointeger())
let timeToRelease = @() {
  watch = SecondsToRelease
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  color = IlsColor.value
  pos = [pw(82), ph(80)]
  fontSize = 40
  text = SecondsToRelease.value > 0 ? string.format("%d SEC", SecondsToRelease.value) : ""
}

let ccrpMarks = @() {
  watch = BombingMode
  size = flex()
  children = BombingMode.value ? [
    timeToRelease
    CCRPTarget
    rotatedBombReleaseReticle()
  ] : null
}

let inRange = Computed(@() GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING)
let inRangeLabel = @() {
  watch = [inRange, IlsColor]
  rendObj = ROBJ_TEXT
  pos = [pw(75), ph(75)]
  color = IlsColor.value
  fontSize = 40
  font = Fonts.hud
  text = inRange.value ? "IN RNG" : ""
}

function ilsF15a(width, height) {
  return {
    size = [width, height]
    children = [
      altWrap(width, height, generateAltMark)
      speedWrap(width, height, generateSpdMark)
      adlMarker
      axisMarker
      gunReticle
      shellCnt
      radarReticle
      mach
      overload
      aamReticle
      distScale
      inRangeLabel
      bombImpactLine
      tvvLinked(width, height)
      compassWrap(width, height, generateCompassMark)
      ccrpMarks
    ]
  }
}

return ilsF15a