from "%rGui/globals/ui_library.nut" import *

let { Speed, Altitude, ClimbSpeed, Roll, Accel } = require("%rGui/planeState/planeFlyState.nut");
let { IlsColor,  BombingMode, TargetPosValid, TargetPos, CannonMode,
        DistToSafety,  DistToTarget, BombCCIPMode, RocketMode,
        RadarTargetPosValid, RadarTargetPos, IlsLineScale,
        AimLockPos, AimLockValid, TimeBeforeBombRelease } = require("%rGui/planeState/planeToolsState.nut")
let { mpsToKmh, baseLineWidth } = require("%rGui/planeIlses/ilsConstants.nut")
let { compassWrap, generateCompassMarkASP } = require("%rGui/planeIlses/ilsCompasses.nut")
let { ASPAirSymbolWrap, ASPLaunchPermitted, targetsComponent, ASPAzimuthMark } = require("%rGui/planeIlses/commonElements.nut")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")
let { DistanceMax, RadarModeNameId, IsRadarVisible, Irst, targets, HasDistanceScale,
  HasAzimuthScale, IsCScopeVisible } = require("%rGui/radarState.nut")
let { mode } = require("%rGui/radarComponent.nut")
let { cvt } = require("dagor.math")
let { round } = require("math")

let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())
let ASPSpeedValue = Computed(@() round(Speed.get() * mpsToKmh).tointeger())
let ASPSpeed = @() {
  watch = [ASPSpeedValue, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(21), ph(30)]
  color = IlsColor.get()
  fontSize = 45
  font = Fonts.ussr_ils
  text = ASPSpeedValue.get().tostring()
}

let ASPAltValue = Computed(@() (Altitude.get()).tointeger())
let ASPAltitude = @() {
  watch = [ASPAltValue, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(70), ph(30)]
  color = IlsColor.get()
  fontSize = 45
  font = Fonts.ussr_ils
  text = ASPAltValue.get().tostring()
}

let ASPRoll = @() {
  watch = IlsColor
  size = static [pw(15), ph(15)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.get()
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, -100, 0, -80, 0],
    [VECTOR_LINE, -96.6, 25.9, -77.3, 20.7],
    [VECTOR_LINE, -86.6, 50, -69.3, 40],
    [VECTOR_LINE, -50, 86.6, -40, 69.3],
    [VECTOR_LINE, 50, 86.6, 40, 69.3],
    [VECTOR_LINE, 86.6, 50, 69.3, 40],
    [VECTOR_LINE, 96.6, 25.9, 77.3, 20.7],
    [VECTOR_LINE, 100, 0, 80, 0],
    [VECTOR_LINE, -15, 0, -5, 0],
    [VECTOR_LINE, 15, 0, 5, 0],
    [VECTOR_LINE, 0, -15, 0, -5],
    [VECTOR_LINE, 0, 15, 0, 5]
  ]
  children = ASPAirSymbolWrap
}

let ASPCompassMark = @() {
  watch = IlsColor
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
  color = IlsColor.get()
  fillColor = IlsColor.get()
  commands = [
    [VECTOR_LINE, 32, 33, 68, 33],
    [VECTOR_POLY, 49, 36, 50, 33, 51, 36]
  ]
}

let DistToTargetBuc = Computed(@() cvt(TimeBeforeBombRelease.get(), 0, 10.0, -90, 250).tointeger())
function ASPTargetMark(width, height, is_radar, isIpp, is_aam = false) {
  let watchVar = is_aam ? IlsTrackerVisible : (is_radar ? RadarTargetPosValid : TargetPosValid)
  return @() {
    watch = watchVar
    size = flex()
    children = watchVar.value ?
      @() {
        watch = [IlsColor, BombingMode]
        size = static [pw(3), ph(3)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100],
          (!is_radar ? [VECTOR_LINE, 0, 0, 0, 0] : [])
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = watchVar.value ? (is_aam ? [IlsTrackerX.get(), IlsTrackerY.get()] : (is_radar ? RadarTargetPos : TargetPos.get())) : [width * 0.5, height * 0.575]
            rotate = -Roll.get()
            pivot = [0, 0]
          }
        }
        children = [
          isIpp && BombingMode.get() ? @() {
            watch = DistToTargetBuc
            size = flex()
            rendObj = ROBJ_VECTOR_CANVAS
            color = IlsColor.get()
            fillColor = Color(0, 0, 0, 0)
            lineWidth = baseLineWidth * IlsLineScale.get()
            commands = [
              [VECTOR_SECTOR, 0, 0, 200, 200, -90, DistToTargetBuc.get()],
            ]
          } : null
        ]
      }
      : null
  }
}

