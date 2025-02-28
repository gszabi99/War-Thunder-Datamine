from "%rGui/globals/ui_library.nut" import *

let { IlsColor, TargetPosValid, TargetPos, IlsLineScale, BombingMode, RocketMode, AirCannonMode,
       AAMRocketMode, CannonMode, BombCCIPMode,RadarTargetPos, RadarTargetPosValid, RadarTargetDist, RadarTargetDistRate,
       IlsPosSize, RadarTargetHeight, RadarTargetAngle, RadarTargetBearing } = require("%rGui/planeState/planeToolsState.nut")
let { Speed, BarAltitude, Roll, Aoa, Gear, ClimbSpeed, Overload, Tangage } = require("%rGui/planeState/planeFlyState.nut");
let { mpsToKnots, mpsToFpm, baseLineWidth, metrToFeet, meterToYard, metrToNavMile } = require("ilsConstants.nut")
let { CurWeaponName, BulletImpactPoints1, BulletImpactLineEnable } = require("%rGui/planeState/planeWeaponState.nut")
let { cvt } = require("dagor.math")
let { compassWrap, generateCompassMarkSUM } = require("ilsCompasses.nut")
let { yawIndicator, SUMAltitude } = require("commonElements.nut")
let { AamLaunchZoneDistMinVal, AamLaunchZoneDistMaxVal } = require("%rGui/radarState.nut")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { sin, cos, PI, abs, log10, round } = require("math")

let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())
let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)
let isTakeOffOrLanding = Computed(@() Gear.get() > 0.95)


let HarrierAoaMarkH = Computed(@() cvt(Aoa.get(), 0, 24, 100, -20).tointeger())
let HarrierAoa = @() {
  watch = [HarrierAoaMarkH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(30)]
  pos = [pw(15), ph(40)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * 3 * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 0, 20, 0, 20],
    [VECTOR_LINE, 0, 40, 0, 40],
    [VECTOR_LINE, 0, 60, 0, 60],
    [VECTOR_LINE, 100, 60, 100, 60],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get()],
    [VECTOR_LINE, -20, 100, 100, 100],
    [VECTOR_LINE, 50, HarrierAoaMarkH.get(), -50, HarrierAoaMarkH.get() - 5],
    [VECTOR_LINE, 50, HarrierAoaMarkH.get(), -50, HarrierAoaMarkH.get() + 5],
    [VECTOR_LINE, -20, 100, -20, HarrierAoaMarkH.get()]
  ]
}

let HarrierVSMarkH = Computed(function() {
    local sign = 1
    let logCoef = 3.322
    if (ClimbSpeed.get() < 0)
        sign = -1

    let norm = abs(ClimbSpeed.get() * mpsToFpm) / 500.0
    if (norm >= 1) {
        return clamp(50 - (log10(norm) * logCoef + 1) * sign * 12.5, -5, 105)
    }
    return 50 - 12.5 * norm * sign
})

let HarrierVerticalSpeed = @() {
  watch = [HarrierVSMarkH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(30)]
  pos = [pw(85), ph(40)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * 1 * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, -50, 0, 50, 0],
    [VECTOR_LINE, -50, 12, 50, 12],
    [VECTOR_LINE, -50, 25, 50, 25],
    [VECTOR_LINE, -25, 37, 50, 37],

    [VECTOR_LINE, -150, 50, 100, 50],

    [VECTOR_LINE, -25, 62, 50, 62],
    [VECTOR_LINE, -50, 75, 50, 75],
    [VECTOR_LINE, -50, 87, 50, 87],
    [VECTOR_LINE, -50, 100, 50, 100],
    [VECTOR_LINE, 5, HarrierVSMarkH.get(), 100, HarrierVSMarkH.get() - 5],
    [VECTOR_LINE, 5, HarrierVSMarkH.get(), 100, HarrierVSMarkH.get() + 5],
    [VECTOR_LINE, 100, 50, 100, HarrierVSMarkH.get()]
  ]
}

let AircraftSymbol = @() {
  watch = IlsColor
  size = [pw(10), ph(10)]
  pos = [pw(50), ph(40)]
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

let VSTOLAircraftSymbol = @() {
  watch = IlsColor
  size = [pw(10), ph(10)]
  pos = [pw(50), ph(40)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 20, 14],
    [VECTOR_LINE, -50, 0, -20, 0],
    [VECTOR_LINE, 20, 0, 50, 0],
    [VECTOR_LINE, 13, 13, 40, 30],
    [VECTOR_LINE, -13, 13, -40, 30]
  ]
}

