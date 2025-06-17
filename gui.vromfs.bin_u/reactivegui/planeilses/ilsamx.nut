from "%rGui/globals/ui_library.nut" import *
let { Aoa, ClimbSpeed, Altitude, Speed, Tangage, Roll, Overload,
 Mach, CompassValue } = require("%rGui/planeState/planeFlyState.nut")
let { cvt } = require("dagor.math")
let { IlsColor, IlsLineScale, TargetPos, RocketMode, CannonMode, BombCCIPMode, BombingMode,
  TargetPosValid, DistToTarget, RadarTargetDist, RadarTargetDistRate, IlsPosSize,
  AimLockPos, AimLockValid, TimeBeforeBombRelease } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToFpm, metrToFeet, mpsToKnots } = require("ilsConstants.nut")
let string = require("string")
let { GuidanceLockResult } = require("guidanceConstants")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { AamLaunchZoneDistMaxVal, AamLaunchZoneDistMinVal, IsAamLaunchZoneVisible } = require("%rGui/radarState.nut")
let { BulletImpactPoints, BulletImpactLineEnable } = require("%rGui/planeState/planeWeaponState.nut")

let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let isCCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)
let SUMAoaMarkH = Computed(@() cvt(Aoa.value, 0, 25, 100, 0).tointeger())
let SUMAoa = @() {
  watch = [SUMAoaMarkH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(3), ph(30)]
  pos = [pw(15), ph(35)]
  color = IlsColor.value
  lineWidth = baseLineWidth * 2 * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 100, 0, 100, 0],
    [VECTOR_LINE, 160, 20, 160, 20],
    [VECTOR_LINE, 100, 20, 100, 20],
    [VECTOR_LINE, 100, 40, 100, 40],
    [VECTOR_LINE, 160, 60, 160, 60],
    [VECTOR_LINE, 100, 60, 100, 60],
    [VECTOR_LINE, 100, 80, 100, 80],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
    [VECTOR_LINE, 95, SUMAoaMarkH.value, 0, SUMAoaMarkH.value - 5],
    [VECTOR_LINE, 95, SUMAoaMarkH.value, 0, SUMAoaMarkH.value + 5],
    (SUMAoaMarkH.value < 96 ? [VECTOR_LINE, 20, 100, 20, SUMAoaMarkH.value + (Aoa.value > 0 ? 4 : -4)] : []),
    [VECTOR_LINE, 20, 100, 80, 100],
  ]
}

let SUMVSMarkH = Computed(@() cvt(ClimbSpeed.value * mpsToFpm, 1000, -2000, 0, 100).tointeger())
let SUMVerticalSpeed = @() {
  watch = [SUMVSMarkH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(3), ph(30)]
  pos = [pw(78), ph(35)]
  color = IlsColor.value
  lineWidth = baseLineWidth * 2 * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, -60, 0, -60, 0],
    [VECTOR_LINE, 0, 16, 0, 16],
    [VECTOR_LINE, 0, 34, 0, 34],
    [VECTOR_LINE, 0, 52, 0, 52],
    [VECTOR_LINE, 0, 68, 0, 68],
    [VECTOR_LINE, -60, 68, -60, 68],
    [VECTOR_LINE, 0, 84, 0, 84],
    [VECTOR_LINE, 0, 100, 0, 100],
    [VECTOR_LINE, -60, 100, -60, 100],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
    [VECTOR_LINE, 0, 34, 100, 34],
    [VECTOR_LINE, 5, SUMVSMarkH.value, 100, SUMVSMarkH.value - 5],
    [VECTOR_LINE, 5, SUMVSMarkH.value, 100, SUMVSMarkH.value + 5],
    (SUMVSMarkH.value < 30 || SUMVSMarkH.value > 38 ? [VECTOR_LINE, 80, 34, 80, SUMVSMarkH.value + (ClimbSpeed.value > 0.0 ? 4 : -4)] : [])
  ]
}

