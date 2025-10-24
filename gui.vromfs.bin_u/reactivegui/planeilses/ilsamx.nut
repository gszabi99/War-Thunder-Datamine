from "%rGui/globals/ui_library.nut" import *
let { Aoa, ClimbSpeed, Altitude, Speed, Tangage, Roll, Overload,
 Mach, CompassValue } = require("%rGui/planeState/planeFlyState.nut")
let { cvt } = require("dagor.math")
let { IlsColor, IlsLineScale, TargetPos, RocketMode, CannonMode, BombCCIPMode, BombingMode,
  TargetPosValid, DistToTarget, RadarTargetDist, RadarTargetDistRate, IlsPosSize,
  AimLockPos, AimLockValid, TimeBeforeBombRelease } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToFpm, metrToFeet, mpsToKnots } = require("%rGui/planeIlses/ilsConstants.nut")
let string = require("string")
let { GuidanceLockResult } = require("guidanceConstants")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { AamLaunchZoneDistMaxVal, AamLaunchZoneDistMinVal, IsAamLaunchZoneVisible } = require("%rGui/radarState.nut")
let { BulletImpactPoints, BulletImpactLineEnable } = require("%rGui/planeState/planeWeaponState.nut")

let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)
let isCCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())
let SUMAoaMarkH = Computed(@() cvt(Aoa.get(), 0, 25, 100, 0).tointeger())
let SUMAoa = @() {
  watch = [SUMAoaMarkH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(3), ph(30)]
  pos = [pw(15), ph(35)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * 2 * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 100, 0, 100, 0],
    [VECTOR_LINE, 160, 20, 160, 20],
    [VECTOR_LINE, 100, 20, 100, 20],
    [VECTOR_LINE, 100, 40, 100, 40],
    [VECTOR_LINE, 160, 60, 160, 60],
    [VECTOR_LINE, 100, 60, 100, 60],
    [VECTOR_LINE, 100, 80, 100, 80],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get()],
    [VECTOR_LINE, 95, SUMAoaMarkH.get(), 0, SUMAoaMarkH.get() - 5],
    [VECTOR_LINE, 95, SUMAoaMarkH.get(), 0, SUMAoaMarkH.get() + 5],
    (SUMAoaMarkH.get() < 96 ? [VECTOR_LINE, 20, 100, 20, SUMAoaMarkH.get() + (Aoa.get() > 0 ? 4 : -4)] : []),
    [VECTOR_LINE, 20, 100, 80, 100],
  ]
}

let SUMVSMarkH = Computed(@() cvt(ClimbSpeed.get() * mpsToFpm, 1000, -2000, 0, 100).tointeger())
let SUMVerticalSpeed = @() {
  watch = [SUMVSMarkH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(3), ph(30)]
  pos = [pw(78), ph(35)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * 2 * IlsLineScale.get()
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
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get()],
    [VECTOR_LINE, 0, 34, 100, 34],
    [VECTOR_LINE, 5, SUMVSMarkH.get(), 100, SUMVSMarkH.get() - 5],
    [VECTOR_LINE, 5, SUMVSMarkH.get(), 100, SUMVSMarkH.get() + 5],
    (SUMVSMarkH.get() < 30 || SUMVSMarkH.get() > 38 ? [VECTOR_LINE, 80, 34, 80, SUMVSMarkH.get() + (ClimbSpeed.get() > 0.0 ? 4 : -4)] : [])
  ]
}

let altValue = Computed(@() (Altitude.get() * metrToFeet).tointeger())
let altThousands = Computed(@() altValue.get() > 1000 ? $"{altValue.get() / 1000}" : "")
let AltitudeMark = {
  size = flex()
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 45
      font = Fonts.mirage_ils
      text = "R"
    }
    @() {
      watch = [altValue, IlsColor]
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      fontSize = 45
      font = Fonts.digital
      text = string.format("%s.%03d", altThousands.get(), altValue.get() % 1000)
    }
  ]
}

let AltThousandAngle = Computed(@() (Altitude.get() * metrToFeet % 1000 / 2.7777 - 90.0).tointeger())
let altCircle = @() {
  size = pw(16)
  pos = [pw(70), ph(15)]
  children = @() {
    watch = IlsColor
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get() * 2
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
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_LINE, 90, 0, 60, 15],
          [VECTOR_LINE, 90, 0, 60, -15]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            rotate = AltThousandAngle.get()
            pivot = [0, 0]
          }
        }
      }
      AltitudeMark
    ]
  }
}