let isClimb = Computed(@() ClimbSpeed.get() > 0.0)
let HarrierClimbAngle = @() {
  watch = [IlsColor, isClimb]
  size = [pw(10), ph(10)]
  pos = [pw(50), ph(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = isClimb.get() ? [
    [VECTOR_LINE, -20, 0, 0, -35],
    [VECTOR_LINE, 0, -35, 20, 0],
    [VECTOR_LINE, 20, 0, -20, 0]
  ] : [
    [VECTOR_LINE, -20, 0, 0, 35],
    [VECTOR_LINE, 0, 35, 20, 0],
    [VECTOR_LINE, 20, 0, -20, 0]
  ]
}

let HarrierSpeedValue = Computed(@() round(Speed.get() * mpsToKnots).tointeger())
let HarrierSpeed = @() {
  watch = [HarrierSpeedValue, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(14), ph(72)]
  color = IlsColor.get()
  fontSize = 45
  font = Fonts.hud
  text = $"{HarrierSpeedValue.get()}"
}

let HarrierOverloadValue = Computed(@() (Overload.get() * 10.0).tointeger())
let OverloadValue = @() {
  watch = [HarrierOverloadValue, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(14), ph(78)]
  color = IlsColor.get()
  fontSize = 45
  font = Fonts.hud
  text = $"{HarrierOverloadValue.get() / 10}.{(HarrierOverloadValue.get() % 10).tointeger()}g"
}

function getPointOnCircle(r, a) {
  return { x = r * sin(a), y = - r * cos(a)}
}

let HarrierHeight = Computed(@() (BarAltitude.get() * metrToFeet).tointeger())

function CircleHeightIndicator() {

  let commands = []
  let PointsNum = 10

  for (local i = 0; i < PointsNum; i++) {
    let curAngle = 2 * PI * i / PointsNum
    let point = getPointOnCircle(100, curAngle)
    commands.append([VECTOR_LINE, point.x, point.y, point.x, point.y])
  }

  let curAngle = 2 * PI * (HarrierHeight.get() % 1000) / 1000.;
  let point1 = getPointOnCircle(60, curAngle)
  let point2 = getPointOnCircle(100, curAngle)

  commands.append([VECTOR_LINE, point1.x, point1.y, point2.x, point2.y])

  return {
    watch = [BarAltitude, IlsColor]
    size = [pw(40), ph(40)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * 1.5 * IlsLineScale.get()
    commands = commands
  }
}

let BarometricHeightText = @() {
  watch = [HarrierHeight, IlsColor]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  hplace = ALIGN_CENTER
  pos = [pw(-50), ph(-8)]
  fontSize = 45
  font = Fonts.hud
  text = $"{HarrierHeight.get().tointeger() - HarrierHeight.get().tointeger() % 20}"
}

let BarometricHeight = @() {
  watch = [HarrierHeight, IlsColor]
  pos = [pw(83), ph(83)]
  size = [pw(20), ph(20)]
  children = [
    HarrierHeight.get() < 8000 ? CircleHeightIndicator : null,
    BarometricHeightText,
  ]
}


function HarrierCompass(w, h) {
  return @() {
    pos = [pw(0), ph(0)]
    size = [pw(100), ph(100)]
    watch = [IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * IlsLineScale.get()
    color = IlsColor.get()
    children = [compassWrap(w, h, 0.85, generateCompassMarkSUM)]
    commands = [
       [VECTOR_LINE, 50, 93, 50, 100],
    ]
  }
}

function angleTxt(num, isLeft, invVPlace = 1, x = 0) {
  return @() {
    watch = IlsColor
    rendObj = ROBJ_TEXT
    pos = [x, num > 0 ? 10 : 0]
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.get()
    fontSize = 45
    font = Fonts.hud
    text = num.tostring()
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  return {
    size = [pw(80), ph(50)]
    pos = [pw(10), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = [0, 10]
        commands = [
          [VECTOR_LINE, -10, 0, 30, 0],
          [VECTOR_LINE, 30, 0, 30, 10],
          [VECTOR_LINE, 70, 0, 70, 10],
          [VECTOR_LINE, 70, 0, 110, 0]
        ]
        children = [angleTxt(-5, true, 1, pw(-15)), angleTxt(-5, false, 1, pw(14))]
      }
    ] : (num == 90 || num == -85 ? [
        @() {
          size = flex()
          watch = IlsColor
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = baseLineWidth * IlsLineScale.get()
          color = IlsColor.get()
          commands = [
            [VECTOR_LINE, 50, sign > 0 ? 0 : 100, 50, sign > 0 ? 30 : 70],
            [VECTOR_LINE, 35, sign > 0 ? 10 : 92, 65, sign > 0 ? 10 : 92],
            (sign < 0 ? [VECTOR_LINE, 40, 85, 60, 85] : [])
          ]
        }
      ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        commands = [
          [VECTOR_LINE, -10, 5 * sign, -10, 0],
          [VECTOR_LINE, -10, 0, num > 0 ? 30 : -2, 0],
          (num < 0 ? [VECTOR_LINE, 6, 0, 14, 0] : []),
          (num < 0 ? [VECTOR_LINE, 22, 0, 30, 0] : []),
          [VECTOR_LINE, 110, 5 * sign, 110, 0],
          [VECTOR_LINE, 110, 0, num > 0 ? 70 : 102, 0],
          (num < 0 ? [VECTOR_LINE, 94, 0, 86, 0] : []),
          (num < 0 ? [VECTOR_LINE, 78, 0, 70, 0] : [])
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, 1, pw(-9)), angleTxt(newNum, false, 1, pw(9))] : null
      }
    ])
  }
}

function LaunchLine(width, height) {
  return {
    size = [width * 0.4, height * 0.5]
    pos = [pw(30), ph(40)]
    flow = FLOW_VERTICAL
    children = [
       @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = [0, 10]
        commands = [
          [VECTOR_LINE, 25, 0, 35, 0],
          [VECTOR_LINE, 25, 0, 18, 4],
          [VECTOR_LINE, 25, 0, 18, -4],

          [VECTOR_LINE, 65, 0, 75, 0],
          [VECTOR_LINE, 75, 0, 82, -4],
          [VECTOR_LINE, 75, 0, 82, 4]
        ]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (12 - Tangage.get()) * 0.05]
        rotate = -Roll.get()
        pivot = [0.5, (12 - Tangage.get()) * 0.1]
      }
    }
  }
}