let altValue = Computed(@() (Altitude.value * metrToFeet).tointeger())
let altThousands = Computed(@() altValue.value > 1000 ? $"{altValue.value / 1000}" : "")
let AltitudeMark = {
  size = flex()
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 45
      font = Fonts.mirage_ils
      text = "R"
    }
    @() {
      watch = [altValue, IlsColor]
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 45
      font = Fonts.digital
      text = string.format("%s.%03d", altThousands.value, altValue.value % 1000)
    }
  ]
}

let AltThousandAngle = Computed(@() (Altitude.value * metrToFeet % 1000 / 2.7777 - 90.0).tointeger())
let altCircle = @() {
  size = pw(16)
  pos = [pw(70), ph(15)]
  children = @() {
    watch = IlsColor
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value * 2
    commands = [
      [VECTOR_LINE, 50, 0, 50, 0],
      [VECTOR_LINE, 50, 100, 50, 100],
      [VECTOR_LINE, 20.6, 9.5, 20.6, 9.5],
      [VECTOR_LINE, 2.4, 34.5, 2.4, 34.5],
      [VECTOR_LINE, 2.4, 65.5, 2.4, 65.5],
      [VECTOR_LINE, 20.6, 90.5, 20.6, 90.5],
      [VECTOR_LINE, 80.6, 90.5, 80.6, 90.5],
      [VECTOR_LINE, 97.6, 65.5, 97.6, 65.5],
      [VECTOR_LINE, 97.6, 34.5, 97.6, 34.5],
      [VECTOR_LINE, 80.6, 9.5, 80.6, 9.5]
    ]
    children = [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = const [pw(50), ph(50)]
        pos = [pw(50), ph(50)]
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 90, 0, 60, 15],
          [VECTOR_LINE, 90, 0, 60, -15]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            rotate = AltThousandAngle.value
            pivot = [0, 0]
          }
        }
      }
      AltitudeMark
    ]
  }
}

let overloadValue = Computed(@() (Overload.value * 10.0).tointeger())
let overload = @(){
  watch = IlsColor
  size = const [pw(5), ph(10)]
  pos = [pw(8), ph(37)]
  flow = FLOW_VERTICAL
  children = [
    @(){
      watch = overloadValue
      rendObj = ROBJ_TEXT
      size = flex()
      color = IlsColor.value
      font = Fonts.digital
      fontSize = 45
      halign = ALIGN_CENTER
      text = (overloadValue.value / 10.0).tostring()
    }
    {
      rendObj = ROBJ_TEXT
      size = flex()
      color = IlsColor.value
      font = Fonts.hud
      fontSize = 45
      halign = ALIGN_CENTER
      text = "G"
    }
  ]
}

let machValue = Computed(@() (Mach.value * 100.0).tointeger())
let mach = @(){
  watch = machValue
  size = const [pw(8), ph(5)]
  pos = [pw(10), ph(16)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  halign = ALIGN_CENTER
  font = Fonts.digital
  fontSize = 45
  text = string.format("%.2f", machValue.value / 100.0)
}

let speedValue = Computed(@() (Speed.value * mpsToKnots).tointeger())
let speed = @(){
  watch = speedValue
  size = const [pw(8), ph(5)]
  pos = [pw(10), ph(20)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  halign = ALIGN_CENTER
  font = Fonts.digital
  fontSize = 45
  text = speedValue.value.tostring()
}

function pitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = i * step

    children.append(generateFunc(num))
  }

  return {
    size = [width * 0.5, height * 0.5]
    pos = [width * 0.25, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.06]
        rotate = -Roll.value
        pivot = [0.5, (90.0 - Tangage.value) * 0.12]
      }
    }
  }
}

function angleTxt(num, isLeft, invVPlace = 1, x = 0, y = 0) {
  return @() {
    watch = IlsColor
    pos = [x, y]
    rendObj = ROBJ_TEXT
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.value
    fontSize = 45
    font = Fonts.digital
    text = string.format("%d", num)
  }
}

