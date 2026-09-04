import "string" as string
from "%rGui/planeState/planeToolsState.nut" import IlsColor, IlsLineScale, BombingMode, BombCCIPMode, DistToSafety, TimeBeforeBombRelease, AimLocked
  , TargetPos, TargetPosValid, RocketMode, CannonMode, RadarTargetPosValid
from "%rGui/planeIlses/ilsConstants.nut" import baseLineWidth, metrToFeet
from "%rGui/planeState/planeFlyState.nut" import Aos, Tangage, Roll, BarAltitude, Altitude
from "%rGui/rocketAamAimState.nut" import GuidanceLockState
from "%rGui/radarState.nut" import Irst, TargetsTrigger, Azimuth
from "%rGui/planeState/planeWeaponState.nut" import BulletImpactPoints1, BulletImpactPoints2, BulletImpactLineEnable
from "guidanceConstants" import GuidanceLockResult
from "%rGui/globals/ui_library.nut" import *

let { targets } = require("%rGui/radarState.nut")
let { RADAR_TAGET_TYPE_TARGET } = require("guiRadar").RadarTargetType

let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)

function flyDirection(width, height, isLockedFlyPath = false) {
  return @() {
    watch = [IlsColor, BombCCIPMode, BombingMode, IlsLineScale]
    size = [width * 0.1, height * 0.1]
    pos = [width * 0.5, height * (BombCCIPMode.get() || BombingMode.get() || isLockedFlyPath ? 0.5 : 0.3)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 20, 20],
      [VECTOR_LINE, -50, 0, -20, 0],
      [VECTOR_LINE, 20, 0, 50, 0],
      [VECTOR_LINE, 0, -20, 0, -40]
    ]
  }
}

function angleTxt(num, isLeft, textFont, invVPlace = 1, font_size = 60, x = 0, y = 0) {
  return @() {
    watch = IlsColor
    pos = [x, y]
    rendObj = ROBJ_TEXT
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.get()
    fontSize = font_size
    font = textFont
    text = num.tostring()
  }
}

let aosOffset = Computed(@() Aos.get().tointeger())
let yawIndicator = @() {
  size = const [pw(3), ph(3)]
  pos = [pw(50), ph(80)]
  watch = [IlsColor, aosOffset]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.get()
  color = IlsColor.get()
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, aosOffset.get() * 10, 0, 50, 50],
    [VECTOR_LINE, 0, -100, 0, 100],
  ]
}

let cancelBombVisible = Computed(@() DistToSafety.get() <= 0.0)
function cancelBombing(posY, size) {
  return @() {
    watch = cancelBombVisible
    size = FLEX
    children = cancelBombVisible.get() ?
      @() {
        watch = IlsColor
        size = [pw(size), ph(size)]
        pos = [pw(50), ph(posY)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_LINE, -50, -50, 50, 50],
          [VECTOR_LINE, -50, 50, 50, -50]
        ]
        animations = [
          { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, play = true, loop = true }
        ]
      }
    : null
  }
}


function bombFallingLine() {
  return @() {
    watch = [IlsColor, IlsLineScale]
    size = [baseLineWidth * IlsLineScale.get(), ph(65)]
    rendObj = ROBJ_SOLID
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
  }
}

let lowerCuePos = Computed(@() clamp(0.4 - TimeBeforeBombRelease.get() * 0.05, 0.1, 0.5))
let lowerCueShow = Computed(@() AimLocked.get() && TimeBeforeBombRelease.get() > 0.0)
function lowerSolutionCue(height, posX) {
  return @() {
    watch = lowerCueShow
    size = FLEX
    children = lowerCueShow.get() ?
      @() {
        watch = [IlsColor, lowerCuePos]
        size = [pw(10), baseLineWidth * IlsLineScale.get()]
        pos = [pw(posX), lowerCuePos.get() * height - baseLineWidth * 0.5 * IlsLineScale.get()]
        rendObj = ROBJ_SOLID
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
      }
    : null
  }
}

let shimadzuRoll = @(width) {
  size = const [pw(15), ph(5)]
  pos = [pw(42.5), ph(width)]
  children = @() {
    watch = IlsColor
    size = FLEX
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_LINE, 0, 0, 10, 0],
      [VECTOR_LINE, 10, 0, 30, 100],
      [VECTOR_LINE, 30, 100, 50, 0],
      [VECTOR_LINE, 50, 0, 70, 100],
      [VECTOR_LINE, 70, 100, 90, 0],
      [VECTOR_LINE, 90, 0, 100, 0]
    ]
  }
  behavior = Behaviors.RtPropUpdate
  update = @() {
      transform = {
        rotate = -Roll.get()
      }
    }
}

function ShimadzuPitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generateFunc(num))
  }

  return {
    size = [width * 0.5, height * 0.7]
    pos = [width * 0.25, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.get()) * 0.07]
      }
    }
  }
}

function ShimadzuAlt(height, generateFunc) {
  let children = []

  for (local i = 2000; i >= 0; i -= 10) {
    children.append(generateFunc(i))
  }

  let getOffset = @() ((20000 - BarAltitude.get()) * 0.0007425 - 0.4625) * height
  return {
    size = const [pw(100), ph(100)]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -getOffset()]
      }
    }
    flow = FLOW_VERTICAL
    children = children
  }
}