function HorizonLines(width, height) {
  const step = 5.0
  let children = []

  let start = (90.0 / step).tointeger();
  let stop = (-90.0 / step).tointeger();

  for (local i = start; i > stop; --i) {
    let num = (i * step).tointeger()

    children.append(generatePitchLine(num))
  }

  return {
    size = [width * 0.4, height * 0.5]
    pos = [pw(30), ph(40)]
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

let HarrierYawIndicator = @() {
  pos = [pw(0), ph(15)]
  size = flex()
  children = [yawIndicator]
}

let AimMark = @() {
  watch = [TargetPosValid, CCIPMode]
  size = flex()
  children = TargetPosValid.get() ?
    @() {
      watch = IlsColor
      size = [pw(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = BombingMode.get() ?
      [
        [VECTOR_LINE, -50, 0, 50, 0],

        [VECTOR_LINE, 150, 0, 150, -80],
        [VECTOR_LINE, 250, 0, 250, -80],
        [VECTOR_LINE, 350, 0, 350, -80],
        [VECTOR_LINE, -150, 0, -150, -80],
        [VECTOR_LINE, -250, 0, -250, -80],
        [VECTOR_LINE, -350, 0, -350, -80],
      ]:
      [
        [VECTOR_LINE, 0, 0, 0, 0],
        [VECTOR_LINE, 0, 50, 50, 0],
        [VECTOR_LINE, 50, 0, 0, -50],
        [VECTOR_LINE, 0, -50, -50, 0],
        [VECTOR_LINE, -50, 0, 0, 50],
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

let CCIPLine = @(){
  watch = [TargetPosValid]
  size = flex()
  children = TargetPosValid.get() ? {
    size = [baseLineWidth * IlsLineScale.get(), ph(98)]
    rendObj = ROBJ_SOLID
    color = IlsColor.get()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.get()[0], TargetPos.get()[1] - IlsPosSize[3] * 1]
      }
    }
  } : null
}

let DepressionCarret = @(){
  watch = [TargetPosValid]
  size = flex()
  children = TargetPosValid.get() ? {
    size = [pw(50), ph(50)]
    pos = [ph(0), ph(50)]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * IlsLineScale.get()
    color = IlsColor.get()
    behavior = Behaviors.RtPropUpdate
    commands = [
      [VECTOR_LINE, -15, 0, -20, 5],
      [VECTOR_LINE, -15, 0, -20, -5],
      [VECTOR_LINE, 15, 0, 20, 5],
      [VECTOR_LINE, 15, 0, 20, -5],
    ]
    update = @() {
      transform = {
        translate = [TargetPos.get()[0], 0]
      }
    }
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
    commands.append([VECTOR_LINE, point1.x, point1.y, point2.x, point2.y])
  }
  return commands
}

let BulletsImpactLine = @() {
  watch = [CCIPMode, isAAMMode, BulletImpactLineEnable]
  size = flex()
  children = BulletImpactLineEnable.get() && !CCIPMode.get() && !isAAMMode.get() ? @() {
    watch = [BulletImpactPoints1, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = getBulletImpactLineCommand()
  } : null
}

let RangingCircle = @() {
  watch = [CCIPMode, isAAMMode, BulletImpactLineEnable]
  size = flex()
  children = BulletImpactLineEnable.get() ? @() {
    watch = [BulletImpactPoints1, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    fillColor = Color(0, 0, 0, 0)
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [[VECTOR_ELLIPSE, BulletImpactPoints1.get()[0].x, BulletImpactPoints1.get()[0].y, 2, 2]]
  } : null
}

function getPolygonByDistance(dist, increment, n, pos) {
  let commands = []

  for (local i = 0; i < n; i++) {
    if (increment * (i + 1) > dist)
      break

    let angle1 = (2 * PI * i) / n
    let angle2 = (2 * PI * (i + 1)) / n
    let point1 = getPointOnCircle(5, angle1)
    let point2 = getPointOnCircle(5, angle2)
    commands.append([VECTOR_LINE, point1.x + pos.x, point1.y + pos.y, point2.x + pos.x, point2.y + pos.y])
  }

  return commands
}

let RangeOctagon = @() {
  watch = [RadarTargetPosValid, RadarTargetDist, BulletImpactLineEnable]
  size = flex()
  children = BulletImpactLineEnable.get() && RadarTargetPosValid ? @() {
    watch = [BulletImpactPoints1, IlsColor]
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = getPolygonByDistance(RadarTargetDist.get() * meterToYard, 100, 8, BulletImpactPoints1.get()[0])
  } : null
}

let WeaponHudCode = @() {
  rendObj = ROBJ_TEXT
  watch = [CurWeaponName]
  pos = [pw(83), ph(24)]
  size = SIZE_TO_CONTENT
  hplace = ALIGN_LEFT
  color = IlsColor.get()
  fontSize = 45
  font = Fonts.hud
  text = CurWeaponName.get() != "" ? loc($"{CurWeaponName.get()}/sea_harrier_fa2") : "G6Z"
}

// Radar Target

let TargetCross = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(2.5), ph(2.5)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 0, 50, 0, 100],
    [VECTOR_LINE, 0, -50, 0, -100],
    [VECTOR_LINE, 50, 0, 100, 0],
    [VECTOR_LINE, -50, 0, -100, 0],
  ]
}

let RadarTargetCross = @()
{
  watch = RadarTargetPosValid
  size = flex()
  children = [(RadarTargetPosValid.get() ? TargetCross : null)]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = RadarTargetPos
    }
  }
}

let HarrierRadarTargetBearing = @() {
  rendObj = ROBJ_TEXT
  watch = [RadarTargetPosValid, RadarTargetBearing]
  pos = [pw(13), ph(34)]
  size = SIZE_TO_CONTENT
  hplace = ALIGN_LEFT
  color = IlsColor.get()
  fontSize = 45
  font = Fonts.hud
  text = $"{(RadarTargetBearing.get() > 0 ? "+" : "")}{(RadarTargetBearing.get() / PI * 180).tointeger()}"
}

let RadarTartgetRelHeight = @() {
  rendObj = ROBJ_TEXT
  watch = [RadarTargetPosValid, RadarTargetHeight]
  pos = [pw(83), ph(30)]
  size = SIZE_TO_CONTENT
  hplace = ALIGN_LEFT
  color = IlsColor.get()
  fontSize = 45
  font = Fonts.hud
  text = $"{((RadarTargetHeight.get() - BarAltitude.get()) > 0 ? "+" : "")}{((RadarTargetHeight.get() - BarAltitude.get()) * metrToFeet / 100).tointeger()}"
}

let RadarTartgetRelVel = @() {
  rendObj = ROBJ_TEXT
  watch = [RadarTargetPosValid, RadarTargetHeight]
  pos = [pw(83), ph(34)]
  size = SIZE_TO_CONTENT
  hplace = ALIGN_LEFT
  color = IlsColor.get()
  fontSize = 45
  font = Fonts.hud
  text = $"{(RadarTargetDistRate.get() > 0 ? "+" : "")}{(RadarTargetDistRate.get() * mpsToKnots).tointeger()}"
}


function RadarTargetVelDirection() {
  let point = getPointOnCircle(95, -RadarTargetAngle.get())
  return @() {
    watch = [IlsColor, RadarTargetPosValid, RadarTargetAngle]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [pw(100), ph(100)]
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = RadarTargetPosValid.get() ? [
      [VECTOR_LINE, point.x, point.y, point.x * 2, point.y * 2],
    ] : null
    update = @() {
      transform = {
        rotate = -Roll.get()
      }
    }
  }
}

let RadarTargetMarkerCirle = @() {
  watch = [IlsColor, RadarTargetPosValid, RadarTargetAngle]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(2.5), ph(2.5)]
  pos = [pw(50), ph(50)]
  color = IlsColor.get()
  fillColor = Color(0,0,0,0)
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = RadarTargetPosValid.get() ? [
    [VECTOR_ELLIPSE, 0, 0, 100, 100],
  ] : null
  children = [RadarTargetVelDirection()]
}