function basicASP23(width, height) {
  return @() {
    size = [width, height]
    children = [
      compassWrap(width, height, 0.25, generateCompassMarkASP, 0.6, 5.0, false, -1, Fonts.ussr_ils),
      ASPCompassMark,
      ASPSpeed,
      ASPAltitude
    ]
  }
}

let ASPLRGrid = @() {
  watch = IlsColor
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, 5, 0, 5, 100],
    [VECTOR_LINE, 5, 0, 8, 0],
    [VECTOR_LINE, 5, 16.5, 8, 16.5],
    [VECTOR_LINE, 5, 33, 8, 33],
    [VECTOR_LINE, 5, 50, 8, 50],
    [VECTOR_LINE, 5, 66, 8, 66],
    [VECTOR_LINE, 5, 83.5, 8, 83.5],
    [VECTOR_LINE, 5, 100, 8, 100],
    [VECTOR_LINE, 5, 50, 2, 48],
    [VECTOR_LINE, 5, 50, 2, 52],
    [VECTOR_LINE, 95, 0, 95, 100],
    [VECTOR_LINE, 92, 0, 95, 0],
    [VECTOR_LINE, 92, 20, 97, 20],
    [VECTOR_LINE, 92, 40, 97, 40],
    [VECTOR_LINE, 92, 60, 97, 60],
    [VECTOR_LINE, 92, 80, 97, 80],
    [VECTOR_LINE, 92, 100, 95, 100],
    [VECTOR_LINE, 95, 50, 98, 48],
    [VECTOR_LINE, 95, 50, 98, 52]
  ]
}

function ASPRadarDist(is_ru, w_pos) {
  return @() {
    watch = [DistanceMax, IlsColor]
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    pos = [pw(w_pos), ph(0)]
    color = IlsColor.get()
    fontSize = 40
    font = is_ru ? Fonts.ussr_ils : Fonts.usa_ils
    text = (DistanceMax.get()).tointeger()
  }
}

let ASPRadarMode = @() {
  watch = [RadarModeNameId, IsRadarVisible, Irst, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(-7),  Irst.get() ? ph(50) : ph(15)]
  color = IlsColor.get()
  fontSize = 35
  font = Fonts.hud
  text = Irst.get() ? "T" : mode(RadarModeNameId, IsRadarVisible)
}

let ASPRadarRoll = @() {
  watch = IlsColor
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, 25, 30, 42, 30],
    [VECTOR_LINE, 58, 30, 75, 30]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      rotate = Roll.get()
      pivot = [0.5, 0.3]
    }
  }
}

function createTargetDistASP23(index) {
  let target = targets[index]
  let dist = HasDistanceScale.get() ? target.distanceRel : 0.9;
  let distanceRel = IsCScopeVisible.get() ? target.elevationRel : dist

  let angleRel = HasAzimuthScale.get() ? target.azimuthRel : 0.5
  let angularWidthRel = HasAzimuthScale.get() ? target.azimuthWidthRel : 1.0
  let angleLeft = angleRel - 0.5 * angularWidthRel
  let angleRight = angleRel + 0.5 * angularWidthRel

  return @() {
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
    color = IlsColor.get()
    commands = [
      [VECTOR_LINE,
        !RadarTargetPosValid.get() ? 100 * angleLeft : 10,
        100 * (1 - distanceRel),
        !RadarTargetPosValid.get() ? 100 * angleRight : 15,
        100 * (1 - distanceRel)
      ],
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.get() ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) - 5,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) + 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.get() ? [VECTOR_LINE,
        100 * angleRight + 2,
        100 * (1 - distanceRel) - 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) + 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.get() ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) - 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) - 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.get() ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) + 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) + 5
      ] : []),
      (!target.isEnemy ?
        [VECTOR_LINE,
          !RadarTargetPosValid.get() ? 100 * angleLeft : 10,
          100 * (1 - distanceRel) - 3,
          !RadarTargetPosValid.get() ? 100 * angleRight : 15,
          100 * (1 - distanceRel) - 3
        ] : [])
    ]
  }
}