function generatePitchLine(num) {
  let newNum = num <= 0 ? num : (num - 5)
  return {
    size = const [pw(100), ph(60)]
    pos = [0, 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        commands = [
          [VECTOR_LINE, 0, 0, 25, 0],
          [VECTOR_LINE, 75, 0, 100, 0],
          [VECTOR_LINE, 75, 0, 75, 4],
          [VECTOR_LINE, 25, 0, 25, 4]
        ]
      }
    ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        commands = [
          [VECTOR_LINE, 0, 4, 0, 0],
          [VECTOR_LINE, 0, 0, num > 0 ? 21 : 3, 0],
          (num < 0 ? [VECTOR_LINE, 6, 0, 9, 0] : []),
          (num < 0 ? [VECTOR_LINE, 12, 0, 15, 0] : []),
          (num < 0 ? [VECTOR_LINE, 18, 0, 21, 0] : []),
          [VECTOR_LINE, 100, 4, 100, 0],
          [VECTOR_LINE, 100, 0, num > 0 ? 79 : 97, 0],
          (num < 0 ? [VECTOR_LINE, 94, 0, 91, 0] : []),
          (num < 0 ? [VECTOR_LINE, 88, 0, 85, 0] : []),
          (num < 0 ? [VECTOR_LINE, 82, 0, 79, 0] : [])
        ]
        children = newNum <= 90 && newNum != 0 ? [angleTxt(newNum, true, -1, 3, newNum > 0 ? 50 : 10)] : null
      }
    ]
  }
}

let aircraftSymbol = @(){
  watch = [isCCIPMode, BombingMode]
  size = flex()
  children = isCCIPMode.value || BombingMode.value ? @() {
    size = const [pw(5), ph(5)]
    pos = [pw(50), ph(50)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 30, 30],
      [VECTOR_LINE, -100, 0, -30, 0],
      [VECTOR_LINE, 100, 0, 30, 0],
      [VECTOR_LINE, 0, -100, 0, -30]
    ]
  } : null
}

let mode = @(){
  watch = [RocketMode, CannonMode, BombCCIPMode, BombingMode, isAAMMode]
  size = SIZE_TO_CONTENT
  pos = [pw(75), ph(67)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  font = Fonts.hud
  fontSize = 45
  text = RocketMode.value ? "RKT" : CannonMode.value ? "GUN" : BombCCIPMode.value ? "CCIP" : BombingMode.value ? "CCRP" : "A/A"
}

let hasRadarTarget = Computed(@() RadarTargetDist.value > 0.0)
let distanceSector = Computed(@() cvt((isCCIPMode.value ? DistToTarget.value : RadarTargetDist.value), 0.0, 3000.0, 179.0, -179.0).tointeger())
let gunReticle = @(){
  watch = [BombingMode, TargetPosValid]
  size = flex()
  children = !BombingMode.value && TargetPosValid.value ? [
    {
      size = ph(3)
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value * 0.7
      fillColor = Color(0, 0, 0, 0)
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100],
        [VECTOR_LINE, 0, 0, 0, 0]
      ]
    }
    @() {
      watch = [isCCIPMode, hasRadarTarget]
      size = flex()
      children = isCCIPMode.value || hasRadarTarget.value ? @(){
        watch = distanceSector
        rendObj = ROBJ_VECTOR_CANVAS
        size = ph(4)
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value * 0.7
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_SECTOR, 0, 0, 100, 100, distanceSector.value, 180],
          [VECTOR_LINE, -97, 25, -72.4, 19.4],
          [VECTOR_LINE, 97, 25, 72.4, 19.4]
        ]
      } : null
    }
  ] : null
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = TargetPos.value
    }
  }
}

let bombCcipLine = @(){
  watch = [BombCCIPMode, BombingMode, TargetPosValid]
  size = flex()
  children = BombCCIPMode.value || (BombingMode.value && TargetPosValid.value) ? {
    size = [baseLineWidth * IlsLineScale.value, ph(200)]
    rendObj = ROBJ_SOLID
    color = IlsColor.value
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.value[0], TargetPos.value[1] - IlsPosSize[3] * 2.0]
      }
    }
  } : null
}