// Rockets

let RocketLockTargetDiamond = @() {
  watch = IlsTrackerVisible
  size = flex()
  children = IlsTrackerVisible.get() ?
  [
    @() {
      watch = [IlsColor, GuidanceLockState]
      size = [pw(10), ph(10)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = GuidanceLockState.get() > GuidanceLockResult.RESULT_LOCKING ? [
        [VECTOR_POLY, -50, 0, 0, 50, 50, 0, 0, -50]
      ] : [
        [VECTOR_LINE, 25, 25, 50, 50],
        [VECTOR_LINE, -25, -25, -50, -50],
        [VECTOR_LINE, 25, -25, 50, -50],
        [VECTOR_LINE, -25, 25, -50, 50],
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

function RadarRangeDecagon() {
  let commands = getPolygonByDistance(RadarTargetDist.get() * metrToNavMile, 1, 10, {x = 0, y = 0});

  for (local i = 0; i < 10; i++) {
    let angle = (2 * PI * i) / 10
    let point = getPointOnCircle(5, angle)
    commands.append([VECTOR_LINE, point.x, point.y, point.x, point.y])
  }

  let angleMax = (2 * PI * AamLaunchZoneDistMaxVal.get() * metrToNavMile) / 10

  let pointMax = getPointOnCircle(5, angleMax)
  commands.append([VECTOR_LINE, 0.6 * pointMax.x, 0.6 * pointMax.y, pointMax.x, pointMax.y])

  let angleMin = (2 * PI * AamLaunchZoneDistMinVal.get() * metrToNavMile) / 10

  let pointMin = getPointOnCircle(5, angleMin)
  commands.append([VECTOR_LINE, 0.6 * pointMin.x, 0.6 * pointMin.y, pointMin.x, pointMin.y])

  return {
    watch = [RadarTargetPosValid, RadarTargetDist, AamLaunchZoneDistMinVal, AamLaunchZoneDistMaxVal]
    size = flex()
    children = RadarTargetPosValid.get() ? @() {
      watch = [IlsColor, RadarTargetDist]
      pos = [pw(50), ph(50)]
      size = [pw(150), ph(150)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = commands
    } : null
  }
}

function RocketLaunchPromptTextValue() {
  if (RadarTargetDist.get() > AamLaunchZoneDistMaxVal.get())
    return "RMAX"
  if (RadarTargetDist.get() < AamLaunchZoneDistMinVal.get())
    return "RMIN"
  return "SHOOT"
}

let RocketLaunchPromptText = @() {
  rendObj = ROBJ_TEXT
  watch = [IlsColor, RadarTargetDist, AamLaunchZoneDistMinVal, AamLaunchZoneDistMaxVal]
  size = SIZE_TO_CONTENT
  pos = [-100, -16]
  hplace = ALIGN_CENTER
  color = IlsColor.get()
  fontSize = 34
  font = Fonts.hud
  text = RocketLaunchPromptTextValue()
}

let RocketLaunchPrompt = @() {
  watch = [IlsColor, RadarTargetDist, AamLaunchZoneDistMinVal, AamLaunchZoneDistMaxVal]
  pos = [pw(50), ph(35)]
  size = [pw(20), ph(20)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  fillColor = Color(0,0,0,0)
  commands = [[VECTOR_POLY, -30, -10, -30, 10, 30, 10, 30, -10]]
  children = [RocketLaunchPromptText]
}

// Modes

let HarrierRadarData = @() {
  watch = [CCIPMode, RadarTargetPosValid]
  size = flex()
  children = RadarTargetPosValid.get() ? [
    RadarTargetCross,
    RadarTartgetRelHeight,
    RadarTargetMarkerCirle,
    HarrierRadarTargetBearing,
    RadarTartgetRelVel,
  ] : null
}

function BasicSeaHarrier(width, height) {
  return @() {
    watch = [CCIPMode]
    size = [width, height]
    children = [
      HarrierAoa,
      HarrierCompass(width, height),
      HorizonLines(width, height),
      AAMRocketMode.get() ? HarrierClimbAngle : null,
      HarrierVerticalSpeed,
      SUMAltitude(60),
      HarrierSpeed,
      BarometricHeight,
      WeaponHudCode,
      HarrierRadarData
    ]
  }
}

function HarrierAAM(width, height) {
  return @() {
    size = [width, height]
    watch = [AAMRocketMode, isTakeOffOrLanding, RadarTargetPosValid]
    children = AAMRocketMode.get() && !isTakeOffOrLanding.get() ? [
      RocketLockTargetDiamond,
      RadarRangeDecagon,
      RadarTargetPosValid.get() ? RocketLaunchPrompt : null,
    ] : null
  }
}

function HarrierAirGuns(width, height) {
  return @() {
    size = [width, height]
    watch = [AirCannonMode, isTakeOffOrLanding]
    children = AirCannonMode.get() && !isTakeOffOrLanding.get() ? [
      BulletsImpactLine,
      RangingCircle,
      RangeOctagon
    ] : null
  }
}

function HarrierGroundGunsAndBombs(width, height) {
  return @() {
    watch = [CannonMode, isTakeOffOrLanding]
    size = [width, height]
    children = (CannonMode.get() || BombCCIPMode.get()) && !isTakeOffOrLanding.get() ? [
      CCIPLine,
      AimMark,
      DepressionCarret,
    ] : null
  }
}

function HarrierGeneralFlight(width, height) {
  return @() {
    watch = [isTakeOffOrLanding]
    size = [width, height]
    children = !isTakeOffOrLanding.get() ? [
      !AAMRocketMode.get() ? AircraftSymbol : null,
      OverloadValue
    ] : null
  }
}

function HarrierLandingAndTakeOff(width, height) {
  return @() {
    watch = [isTakeOffOrLanding]
    size = [width, height]
    children = isTakeOffOrLanding.get() ? [
      HarrierYawIndicator,
      LaunchLine(width, height),
      VSTOLAircraftSymbol
    ] : null
  }
}

function IlsSeaHarrier(width, height) {
  return {
    size = [width, height]
    children = [
      BasicSeaHarrier(width, height),
      HarrierGeneralFlight(width, height),
      HarrierAirGuns(width, height),
      HarrierLandingAndTakeOff(width, height),
      HarrierGroundGunsAndBombs(width, height),
      HarrierAAM(width, height),
    ]
  }
}

return IlsSeaHarrier