function ASP23LongRange(width, height) {
  return @() {
    watch = [Irst, IlsColor]
    size = [width * 0.5, height * 0.35]
    pos = [width * 0.25, height * 0.4]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
    color = IlsColor.get()
    commands = [
      [VECTOR_LINE, 45, 30, 48, 30],
      [VECTOR_LINE, 52, 30, 55, 30],
      [VECTOR_LINE, 50, 24, 50, 28],
      [VECTOR_LINE, 50, 32, 50, 36]
    ]
    children = [
      (!Irst.get() ? ASPLRGrid : null),
      (!Irst.get() ? ASPRadarDist(true, -5) : null),
      ASPRadarMode,
      ASPRadarRoll,
      targetsComponent(createTargetDistASP23),
      ASPLaunchPermitted(true, 48, 80),
      ASPAzimuthMark
    ]
  }
}

function ASPCCIPDistanceGrid() {
  let minDist = Computed(@() Altitude.get() - DistToSafety.get())
  return @() {
    watch = [IlsColor, minDist]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
    size = flex()
    color = IlsColor.get()
    commands = [
      [VECTOR_LINE, 27, 38, 27, 80],
      [VECTOR_LINE, 25, 38, 27, 38],
      [VECTOR_LINE, 25, 46.4, 27, 46.4],
      [VECTOR_LINE, 25, 54.8, 27, 54.8],
      [VECTOR_LINE, 25, 63.2, 27, 63.2],
      [VECTOR_LINE, 25, 72, 27, 72],
      [VECTOR_LINE, 25, 80, 27, 80],
      [VECTOR_WIDTH, baseLineWidth * 2.2 * IlsLineScale.get()],
      [VECTOR_LINE, 27.5, (80 - minDist.get() / 5000.0 * 42), 30, (80 - minDist.get() / 5000.0 * 42)]
    ]
    children =
    {
      size = flex()
      rendObj = ROBJ_TEXT
      pos = [pw(22), ph(36)]
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.ussr_ils
      text = "5"
    }
  }
}

let DistMarkPos = Computed(@() clamp((38 + (5000.0 - DistToTarget.get()) / 5000.0 * 42), 38, 80).tointeger())
let ASPCCIPDistanceMark = @() {
  watch = DistMarkPos
  size = static [pw(3), ph(2)]
  pos = [pw(27), ph(DistMarkPos.get())]
  children = @() {
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
    size = flex()
    color = IlsColor.get()
    commands = [
      [VECTOR_LINE, 0, 0, 40, -100],
      [VECTOR_LINE, 0, 0, 40, 100],
      [VECTOR_LINE, 40, -100, 40, -50],
      [VECTOR_LINE, 40, -50, 100, -50],
      [VECTOR_LINE, 40, 100, 40, 50],
      [VECTOR_LINE, 40, 50, 100, 50],
    ]
  }
}

function IPPCCRPLine(_width, height) {
  return @() {
    watch = [TargetPosValid, BombCCIPMode, BombingMode, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
    size = flex()
    color = IlsColor.get()
    commands = [
      (TargetPosValid.get() && (BombCCIPMode.get() || BombingMode.get()) ? [VECTOR_LINE, 0, 0, 0, -100] : [])
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TargetPosValid.get() ? [TargetPos.get()[0], clamp(TargetPos.get()[1], 0, height)] : [TargetPos.get()[0], height]
        rotate = -Roll.get()
        pivot = [0, 0]
      }
    }
  }
}