let distanceTextVal = Computed(@() (isCCIPMode.value && TargetPosValid.value ? DistToTarget.value : RadarTargetDist.value).tointeger())
let distanceMark = {
  size = flex()
  pos = [pw(10), ph(70)]
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      font = Fonts.hud
      fontSize = 45
      text="M"
    }
    @(){
      watch = distanceTextVal
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      font = distanceTextVal.value >= 0.0 ? Fonts.digital : Fonts.tiny_text
      fontSize = 45
      text = distanceTextVal.value >= 0.0 ? distanceTextVal.value.tostring() : "......."
    }
  ]
}

let distanceRateValue = Computed(@() (RadarTargetDistRate.value * -mpsToKnots).tointeger())
let distanceRate = @(){
  watch = hasRadarTarget
  size = flex()
  pos = [pw(10), ph(74)]
  flow = FLOW_HORIZONTAL
  children = hasRadarTarget.value ? [
    @(){
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      font = Fonts.hud
      fontSize = 45
      text="RR"
    }
    @(){
      watch = distanceRateValue
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      font = Fonts.digital
      fontSize = 45
      text = distanceRateValue.value.tostring()
    }
  ] : null
}

let aamReticle = @(){
  watch = [isAAMMode, IlsTrackerVisible]
  size = flex()
  children = isAAMMode.value && IlsTrackerVisible.value ? @(){
    watch = GuidanceLockState
    size = const [pw(3), ph(3)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value * 0.7
    commands = GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [
      [VECTOR_POLY, 0, -100, 100, 0, 0, 100, -100, 0],
      [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
      [VECTOR_LINE, 0, 0, 0, 0]
    ] :
    [
      [VECTOR_LINE, 90, 0, 40, 0],
      [VECTOR_LINE, -90, 0, -40, 0],
      [VECTOR_LINE, 0, 90, 0, 40],
      [VECTOR_LINE, 0, -90, 0, -40]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [IlsTrackerX.value, IlsTrackerY.value]
      }
    }
  } : null
}

let aimLockMark = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.value ? @() {
    size = const [pw(4), ph(4)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, 40, 0, 100, 0],
      [VECTOR_LINE, -40, 0, -100, 0],
      [VECTOR_LINE, 0, 40, 0, 100],
      [VECTOR_LINE, 0, -40, 0, -100]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = AimLockPos
      }
    }
  } : null
}

let maxDistOfLaunchZone = Computed(@() max(max(RadarTargetDist.value, AamLaunchZoneDistMaxVal.value), 1.0) * 1.1)
let curDistMarkPos = Computed(@() (RadarTargetDist.value / maxDistOfLaunchZone.value * 100.0).tointeger())
let maxDistMarkPos = Computed(@() (100.0 - AamLaunchZoneDistMaxVal.value / maxDistOfLaunchZone.value * 100.0).tointeger())
let minDistMarkPos = Computed(@() (100.0 - AamLaunchZoneDistMinVal.value / maxDistOfLaunchZone.value * 100.0).tointeger())
let aamLaunchZone = @(){
  watch = isAAMMode
  size = flex()
  pos = [pw(15), ph(27)]
  flow = FLOW_VERTICAL
  children = isAAMMode.value ? [
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      color = IlsColor.value
      font = Fonts.hud
      fontSize = 45
      text = "MSL"
    }
    @() {
      watch = IsAamLaunchZoneVisible
      size = const [pw(8), ph(3)]
      children = IsAamLaunchZoneVisible.value ? [
        @(){
          watch = curDistMarkPos
          size = [pw(curDistMarkPos.value), baseLineWidth * IlsLineScale.value * 0.5]
          pos = [pw(100.0 - curDistMarkPos.value), ph(40)]
          rendObj = ROBJ_SOLID
          color = IlsColor.value
        }
        @(){
          watch = maxDistMarkPos
          size = [baseLineWidth * IlsLineScale.value * 0.5, ph(40)]
          pos = [pw(maxDistMarkPos.value), 0]
          rendObj = ROBJ_SOLID
          color = IlsColor.value
        }
        @(){
          watch = minDistMarkPos
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          lineWidth = baseLineWidth * IlsLineScale.value * 0.5
          commands = [
            [VECTOR_LINE, minDistMarkPos.value, 0, minDistMarkPos.value, 40],
            [VECTOR_LINE, 0, 0, 100, 0]
          ]
        }
      ] : null
    }
  ] : null
}