let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())
let aimMark = @() {
  watch = [TargetPosValid, CCIPMode]
  size = FLEX
  children = TargetPosValid.get() ?
    @() {
      watch = IlsColor
      size = const [pw(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, 0, 0, 0, 0],
        [VECTOR_LINE, 0, 50, 50, 0],
        [VECTOR_LINE, 50, 0, 0, -50],
        [VECTOR_LINE, 0, -50, -50, 0],
        [VECTOR_LINE, -50, 0, 0, 50],
        (CCIPMode.get() ? [VECTOR_LINE, -50, -50, 50, -50] : [])
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.get()[0], TargetPos.get()[1]]
        }
      }
    }
  : null
}

let ASPAirSymbol = @() {
  watch = IlsColor
  size = const [pw(70), ph(70)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.get()
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, -100, 0, -30, 0],
    [VECTOR_LINE, -40, 0, -40, 10],
    [VECTOR_LINE, 100, 0, 30, 0],
    [VECTOR_LINE, 40, 0, 40, 10],
    [VECTOR_LINE, 0, -30, 0, -70],
  ]
}

let ASPAirSymbolWrap = {
  size = FLEX
  children = ASPAirSymbol
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      rotate = Roll.get()
      pivot = [0, 0]
    }
  }
}


let targetsComponent = function(createTargetDistFunc) {
  let getTargets = function() {
    let targetsRes = []
    for (local i = 0; i < targets.len(); ++i) {
      if (!targets[i])
        continue
      else if (targets[i].targetType != RADAR_TAGET_TYPE_TARGET)
        continue
      else if (targets[i].signalRel < 0.01)
        continue
      targetsRes.append(createTargetDistFunc(i))
    }
    return targetsRes
  }

  return @() {
    size = FLEX
    children = Irst.get() && RadarTargetPosValid.get() ? null : getTargets()
    watch = [TargetsTrigger, Irst, RadarTargetPosValid]
  }
}

function ASPLaunchPermitted(is_ru, l_pos, h_pos, is_cn = false) {
  return @() {
    watch = GuidanceLockState
    size = FLEX
    children = (GuidanceLockState.get() >= GuidanceLockResult.RESULT_TRACKING ?
      @() {
        watch = IlsColor
        size = FLEX
        rendObj = ROBJ_TEXT
        pos = [pw(l_pos), ph(h_pos)]
        color = IlsColor.get()
        fontSize = 40
        font = Fonts.hud
        text = is_ru ? "ПР" : (is_cn ? "允许攻击" : "INRNG")
      }
      : null)
  }
}

let ASPAzimuthMark = @() {
  watch = [Azimuth, IlsColor]
  size = [pw(5), baseLineWidth * 0.8 * IlsLineScale.get()]
  pos = [pw(Azimuth.get() * 100 - 2.5), ph(95)]
  rendObj = ROBJ_SOLID
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
}

let SUMAltValue = Computed(@() clamp(Altitude.get() * metrToFeet, 0, 4995).tointeger())
let SUMAltThousands = Computed(@() SUMAltValue.get() > 1000 ? $"{SUMAltValue.get() / 1000}" : "")
let SUMAltVis = Computed(@() Altitude.get() * metrToFeet < 4995)
function SUMAltitude(font_size, posiiton = [pw(60), ph(25)]) {
  return @() {
    watch = SUMAltVis
    size = FLEX
    pos = posiiton
    children = SUMAltVis.get() ? [
      @() {
        watch = [SUMAltValue, IlsColor]
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        fontSize = font_size
        font = Fonts.hud
        text = string.format("R%s.%03d", SUMAltThousands.get(), SUMAltValue.get() % 1000)
      }
    ] : null
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
    commands.append([VECTOR_LINE, point1.x, point1.y, point2.x, point2.y])
  }
  for (local i = 0; i < BulletImpactPoints2.get().len() - 2; ++i) {
    let point1 = BulletImpactPoints2.get()[i]
    let point2 = BulletImpactPoints2.get()[i + 1]
    if (point1.x == -1 && point1.y == -1)
      continue
    if (point2.x == -1 && point2.y == -1)
      continue
    commands.append([VECTOR_LINE, point1.x, point1.y, point2.x, point2.y])
  }
  return commands
}

let bulletsImpactLine = @() {
  watch = [CCIPMode, isAAMMode, BulletImpactLineEnable]
  size = FLEX
  children = BulletImpactLineEnable.get() && !CCIPMode.get() && !isAAMMode.get() ? @() {
    watch = [BulletImpactPoints1, BulletImpactPoints2, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = FLEX
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = getBulletImpactLineCommand()
  } : null
}

return {
  flyDirection
  angleTxt,
  yawIndicator,
  cancelBombing,
  bombFallingLine,
  lowerSolutionCue,
  shimadzuRoll,
  ShimadzuPitch,
  ShimadzuAlt,
  aimMark,
  ASPAirSymbolWrap,
  ASPLaunchPermitted,
  targetsComponent,
  ASPAzimuthMark,
  SUMAltitude,
  bulletsImpactLine
}