function ASP23CCIP(width, height, isIpp) {
  return {
    size = [width, height]
    children = [
      ASPTargetMark(width, height, false, isIpp),
      (!isIpp ? ASPCCIPDistanceGrid() : null),
      (!isIpp ? ASPCCIPDistanceMark : null),
      (isIpp ? IPPCCRPLine(width, height) : null)
    ]
  }
}

let IPPAccelWatch = Computed(@() clamp((50.0 - Accel.get() * mpsToKmh), 0, 100).tointeger())
let IPPAcceleration = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
  size = static [pw(10), ph(5)]
  pos = [pw(15), ph(35)]
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, 0, 0, 0, 50],
    [VECTOR_LINE, 25, 25, 25, 25],
    [VECTOR_LINE, 100, 0, 100, 50],
    [VECTOR_LINE, 75, 25, 75, 25],
    [VECTOR_LINE, 50, 0, 50, 50]
  ]
  children = @() {
    watch = IPPAccelWatch
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
    size = flex()
    color = IlsColor.get()
    commands = [
      [VECTOR_LINE, 100 - IPPAccelWatch.get(), 65, 100 - IPPAccelWatch.get() + 20, 100],
      [VECTOR_LINE, 100 - IPPAccelWatch.get(), 65, 100 - IPPAccelWatch.get() - 20, 100],
      [VECTOR_LINE, 100 - IPPAccelWatch.get() - 20, 100, 100 - IPPAccelWatch.get() + 20, 100]
    ]
  }
}

let IPPClimbWatch = Computed(@() clamp((3.0 - ClimbSpeed.get()) / 6.0 * 100.0, 0, 100).tointeger())
let IPPClimb = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
  size = static [pw(5), ph(30)]
  pos = [pw(70), ph(40)]
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, 0, 0, 50, 0],
    [VECTOR_LINE, 0, 16.6, 50, 16.6],
    [VECTOR_LINE, 0, 33.3, 50, 33.3],
    [VECTOR_LINE, 0, 50, 50, 50],
    [VECTOR_LINE, 0, 66.6, 50, 66.6],
    [VECTOR_LINE, 0, 66.6, 50, 66.6],
    [VECTOR_LINE, 0, 83.4, 50, 83.4],
    [VECTOR_LINE, 0, 100, 50, 100],
  ]
  children = [
    {
      size = flex()
      rendObj = ROBJ_TEXT
      pos = [pw(60), ph(-5)]
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.ussr_ils
      text = "3"
    },
    {
      size = flex()
      rendObj = ROBJ_TEXT
      pos = [pw(60), ph(95)]
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.ussr_ils
      text = "3"
    },
    {
      size = flex()
      rendObj = ROBJ_TEXT
      pos = [pw(60), ph(45)]
      color = IlsColor.get()
      fontSize = 40
      font = Fonts.ussr_ils
      text = "0"
    },
    @() {
      watch = IPPClimbWatch
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
      size = flex()
      color = IlsColor.get()
      commands = [
        [VECTOR_LINE, -50, IPPClimbWatch.get() - 5, -10, IPPClimbWatch.get()],
        [VECTOR_LINE, -50, IPPClimbWatch.get() + 5, -10, IPPClimbWatch.get()],
        [VECTOR_LINE, -50, IPPClimbWatch.get() - 5, -50, IPPClimbWatch.get() + 5]
      ]
    }
  ]
}

let IPPAimLockPosMark = @() {
  watch = IlsColor
  size = static [pw(3), ph(3)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 0, -20, 0, -100],
    [VECTOR_LINE, 0, 20, 0, 100],
    [VECTOR_LINE, 20, 0, 50, 0],
    [VECTOR_LINE, -20, 0, -50, 0]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = AimLockPos
    }
  }
}