let safe = @(){
  rendObj = ROBJ_TEXT
  pos = [pw(75), ph(72)]
  size = SIZE_TO_CONTENT
  color = IlsColor.value
  font = Fonts.hud
  fontSize = 45
  text = "SAFE"
}

function getBulletImpactLineCommand() {
  let commands = []
  for (local i = 0; i < BulletImpactPoints.value.len() - 2; ++i) {
    let point1 = BulletImpactPoints.value[i]
    let point2 = BulletImpactPoints.value[i + 1]
    if (point1.x == -1 && point1.y == -1)
      continue
    if (point2.x == -1 && point2.y == -1)
      continue
    commands.append([VECTOR_LINE, point1.x, point1.y, point2.x, point2.y])
  }
  return commands
}

let bulletsImpactLine = @() {
  watch = [isAAMMode, isCCIPMode, BulletImpactLineEnable]
  size = flex()
  children = BulletImpactLineEnable.value && !isCCIPMode.value && !isAAMMode.value ? [
    @() {
      watch = [BulletImpactPoints, IlsColor]
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = getBulletImpactLineCommand()
    }
  ] : null
}

let generateCompassMark = function(num) {
  return {
    size = const [pw(15), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_TEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 60
        font = Fonts.digital
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        size = [flex(), baseLineWidth * 2 * IlsLineScale.value]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value * 2
        commands = [
          [VECTOR_LINE, 50, 0, 50, 0]
        ]
      }
    ]
  }
}


function compass(width, generateFunc) {
  let children = []
  let step = 5.0

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    let num = (i * step) % 360

    children.append(generateFunc(num))
  }

  let getOffset = @() (360.0 + CompassValue.value) * 0.03 * width
  return {
    size = flex()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [-getOffset() + width * 0.4, 0]
      }
    }
    flow = FLOW_HORIZONTAL
    children = children
  }
}

function compassWrap(width, height, generateFunc) {
  return @(){
    watch = isAAMMode
    size = [width * 0.5, height * 0.1]
    pos = [width * 0.25, height * 0.85]
    clipChildren = true
    children = !isAAMMode.value ? [
      compass(width * 0.5, generateFunc)
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 50, 80, 50, 100]
        ]
      }
    ] : null
  }
}

let timeReleaseSector = Computed(@() cvt(TimeBeforeBombRelease.value, 0.0, 10.0, -90.0, 269.0).tointeger())
let timeToReleaseBar = @() {
  watch = BombingMode
  size = flex()
  children = BombingMode.value ? @(){
    watch = timeReleaseSector
    size = const [pw(6), ph(6)]
    pos = [pw(50), ph(50)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_SECTOR, 0, 0, 100, 100, -90, timeReleaseSector.value]
    ]
  } : null
}

function IlsAmx(width, height) {
  return {
    size = [width, height]
    children = [
      SUMAoa
      SUMVerticalSpeed
      altCircle
      overload
      mach
      speed
      pitch(width, height, generatePitchLine)
      aircraftSymbol
      mode
      gunReticle
      distanceMark
      distanceRate
      aamReticle
      aamLaunchZone
      safe
      bulletsImpactLine
      bombCcipLine
      compassWrap(width, height, generateCompassMark)
      aimLockMark
      timeToReleaseBar
    ]
  }
}

return IlsAmx