let overloadValue = Computed(@() (Overload.get() * 10.0).tointeger())
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
      color = IlsColor.get()
      font = Fonts.digital
      fontSize = 45
      halign = ALIGN_CENTER
      text = (overloadValue.get() / 10.0).tostring()
    }
    {
      rendObj = ROBJ_TEXT
      size = flex()
      color = IlsColor.get()
      font = Fonts.hud
      fontSize = 45
      halign = ALIGN_CENTER
      text = "G"
    }
  ]
}

let machValue = Computed(@() (Mach.get() * 100.0).tointeger())
let mach = @(){
  watch = machValue
  size = const [pw(8), ph(5)]
  pos = [pw(10), ph(16)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  halign = ALIGN_CENTER
  font = Fonts.digital
  fontSize = 45
  text = string.format("%.2f", machValue.get() / 100.0)
}

let speedValue = Computed(@() (Speed.get() * mpsToKnots).tointeger())
let speed = @(){
  watch = speedValue
  size = const [pw(8), ph(5)]
  pos = [pw(10), ph(20)]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  halign = ALIGN_CENTER
  font = Fonts.digital
  fontSize = 45
  text = speedValue.get().tostring()
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
        translate = [0, -height * (90.0 - Tangage.get()) * 0.06]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get()) * 0.12]
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
    color = IlsColor.get()
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
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
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
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
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
  children = isCCIPMode.get() || BombingMode.get() ? @() {
    size = const [pw(5), ph(5)]
    pos = [pw(50), ph(50)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get()
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
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 45
  text = RocketMode.get() ? "RKT" : CannonMode.get() ? "GUN" : BombCCIPMode.get() ? "CCIP" : BombingMode.get() ? "CCRP" : "A/A"
}

let hasRadarTarget = Computed(@() RadarTargetDist.get() > 0.0)
let distanceSector = Computed(@() cvt((isCCIPMode.get() ? DistToTarget.get() : RadarTargetDist.get()), 0.0, 3000.0, 179.0, -179.0).tointeger())
let gunReticle = @(){
  watch = [BombingMode, TargetPosValid]
  size = flex()
  children = !BombingMode.get() && TargetPosValid.get() ? [
    {
      size = ph(3)
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.7
      fillColor = Color(0, 0, 0, 0)
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100],
        [VECTOR_LINE, 0, 0, 0, 0]
      ]
    }
    @() {
      watch = [isCCIPMode, hasRadarTarget]
      size = flex()
      children = isCCIPMode.get() || hasRadarTarget.get() ? @(){
        watch = distanceSector
        rendObj = ROBJ_VECTOR_CANVAS
        size = ph(4)
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.7
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_SECTOR, 0, 0, 100, 100, distanceSector.get(), 180],
          [VECTOR_LINE, -97, 25, -72.4, 19.4],
          [VECTOR_LINE, 97, 25, 72.4, 19.4]
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

let bombCcipLine = @(){
  watch = [BombCCIPMode, BombingMode, TargetPosValid]
  size = flex()
  children = BombCCIPMode.get() || (BombingMode.get() && TargetPosValid.get()) ? {
    size = [baseLineWidth * IlsLineScale.get(), ph(200)]
    rendObj = ROBJ_SOLID
    color = IlsColor.get()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.get()[0], TargetPos.get()[1] - IlsPosSize[3] * 2.0]
      }
    }
  } : null
}

let distanceTextVal = Computed(@() (isCCIPMode.get() && TargetPosValid.get() ? DistToTarget.get() : RadarTargetDist.get()).tointeger())
let distanceMark = {
  size = flex()
  pos = [pw(10), ph(70)]
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      font = Fonts.hud
      fontSize = 45
      text="M"
    }
    @(){
      watch = distanceTextVal
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      font = distanceTextVal.get() >= 0.0 ? Fonts.digital : Fonts.tiny_text
      fontSize = 45
      text = distanceTextVal.get() >= 0.0 ? distanceTextVal.get().tostring() : "......."
    }
  ]
}

let distanceRateValue = Computed(@() (RadarTargetDistRate.get() * -mpsToKnots).tointeger())
let distanceRate = @(){
  watch = hasRadarTarget
  size = flex()
  pos = [pw(10), ph(74)]
  flow = FLOW_HORIZONTAL
  children = hasRadarTarget.get() ? [
    @(){
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      font = Fonts.hud
      fontSize = 45
      text="RR"
    }
    @(){
      watch = distanceRateValue
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.get()
      font = Fonts.digital
      fontSize = 45
      text = distanceRateValue.get().tostring()
    }
  ] : null
}