let IPPAimLockPos = @() {
  watch = AimLockValid
  size = flex()
  children = AimLockValid.get() ? [
    IPPAimLockPosMark
  ] : null
}

function basicIPP253(width, height) {
  return {
    size = [width, height]
    children = [
      IPPAcceleration,
      IPPClimb,
      IPPAimLockPos
    ]
  }
}

function ASP23ModeSelector(width, height, isIPP) {
  return @() {
    watch = [CCIPMode, IsRadarVisible, BombingMode]
    size = [width, height]
    children = [
      basicASP23(width, height),
      (IsRadarVisible.get() && !CCIPMode.get() ? ASP23LongRange(width, height) : ASPRoll),
      (IsRadarVisible.get() && !CCIPMode.get() ? ASPTargetMark(width, height, true, false) : null),
      (CCIPMode.get() || BombingMode.get() ? ASP23CCIP(width, height, isIPP) : null),
      (isIPP ? basicIPP253(width, height) : null)
    ]
  }
}



let createTargetDistJ7E = @(index) function() {
  let target = targets[index]
  let distanceRel = HasDistanceScale.get() ? target.distanceRel : 0.9

  let angleRel = HasAzimuthScale.get() ? target.azimuthRel : 0.5
  let angularWidthRel = HasAzimuthScale.get() ? target.azimuthWidthRel : 1.0

  let angleLeft = angleRel - 0.15 * angularWidthRel
  let angleRight = angleRel + 0.15 * angularWidthRel

  return {
    watch = [HasAzimuthScale, HasDistanceScale, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = baseLineWidth * 0.6 * IlsLineScale.get()
    color = IlsColor.get()
    commands = !RadarTargetPosValid.get() ? [
      [VECTOR_LINE, 100 * angleLeft, 100 * (1 - distanceRel), 100 * angleRight, 100 * (1 - distanceRel)],
      [VECTOR_LINE, 100 * angleLeft, 100 * (1 - distanceRel), 100 * angleRel, 100 * (1 - distanceRel) + 5],
      [VECTOR_LINE, 100 * angleRight, 100 * (1 - distanceRel), 100 * angleRel, 100 * (1 - distanceRel) + 5],
      (target.isDetected || target.isSelected ? [VECTOR_LINE, 100 * angleLeft - 2, 100 * (1 - distanceRel) - 2, 100 * angleLeft - 2, 100 * (1 - distanceRel) + 7] : []),
      (target.isDetected || target.isSelected ? [VECTOR_LINE, 100 * angleRight + 2, 100 * (1 - distanceRel) - 2, 100 * angleRight + 2, 100 * (1 - distanceRel) + 7] : [])
    ] : [
      [VECTOR_LINE, 5, 100 * (1 - distanceRel), 8, 100 * (1 - distanceRel) + 3],
      [VECTOR_LINE, 5, 100 * (1 - distanceRel), 8, 100 * (1 - distanceRel) - 3],
      [VECTOR_LINE, 8, 100 * (1 - distanceRel) + 3, 8, 100 * (1 - distanceRel) - 3]
    ]
  }
}

function J7ERadar(width, height) {
  return {
    size = [width * 0.7, height * 0.4]
    pos = [width * 0.15, height * 0.3]
    children = [
      ASPRadarMode,
      targetsComponent(createTargetDistJ7E),
      ASPLaunchPermitted(false, 20, 80),
      ASPAzimuthMark,
      ASPRadarDist(false, -10)
    ]
  }
}

function J7EAdditionalHud(width, height) {
  let needAdditionalHud = Computed(@() !BombingMode.get() && !BombCCIPMode.get() && !RocketMode.get() && !CannonMode.get())
  return @() {
    watch = [needAdditionalHud, IsRadarVisible]
    size = [width, height]
    children = needAdditionalHud.get() ? [
      J7ERadar(width, height),
      (IsRadarVisible.get() ? ASPTargetMark(width, height, true, false) : null),
      ASPTargetMark(width, height, false, false, true)
    ] : null
  }
}

return {
  J7EAdditionalHud
  ASP23ModeSelector
}