let aamReticle = @(){
  watch = [isAAMMode, IlsTrackerVisible]
  size = flex()
  children = isAAMMode.get() && IlsTrackerVisible.get() ? @(){
    watch = GuidanceLockState
    size = const [pw(3), ph(3)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get() * 0.7
    commands = GuidanceLockState.get() == GuidanceLockResult.RESULT_TRACKING ? [
      [VECTOR_POLY, 0, -100, 100, 0, 0, 100, -100, 0],
      [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get()],
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
        translate = [IlsTrackerX.get(), IlsTrackerY.get()]
      }
    }
  } : null
}

let aimLockMark = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.get() ? @() {
    size = const [pw(4), ph(4)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
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

let maxDistOfLaunchZone = Computed(@() max(max(RadarTargetDist.get(), AamLaunchZoneDistMaxVal.get()), 1.0) * 1.1)
let curDistMarkPos = Computed(@() (RadarTargetDist.get() / maxDistOfLaunchZone.get() * 100.0).tointeger())
let maxDistMarkPos = Computed(@() (100.0 - AamLaunchZoneDistMaxVal.get() / maxDistOfLaunchZone.get() * 100.0).tointeger())
let minDistMarkPos = Computed(@() (100.0 - AamLaunchZoneDistMinVal.get() / maxDistOfLaunchZone.get() * 100.0).tointeger())
let aamLaunchZone = @(){
  watch = isAAMMode
  size = flex()
  pos = [pw(15), ph(27)]
  flow = FLOW_VERTICAL
  children = isAAMMode.get() ? [
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      color = IlsColor.get()
      font = Fonts.hud
      fontSize = 45
      text = "MSL"
    }
    @() {
      watch = IsAamLaunchZoneVisible
      size = const [pw(8), ph(3)]
      children = IsAamLaunchZoneVisible.get() ? [
        @(){
          watch = curDistMarkPos
          size = [pw(curDistMarkPos.get()), baseLineWidth * IlsLineScale.get() * 0.5]
          pos = [pw(100.0 - curDistMarkPos.get()), ph(40)]
          rendObj = ROBJ_SOLID
          color = IlsColor.get()
        }
        @(){
          watch = maxDistMarkPos
          size = [baseLineWidth * IlsLineScale.get() * 0.5, ph(40)]
          pos = [pw(maxDistMarkPos.get()), 0]
          rendObj = ROBJ_SOLID
          color = IlsColor.get()
        }
        @(){
          watch = minDistMarkPos
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.get()
          lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
          commands = [
            [VECTOR_LINE, minDistMarkPos.get(), 0, minDistMarkPos.get(), 40],
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
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 45
  text = "SAFE"
}

function getBulletImpactLineCommand() {
  let commands = []
  for (local i = 0; i < BulletImpactPoints.get().len() - 2; ++i) {
    let point1 = BulletImpactPoints.get()[i]
    let point2 = BulletImpactPoints.get()[i + 1]
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
  children = BulletImpactLineEnable.get() && !isCCIPMode.get() && !isAAMMode.get() ? [
    @() {
      watch = [BulletImpactPoints, IlsColor]
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
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
        color = IlsColor.get()
        hplace = ALIGN_CENTER
        fontSize = 60
        font = Fonts.digital
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        size = [flex(), baseLineWidth * 2 * IlsLineScale.get()]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 2
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

  let getOffset = @() (360.0 + CompassValue.get()) * 0.03 * width
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
    children = !isAAMMode.get() ? [
      compass(width * 0.5, generateFunc)
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get()
        commands = [
          [VECTOR_LINE, 50, 80, 50, 100]
        ]
      }
    ] : null
  }
}

let timeReleaseSector = Computed(@() cvt(TimeBeforeBombRelease.get(), 0.0, 10.0, -90.0, 269.0).tointeger())
let timeToReleaseBar = @() {
  watch = BombingMode
  size = flex()
  children = BombingMode.get() ? @(){
    watch = timeReleaseSector
    size = const [pw(6), ph(6)]
    pos = [pw(50), ph(50)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_SECTOR, 0, 0, 100, 100, -90, timeReleaseSector.get()]
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