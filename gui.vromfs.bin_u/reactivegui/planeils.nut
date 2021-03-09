local {IlsVisible, IlsPosSize, IlsColor, Speed, Altitude, ClimbSpeed, Tangage,
        Roll, CompassValue, BombingMode, TargetPosValid, TargetPos, TimeBeforeBombRelease,
        AimLocked, DistToSafety, Aos, Aoa, DistToTarget, CannonMode, RocketMode, BombCCIPMode,
        BlkFileName, IlsAtgmTrackerVisible, IlsAtgmTargetPos, IlsAtgmLocked, RadarTargetDist} = require("planeState.nut")
local {TrackerVisible, GuidanceLockState} = require("rocketAamAimState.nut")
local {floor, cos, sin, PI} = require("std/math.nut")
local {cvt} = require("dagor.math")
local DataBlock = require("DataBlock")

const mpsToKnots = 1.94384
const metrToFeet = 3.28084
const mpsToFpm = 196.8504
local baseLineWidth = 4 * LINE_WIDTH

enum GuidanceLockResult {
  RESULT_INVALID = -1
  RESULT_STANDBY = 0
  RESULT_WARMING_UP = 1
  RESULT_LOCKING = 2
  RESULT_TRACKING = 3
  RESULT_LOCK_AFTER_LAUNCH = 4
}

local ilsSetting = Computed(function() {
  local res = {
    isASP17 = false
    isAVQ7 = false
    haveAVQ7CCIP = false
    haveAVQ7Bombing = false
    isBuccaneerIls = false
    is410SUM1Ils = false
    isLCOSS = false
  }
  if (BlkFileName.value == "")
    return res
  local blk = DataBlock()
  local fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
  if (!blk.tryLoad(fileName))
    return res
  return {
    isASP17 = blk.getBool("ilsASP17", false)
    isAVQ7 = blk.getBool("ilsAVQ7", false)
    haveAVQ7CCIP = blk.getBool("ilsHaveAVQ7CCIP", false)
    haveAVQ7Bombing = blk.getBool("ilsHaveAVQ7CCRP", false)
    isBuccaneerIls = blk.getBool("isBuccaneerIls", false)
    is410SUM1Ils = blk.getBool("is410SUM1Ils", false)
    isLCOSS = blk.getBool("ilsLCOSS", false)
  }
})

local function speedometer(width, height) {
  local grid = @() {
    watch = IlsColor
    pos = [width * 0.5, height * 0.5]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = baseLineWidth
    color = IlsColor.value
    commands = [
      [VECTOR_LINE, -35, -20, -33, -20],
      [VECTOR_LINE, -35, -16, -35, -16],
      [VECTOR_LINE, -35, -12, -35, -12],
      [VECTOR_LINE, -35, -8, -35, -8],
      [VECTOR_LINE, -35, -4, -35, -4],
      [VECTOR_LINE, -35, 0, -33, 0],
      [VECTOR_LINE, -35, 4, -35, 4],
      [VECTOR_LINE, -35, 8, -35, 8],
      [VECTOR_LINE, -35, 12, -35, 12],
      [VECTOR_LINE, -35, 16, -35, 16],
      [VECTOR_LINE, -35, 20, -33, 20]
    ]
  }

  local hundreds = @() {
    watch = [Speed, IlsColor]
    rendObj = ROBJ_DTEXT
    pos = [width * 0.15, height * 0.72]
    size = flex()
    color = IlsColor.value
    fontSize = 70
    font = Fonts.usa_ils
    text = (floor((Speed.value * mpsToKnots) / 100)).tostring()
  }

  local speedMarkLen = Computed(@() (height * ((Speed.value * mpsToKnots) % 100 / 100) * 0.4).tointeger())
  local speedColumn = @() {
    watch = speedMarkLen
    pos = [width * 0.17, height * 0.7 - speedMarkLen.value]
    size = [baseLineWidth, speedMarkLen.value]
    rendObj = ROBJ_SOLID
    color = IlsColor.value
    lineWidth = baseLineWidth
  }

  return {
    size = [width, height]
    children = [ grid, hundreds, speedColumn ]
  }
}

local altmeterGrid = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = flex()
  lineWidth = baseLineWidth
  color = IlsColor.value
  commands = [
    [VECTOR_LINE, 0, 0, 100, 0],
    [VECTOR_LINE, 40, 10, 40, 10],
    [VECTOR_LINE, 40, 20, 40, 20],
    [VECTOR_LINE, 60, 25, 100, 25],
    [VECTOR_LINE, 40, 30, 40, 30],
    [VECTOR_LINE, 40, 40, 40, 40],
    [VECTOR_LINE, 0, 50, 100, 50],
    [VECTOR_LINE, 40, 60, 40, 60],
    [VECTOR_LINE, 40, 70, 40, 70],
    [VECTOR_LINE, 60, 75, 100, 75],
    [VECTOR_LINE, 40, 80, 40, 80],
    [VECTOR_LINE, 40, 90, 40, 90],
    [VECTOR_LINE, 0, 100, 100, 100]
  ]
}

local altThousand = Computed(@() (floor((Altitude.value * metrToFeet) / 1000)).tointeger())
local thousands = @() {
  watch = [altThousand, IlsColor]
  rendObj = ROBJ_DTEXT
  color = IlsColor.value
  fontSize = 70
  font = Fonts.usa_ils
  text = altThousand.value.tostring()
}

local altMarkLen = Computed(@() ((Altitude.value * metrToFeet) % 1000 / 10).tointeger())
local altColumn = @() {
  watch = altMarkLen
  pos = [0, ph(100 - altMarkLen.value)]
  hplace = ALIGN_RIGHT
  size = [baseLineWidth, ph(altMarkLen.value)]
  rendObj = ROBJ_SOLID
  color = IlsColor.value
  lineWidth = baseLineWidth
}

local climbMarkPos = Computed(@() (clamp(ClimbSpeed.value * mpsToFpm, -999, 999) % 1000 / 10).tointeger())
local climbMark = @() {
  watch = climbMarkPos
  pos = [0, ph(50 - climbMarkPos.value * 0.5)]
  size = [hdpx(30), hdpx(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * 0.5
  commands = [
    [VECTOR_LINE, 100, 50, 100, -50],
    [VECTOR_LINE, 100, 50, 0, 0],
    [VECTOR_LINE, 100, -50, 0, 0]
  ]
}

local function altmeter(width, height) {
  return {
    size = [width * 0.08, height * 0.5]
    pos = [width * 0.8, height * 0.3]
    flow = FLOW_VERTICAL
    children = [
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        children = [altColumn, altmeterGrid, climbMark]
      },
      {
        size = [pw(100), ph(20)]
        flow = FLOW_VERTICAL
        padding = [10, 0]
        children = [
          @() {
            size = flex()
            watch = IlsColor
            rendObj = ROBJ_VECTOR_CANVAS
            lineWidth = baseLineWidth
            color = IlsColor.value
            commands = [
              [VECTOR_LINE, 0, 100, 100, 100],
              [VECTOR_LINE, 100, 100, 100, 50]
            ]
            children = [thousands]
          }
        ]
      }
    ]
  }
}

local function flyDirection(width, height) {
  return @() {
    watch = IlsColor
    size = [width * 0.1, height * 0.1]
    pos = [width * 0.5, height * (BombCCIPMode.value || BombingMode.value ? 0.5 : 0.3)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 20, 20],
      [VECTOR_LINE, -50, 0, -20, 0],
      [VECTOR_LINE, 20, 0, 50, 0],
      [VECTOR_LINE, 0, -20, 0, -40]
    ]
  }
}

local function angleTxt(num, isLeft, textFont, invVPlace = 1) {
  return @() {
    watch = IlsColor
    rendObj = ROBJ_DTEXT
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.value
    fontSize = 60
    font = textFont
    text = num.tostring()
  }
}

local function generatePitchLine(num) {
  local sign = num > 0 ? 1 : -1
  local newNum = num >= 0 ? num : (num - 5)
  return {
    size = [pw(100), ph(100)]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth
        color = IlsColor.value
        padding = [0, 10]
        commands = [
          [VECTOR_LINE, 0, 0, 34, 0],
          [VECTOR_LINE, 66, 0, 100, 0]
        ]
        children = [angleTxt(-5, true, Fonts.usa_ils), angleTxt(-5, false, Fonts.usa_ils)]
      }
    ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth
        color = IlsColor.value
        padding = [10, 10]
        commands = [
          [VECTOR_LINE, 0, 5 * sign, 0, 0],
          [VECTOR_LINE, 0, 0, 7, 0],
          [VECTOR_LINE, 15, 0, 21, 0],
          [VECTOR_LINE, 28, 0, 34, 0],
          [VECTOR_LINE, 100, 5 * sign, 100, 0],
          [VECTOR_LINE, 100, 0, 93, 0],
          [VECTOR_LINE, 85, 0, 79, 0],
          [VECTOR_LINE, 72, 0, 66, 0]
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, Fonts.usa_ils), angleTxt(newNum, false, Fonts.usa_ils)] : null
      }
    ]
  }
}

local function pitch(width, height) {
  const step = 5.0
  local children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    local num = (i * step).tointeger()

    children.append(generatePitchLine(num))
  }

  return {
    size = [width * 0.4, height * 0.5]
    pos = [width * 0.3, height * 0.3]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.1]
        rotate = -Roll.value
        pivot=[0.5, (90.0 - Tangage.value) * 0.2]
      }
    }
  }
}

local generateCompassMark = function(num) {
  return {
    size = [pw(20), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 60
        font = Fonts.usa_ils
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        size = [baseLineWidth, baseLineWidth]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth
        hplace = ALIGN_CENTER
      }
    ]
  }
}

local generateCompassMarkSUM = function(num) {
  return {
    size = [pw(20), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 60
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        size = [baseLineWidth * 2, baseLineWidth * 2]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth
        hplace = ALIGN_CENTER
      }
    ]
  }
}

local function compass(width, generateFunc) {
  const step = 5.0
  local children = []

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    local num = (i * step) % 360

    children.append(generateFunc(num))
  }

  local getOffset = @() (360 + CompassValue.value) * 0.2 * width / 5
  return {
    size = [pw(100), ph(100)]
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

local function compassWrap(width, height, pos, generateFunc) {
  return {
    size = [width * 0.6, height * 0.2]
    pos = [width * 0.2, height * pos]
    clipChildren = true
    children = compass(width * 0.6, generateFunc)
  }
}

local maverickAimMark = @() {
  watch = IlsAtgmLocked
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(2), ph(2)]
  color = IlsColor.value
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, -100, -100, 100, -100],
    [VECTOR_LINE, -100, -100, -100, 100],
    [VECTOR_LINE, 100, 100, -100, 100],
    [VECTOR_LINE, 100, 100, 100, -100],
    (!IlsAtgmLocked.value ? [VECTOR_LINE, 0, 0, 0, 0] : [VECTOR_LINE, -90, -90, 90, 90]),
    (IlsAtgmLocked.value ? [VECTOR_LINE, -90, 90, 90, -90] : [])
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [IlsAtgmTargetPos[0], IlsAtgmTargetPos[1]]
    }
  }
}

local maverickAim = @() {
  watch = IlsAtgmTrackerVisible
  size = flex()
  children = IlsAtgmTrackerVisible.value ? [maverickAimMark] : []
}

local CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)
local aimMark = @() {
  watch = [TargetPosValid, CCIPMode]
  size = flex()
  children = TargetPosValid.value ?
    @() {
      watch = IlsColor
      size = [pw(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_LINE, 0, 0, 0, 0],
        [VECTOR_LINE, 0, 50, 50, 0],
        [VECTOR_LINE, 50, 0, 0, -50],
        [VECTOR_LINE, 0, -50, -50, 0],
        [VECTOR_LINE, -50, 0, 0, 50],
        (CCIPMode.value ? [VECTOR_LINE, -50, -50, 50, -50] : [])
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos[0], TargetPos[1]]
        }
      }
    }
  : null
}

local function basicInformation(width, height) {
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = SIZE_TO_CONTENT
    children = [
      speedometer(width, height),
      altmeter(width, height),
      flyDirection(width, height),
      pitch(width, height),
      aimMark,
      maverickAim
    ]
  }
}

local function bombFallingLine() {
  return @() {
    watch = IlsColor
    size = [baseLineWidth, ph(65)]
    rendObj = ROBJ_SOLID
    color = IlsColor.value
    lineWidth = baseLineWidth
  }
}

local pullupAnticipPos = Computed(@() clamp(0.35 + DistToSafety.value * 0.001, 0.1, 0.5))
local function pullupAnticipation(height) {
  return @() {
    watch = [IlsColor, pullupAnticipPos]
    size = [pw(10), ph(5)]
    pos = [pw(10), height * pullupAnticipPos.value]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    lineWidth = baseLineWidth
    commands = [
      [VECTOR_LINE, -100, 100, 100, 100],
      [VECTOR_LINE, -100, 100, -100, 0],
      [VECTOR_LINE, 100, 100, 100, 0]
    ]
  }
}

local solutionCue = @() {
  watch = IlsColor
  size = [pw(100), baseLineWidth]
  rendObj = ROBJ_SOLID
  color = IlsColor.value
  lineWidth = baseLineWidth
}

local aosOffset = Computed(@() Aos.value.tointeger())
local yawIndicator = @() {
  size = [pw(3), ph(3)]
  pos = [pw(50), ph(80)]
  watch = [IlsColor, aosOffset]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, aosOffset.value * 10, 0, 50, 50],
    [VECTOR_LINE, 0, -100, 0, 100],
  ]
}

local lowerCuePos = Computed(@() clamp(0.4 - TimeBeforeBombRelease.value * 0.05, 0.1, 0.5))
local lowerCueShow = Computed(@() AimLocked.value && TimeBeforeBombRelease.value > 0.0)
local function lowerSolutionCue(height) {
  return @() {
    watch = lowerCueShow
    size = flex()
    children = lowerCueShow.value ?
      @() {
        watch = [IlsColor, lowerCuePos]
        size = [pw(10), baseLineWidth]
        pos = [pw(5), lowerCuePos.value * height - baseLineWidth * 0.5]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth
      }
    : null
  }
}

local cancelBombVisible = Computed(@() DistToSafety.value <= 0.0)
local function cancelBombing() {
  return @() {
    watch = cancelBombVisible
    size = flex()
    children = cancelBombVisible.value ?
      @() {
        watch = IlsColor
        size = [pw(20), ph(20)]
        pos = [pw(50), ph(20)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth
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

local function rotatedBombReleaseReticle(width, height) {
  return {
    size = flex()
    children = [
      pullupAnticipation(height),
      lowerSolutionCue(height),
      {
        size = [pw(20), flex()]
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        children = [solutionCue, bombFallingLine()]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos[0] - width * 0.1, height * 0.1]
        rotate = -Roll.value
        pivot=[0.1, TargetPos[1] / height - 0.1]
      }
    }
  }
}

local function CCIP(width, height) {
  return {
    size = [width, height]
    children = [
      compassWrap(width, height, 0.85, generateCompassMark),
      cancelBombing(),
      yawIndicator
    ]
  }
}

local function bombingMode(width, height) {
  return {
    size = [width, height]
    children = [
      rotatedBombReleaseReticle(width, height),
      compassWrap(width, height, 0.85, generateCompassMark),
      cancelBombing(),
      yawIndicator
    ]
  }
}

local ASP17crosshair = @() {
  watch = IlsColor
  size = [pw(20), ph(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, -10, 0, -60, 0],
    [VECTOR_LINE, 0, -10, 0, -60],
    [VECTOR_LINE, 10, 0, 60, 0],
    [VECTOR_LINE, 0, 10, 0, 60],
  ]
}

local ASP17Roll = @() {
  watch = IlsColor
  size = [pw(20), ph(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth
  fillColor = IlsColor.value
  behavior = Behaviors.RtPropUpdate
  commands = [
    [VECTOR_POLY, -2, -70, 0, -77, 2, -70]
  ]
  update = @() {
    transform = {
      rotate = clamp(Roll.value, -30, 30).tointeger()
      pivot = [0, 0]
    }
  }
}

local DistToTargetWatch = Computed(@() cvt(DistToTarget.value, 450, 3000, -90, 15).tointeger())
local ASP17Distances = @() {
  watch = [IlsColor, DistToTargetWatch]
  size = [pw(20), ph(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth
  fillColor = Color(0, 0, 0)
  commands = [
    [VECTOR_SECTOR, 0, 0, 93, 93, -80, max(-80, min(DistToTargetWatch.value, -3))],
    [VECTOR_SECTOR, 0, 0, 90, 90, -90, DistToTargetWatch.value],
    [VECTOR_WIDTH, baseLineWidth * 1.5],
    [VECTOR_LINE, 0, -90, 0, -82], //0
    (DistToTargetWatch.value > -30 ? [VECTOR_LINE, 78, -45, 71, -41] : []),  //60
    (DistToTargetWatch.value > -60 ? [VECTOR_LINE, 45, -78, 41, -71] : []), //30
    (DistToTargetWatch.value > 0 ? [VECTOR_LINE, 82, 0, 90, 0] : []), //90
    [VECTOR_WIDTH, baseLineWidth],
    (DistToTargetWatch.value >= 15 ? [VECTOR_LINE, 82.1, 22, 86.9, 23.3] : []),  //105
    (DistToTargetWatch.value > -15 ? [VECTOR_LINE, 82.1, -22, 86.9, -23.3] : []),  //75
    (DistToTargetWatch.value > -37.5 ? [VECTOR_LINE, 67.4, -51.7, 71.4, -54.8] : []),  //52,5
    (DistToTargetWatch.value > -45 ? [VECTOR_LINE, 60.1, -60.1, 63.6, -63.6] : []),  //45
    (DistToTargetWatch.value > -52.5 ? [VECTOR_LINE, 51.7, -67.4, 54.8, -71.4] : []),  //37.5
    (DistToTargetWatch.value > -67.5 ? [VECTOR_LINE, 32.5, -78.5, 34.4, -83.2] : []),  //22.5
    (DistToTargetWatch.value > -75 ? [VECTOR_LINE, 22, -82.1, 23.3, -86.9] : []),  //15
    (DistToTargetWatch.value > -82.5 ? [VECTOR_LINE, 11, -84.3, 11.7, -89.2] : [])  //7.5
  ]
}

local function ASP17(width, height) {
  return {
    size = [width, height]
    children = [
      ASP17Distances,
      ASP17crosshair,
      ASP17Roll
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TargetPosValid.value ? [TargetPos[0] - width * 0.5, TargetPos[1] - height * 0.5] : [0, 0]
      }
    }
  }
}

local buccaneerSpdVal = Computed(@() cvt(Speed.value * mpsToKnots, 300, 600, 0, 100).tointeger())
local buccaneerSpeed = @() {
  watch = buccaneerSpdVal
  size = [pw(20), ph(5)]
  pos = [pw(40), ph(85)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * 1.5
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 33, 0, 33, 0],
    [VECTOR_LINE, 66, 0, 66, 0],
    [VECTOR_LINE, 100, 0, 100, 0],
    [VECTOR_LINE, buccaneerSpdVal.value, 50, buccaneerSpdVal.value, 100]
  ]
}

local DistToTargetBuc = Computed(@() cvt(TimeBeforeBombRelease.value, 0, 10.0, -90, 250).tointeger())
local BucDistMarkVis = Computed(@() TargetPosValid.value && BombingMode.value)
local buccaneerCCRP = @() {
  watch = [BucDistMarkVis, DistToTargetBuc]
  size = [pw(20), pw(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * 1.5
  commands = BucDistMarkVis.value ? [
    [VECTOR_SECTOR, 0, 0, 80, 80, -90, DistToTargetBuc.value],
    [VECTOR_SECTOR, 0, 0, 30, 30, 50, 130],
    (TimeBeforeBombRelease.value < 3.0 ? [VECTOR_SECTOR, 0, 0, 30, 30, -130, -50] : [])
  ] : []
}

local function buccaneerAimMark(width, height) {
  return {
    size = flex()
    children = [
      {
        size = [pw(20), ph(20)]
        pos = [pw(50), ph(50)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * 1.5
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 15, 15],
          [VECTOR_LINE, -35, 0, -15, 0],
          [VECTOR_LINE, 15, 0, 35, 0],
          [VECTOR_LINE, 0, 80, 0, 90],
          [VECTOR_LINE, 0, -80, 0, -90],
          [VECTOR_LINE, -80, 0, -90, 0],
          [VECTOR_LINE, 80, 0, 90, 0]
        ]
      },
      {
        size = [pw(30), ph(30)]
        pos = [pw(50), ph(50)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * 1.5
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_LINE, -100, 0, -80, 0],
          [VECTOR_LINE, 100, 0, 80, 0]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            rotate = -Roll.value
            pivot = [0, 0]
          }
        }
      },
      buccaneerCCRP,
      {
        size = [ph(1.2), ph(1.2)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = IlsColor.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.value ? [TargetPos[0], TargetPos[1]] : [-10, -10]
          }
        }
      }
    ]
  }
}

local function buccaneerHUD(width, height) {
  return {
    size = [width, height]
    children = [
      buccaneerAimMark(width, height),
      buccaneerSpeed
    ]
  }
}

local SUMAoaMarkH = Computed(@() cvt(Aoa.value, -5, 20, 100, 0).tointeger())
local SUMAoa = @() {
  watch = SUMAoaMarkH
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(40)]
  pos = [pw(15), ph(30)]
  color = IlsColor.value
  lineWidth = baseLineWidth * 3
  commands = [
    [VECTOR_LINE, 0, 16, 0, 16],
    [VECTOR_LINE, 0, 32, 0, 32],
    [VECTOR_LINE, 0, 48, 0, 48],
    [VECTOR_LINE, 0, 100, 0, 100],
    [VECTOR_WIDTH, baseLineWidth],
    [VECTOR_LINE, 0, 80, 100, 80],
    [VECTOR_LINE, 5, SUMAoaMarkH.value, 100, SUMAoaMarkH.value - 5],
    [VECTOR_LINE, 5, SUMAoaMarkH.value, 100, SUMAoaMarkH.value + 5],
    (SUMAoaMarkH.value < 76 || SUMAoaMarkH.value > 84 ? [VECTOR_LINE, 80, 80, 80, SUMAoaMarkH.value + (Aoa.value > 0 ? 4 : -4)] : [])
  ]
}

local SUMVSMarkH = Computed(@() cvt(ClimbSpeed.value * mpsToFpm, 1000, -2000, 0, 100).tointeger())
local SUMVerticalSpeed = @() {
  watch = SUMVSMarkH
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(40)]
  pos = [pw(85), ph(30)]
  color = IlsColor.value
  lineWidth = baseLineWidth * 3
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 0, 16, 0, 16],
    [VECTOR_LINE, 0, 52, 0, 52],
    [VECTOR_LINE, 0, 68, 0, 68],
    [VECTOR_LINE, 0, 84, 0, 84],
    [VECTOR_LINE, 0, 100, 0, 100],
    [VECTOR_WIDTH, baseLineWidth],
    [VECTOR_LINE, 0, 34, 100, 34],
    [VECTOR_LINE, 5, SUMVSMarkH.value, 100, SUMVSMarkH.value - 5],
    [VECTOR_LINE, 5, SUMVSMarkH.value, 100, SUMVSMarkH.value + 5],
    (SUMVSMarkH.value < 30 || SUMVSMarkH.value > 38 ? [VECTOR_LINE, 80, 34, 80, SUMVSMarkH.value + (ClimbSpeed.value > 0.0 ? 4 : -4)] : [])
  ]
}

local flyDirectionSUM = @() {
  watch = IlsColor
  size = [pw(10), ph(10)]
  pos = [pw(50), ph(40)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 20, 20],
    [VECTOR_LINE, -50, 0, -20, 0],
    [VECTOR_LINE, 20, 0, 50, 0]
  ]
}

local SUMAltValue = Computed(@() clamp(Altitude.value * metrToFeet, 0, 4995).tointeger())
local SUNAltThousands = Computed(@() SUMAltValue.value > 1000 ? $"{SUMAltValue.value / 1000}" : "")
local SUMAltVis = Computed(@() Altitude.value * metrToFeet < 4995)
local SUMAltitude = @() {
  watch = SUMAltVis
  size = flex()
  pos = [pw(60), ph(25)]
  children = SUMAltVis.value ? [
    @() {
      watch = SUMAltValue
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_DTEXT
      color = IlsColor.value
      fontSize = 60
      font = Fonts.hud
      text = string.format("R%s.%03d", SUNAltThousands.value, SUMAltValue.value % 1000)
    }
  ] : null
}

local SUMSpeedValue = Computed(@() (Speed.value * mpsToKnots).tointeger())
local SUMSpeed = @() {
  watch = SUMSpeedValue
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_DTEXT
  pos = [pw(27), ph(25)]
  color = IlsColor.value
  fontSize = 60
  font = Fonts.hud
  text = $"{SUMSpeedValue.value}T"
}

local function generatePitchLineSum(num) {
  local sign = num > 0 ? 1 : -1
  local newNum = num < 0 ? (num / -10) : ((num - 30) / 10)
  return {
    size = [pw(100), ph(100)]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth
        color = IlsColor.value
        padding = [0, 10]
        commands = [
          [VECTOR_LINE, 0, 0, 35, 0],
          [VECTOR_LINE, 35, 0, 35, 5],
          [VECTOR_LINE, 65, 0, 100, 0],
          [VECTOR_LINE, 65, 0, 65, 5]
        ]
      }
    ] : (num == 90 || num == -90 ? [
        @() {
          size = flex()
          watch = IlsColor
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = baseLineWidth
          color = IlsColor.value
          commands = [
            [VECTOR_LINE, 50, sign > 0 ? 0 : 100, 50, sign > 0 ? 30 : 70],
            [VECTOR_LINE, 35, sign > 0 ? 10 : 92, 65, sign > 0 ? 10 : 92],
            (sign < 0 ? [VECTOR_LINE, 40, 85, 60, 85] : [])
          ]
          children = num == 90 ? [angleTxt(6, true, Fonts.hud, -1), angleTxt(6, false, Fonts.hud, -1)] : []
        }
      ] :
      [
        @() {
          size = flex()
          watch = IlsColor
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = baseLineWidth
          color = IlsColor.value
          padding = [10, 10]
          commands = sign > 0 ? [
            [VECTOR_LINE, 0, 0, 5, 0],
            [VECTOR_LINE, 10, 0, 15, 0],
            [VECTOR_LINE, 20, 0, 25, 0],
            [VECTOR_LINE, 30, 0, 35, 0],
            [VECTOR_LINE, 35, 0, 35, 5],
            [VECTOR_LINE, 100, 0, 95, 0],
            [VECTOR_LINE, 90, 0, 85, 0],
            [VECTOR_LINE, 80, 0, 75, 0],
            [VECTOR_LINE, 70, 0, 65, 0],
            [VECTOR_LINE, 65, 0, 65, 5]
          ] : [
            [VECTOR_LINE, 0, 0, 12, 0],
            [VECTOR_LINE, 22, 0, 35, 0],
            [VECTOR_LINE, 35, 0, 35, 5],
            [VECTOR_LINE, 100, 0, 88, 0],
            [VECTOR_LINE, 78, 0, 65, 0],
            [VECTOR_LINE, 65, 0, 65, 5]
          ]
          children = newNum != 0 ? [angleTxt(newNum, true, Fonts.hud, -sign), angleTxt(newNum, false, Fonts.hud, -sign)] : null
        }
    ])
  }
}

local function pitchSum(height) {
  const step = 30.0
  local children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    local num = (i * step).tointeger()

    children.append(generatePitchLineSum(num))
  }

  return {
    size = [pw(40), ph(50)]
    pos = [pw(30), ph(40)]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.016666667]
        rotate = -Roll.value
        pivot=[0.5, (90.0 - Tangage.value) * 0.0333333]
      }
    }
  }
}

local function basic410SUM(width, height) {
  return @() {
    watch = CCIPMode
    size = [width, height]
    children = [
      SUMAoa,
      compassWrap(width, height, 0.85, generateCompassMarkSUM),
      pitchSum(height),
      (!CCIPMode.value ? flyDirectionSUM : null),
      SUMVerticalSpeed,
      SUMAltitude,
      SUMSpeed,
      yawIndicator
    ]
  }
}

local function SUMGunReticle(width, height) {
  return {
    size = [width * 0.1, height * 0.1]
    color = IlsColor.value
    lineWidth = baseLineWidth
    rendObj = ROBJ_VECTOR_CANVAS
    commands = [
      [VECTOR_LINE, 0, 0, 0, 0],
      [VECTOR_LINE, 0, -70, 0, -100],
      [VECTOR_LINE, 0, 70, 0, 100],
      [VECTOR_LINE, 70, 0, 100, 0],
      [VECTOR_LINE, -100, 0, -70, 0],
      [VECTOR_LINE, 35, 60.6, 50, 86.6],
      [VECTOR_LINE, 60.6, 35, 86.6, 50],
      [VECTOR_LINE, -35, -60.6, -50, -86.6],
      [VECTOR_LINE, -60.6, -35, -86.6, -50],
      [VECTOR_LINE, -35, 60.6, -50, 86.6],
      [VECTOR_LINE, -60.6, 35, -86.6, 50],
      [VECTOR_LINE, 35, -60.6, 50, -86.6],
      [VECTOR_LINE, 60.6, -35, 86.6, -50],
    ]
    behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos[0], TargetPos[1]]
        }
      }
  }
}

local SUMCCIPReticle = @() {
  watch = IlsColor
  size = [pw(10), ph(10)]
  color = IlsColor.value
  lineWidth = baseLineWidth
  rendObj = ROBJ_VECTOR_CANVAS
  fillColor = Color(0,0,0,0)
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 20, 20],
    [VECTOR_LINE, -50, 0, -20, 0],
    [VECTOR_LINE, 20, 0, 50, 0],
    [VECTOR_LINE, 10, 17.3, 25, 43.3],
    [VECTOR_LINE, -10, 17.3, -25, 43.3]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [TargetPos[0], TargetPos[1]]
    }
  }
}

local function SUMCCIPMode(width, height) {
  return @() {
    watch = TargetPosValid
    size = [width, height]
    children = [
      (TargetPosValid.value ? SUMCCIPReticle : null),
      @() {
        watch = BombCCIPMode
        size = [pw(3), ph(3)]
        pos = [pw(50), ph(BombCCIPMode.value ? 50 : 30)]
        color = IlsColor.value
        lineWidth = baseLineWidth
        rendObj = ROBJ_VECTOR_CANVAS
        commands = [
          [VECTOR_LINE, -100, 0, 100, 0],
          [VECTOR_LINE, 0, -100, 0, 100],
        ]
      }
    ]
  }
}

local function SumAAMCrosshair(position, anim) {
  return {
    size = [pw(2), ph(2)]
    pos = position
    color = IlsColor.value
    lineWidth = baseLineWidth
    rendObj = ROBJ_VECTOR_CANVAS
    commands = [
      [VECTOR_LINE, -100, -100, -50, -50],
      [VECTOR_LINE, 100, 100, 50, 50],
      [VECTOR_LINE, -100, 100, -50, 50],
      [VECTOR_LINE, 50, -50, 100, -100]
    ]
    transform = {}
    animations = [
      { prop=AnimProp.rotate, from = 0, to = 360, duration = 2.5, play = anim, loop = true}
    ]
  }
}

local function SumAAMMode(width, height) {
  return @() {
    watch = GuidanceLockState
    size = [width, height]
    children = [
      SumAAMCrosshair([width * 0.5, height * 0.5], false),
      (GuidanceLockState.value != GuidanceLockResult.RESULT_TRACKING ?
      {
        size = flex()
        children = [SumAAMCrosshair([width * 0.5, height * 0.25], true)]
        transform = {}
        animations = [
          { prop=AnimProp.rotate, from = 360, to = 0, duration = 2.5, play = true, loop = true}
        ]
      }
      : null)
    ]
  }
}

local function SUMCcrpTarget(width, height) {
  return @() {
    watch = AimLocked
    size = flex()
    children = AimLocked.value ?
      @() {
        watch = IlsColor
        size = [pw(10), baseLineWidth]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_LINE, 0, 0, 40, 0],
          [VECTOR_LINE, 60, 0, 100, 0]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [width * 0.05, TargetPos[1] - height * 0.4]
          }
        }
      }
    : null
  }
}

local function rotatedBombReleaseSUM(width, height) {
  return @() {
    watch = TargetPosValid
    size = flex()
    children = TargetPosValid.value ? [
      SUMCcrpTarget(width, height),
      {
        size = [pw(20), flex()]
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        children = [bombFallingLine()]
      }
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos[0] - width * 0.1, height * 0.4]
        rotate = -Roll.value
        pivot=[0.1, TargetPos[1] / height - 0.4]
      }
    }
  }
}

local cancelBombingSUM = @() {
  watch = cancelBombVisible
  size = flex()
  children = cancelBombVisible.value ?
    @() {
      watch = IlsColor
      size = [pw(7), ph(7)]
      pos = [pw(50), ph(30)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_LINE, -40, -50, 40, 50],
        [VECTOR_LINE, -40, 50, 40, -50]
      ]
    }
  : null
}

local releaseMarkSector = Computed (@() cvt(TimeBeforeBombRelease.value, 10.0, 0, 260, -90).tointeger())
local timeToRelease = @() {
  watch = releaseMarkSector
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(8), ph(8)]
  pos = [pw(50), ph(30)]
  color = IlsColor.value
  fillColor = Color(0,0,0,0)
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_SECTOR, 0, 0, 80, 80, -90, releaseMarkSector.value],
    [VECTOR_LINE, 0, -80, 0, -100]
  ]
}

local function SumBombingSight(width, height) {
  return {
    size = [width, height]
    children = [
      rotatedBombReleaseSUM(width, height),
      timeToRelease,
      cancelBombingSUM
    ]
  }
}

local LCOSSRollMark = @() {
  watch = IlsColor
  size = flex()
  children = [
    {
      pos = [pw(46), pw(27)]
      size = [baseLineWidth * 4, baseLineWidth * 4]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
    },
    {
      pos = [pw(51), pw(27)]
      size = [baseLineWidth * 4, baseLineWidth * 4]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
    },
    {
      pos = [pw(26), pw(48.5)]
      size = [baseLineWidth * 4, baseLineWidth * 4]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
    },
    {
      pos = [pw(71), pw(49)]
      size = [baseLineWidth * 4, baseLineWidth * 4]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
    }
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      rotate = -Roll.value
    }
  }
}

local LCOSSCrosshair = @() {
  watch = IlsColor
  size = [pw(20), ph(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 90, 90],
    [VECTOR_SECTOR, 0, 0, 50, 50, -125, -55],
    [VECTOR_SECTOR, 0, 0, 50, 50, -35, 35],
    [VECTOR_SECTOR, 0, 0, 50, 50, 55, 125],
    [VECTOR_SECTOR, 0, 0, 50, 50, 145, 215],
    [VECTOR_WIDTH, baseLineWidth * 3],
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 92, 0, 97, 0],
    [VECTOR_LINE, -92, 0, -97, 0],
    [VECTOR_LINE, 0, -92, -0, -97]
  ]
}

local RadarDistAngle = Computed(@() PI * (BombingMode.value ? cvt(TimeBeforeBombRelease.value, 10.0, 0, -88, 90) :
  cvt(RadarTargetDist.value, 91.44, 1727.302, 90, -88)) / 180)
local LCOSSRadarRangeMark = @() {
  watch = [RadarDistAngle, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(17), ph(17)]
  pos = [pw(50), ph(50)]
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * 3
  commands = [
    [VECTOR_SECTOR, 0, 0, 100, 100, RadarDistAngle.value * 180 / PI, 90],
    [VECTOR_LINE, 80 * cos(RadarDistAngle.value), 80 * sin(RadarDistAngle.value), 100 * cos(RadarDistAngle.value), 100 * sin(RadarDistAngle.value)]
  ]
}

local LCOSSRadarRangeVis =  Computed(@() RadarTargetDist.value > 0.0 || BombingMode.value)
local LCOSSRadarRange = @() {
  watch = LCOSSRadarRangeVis
  size = flex()
  children = LCOSSRadarRangeVis.value ? [LCOSSRadarRangeMark] : null
}

local function LCOSS(width, height) {
  return @() {
    watch = TargetPosValid
    size = [width, height]
    children = TargetPosValid.value ? [
      LCOSSCrosshair,
      LCOSSRollMark,
      LCOSSRadarRange
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = BombingMode.value ? [0, 0] : [TargetPos[0] - width * 0.5, TargetPos[1] - height * 0.5]
      }
    }
  }
}

local function planeIls(width, height) {
  return @() {
    watch = [BombingMode, CCIPMode, TrackerVisible]
    children = [
      (ilsSetting.value.isAVQ7 ? basicInformation(width, height) : null),
      (ilsSetting.value.haveAVQ7Bombing && BombingMode.value ? bombingMode(width, height) : null),
      (ilsSetting.value.haveAVQ7CCIP && CCIPMode.value ? CCIP(width, height) : null),
      (ilsSetting.value.isAVQ7 && (!BombingMode.value || !ilsSetting.value.haveAVQ7Bombing) &&
       (!CCIPMode.value || !ilsSetting.value.haveAVQ7CCIP) ? compassWrap(width, height, 0.1, generateCompassMark) : null),
      (ilsSetting.value.isASP17 ? ASP17(width, height) : null),
      (ilsSetting.value.isBuccaneerIls ? buccaneerHUD(width, height) : null),
      (ilsSetting.value.is410SUM1Ils ? basic410SUM(width, height) : null),
      (ilsSetting.value.is410SUM1Ils && CCIPMode.value ? SUMCCIPMode(width, height) : null),
      (ilsSetting.value.is410SUM1Ils && TrackerVisible.value ? SumAAMMode(width, height) : null),
      (ilsSetting.value.is410SUM1Ils && BombingMode.value ? SumBombingSight(width, height) : null),
      (ilsSetting.value.is410SUM1Ils && !BombingMode.value && !CCIPMode.value ? SUMGunReticle(width, height) : null),
      (ilsSetting.value.isLCOSS ? LCOSS(width, height) : null)
    ]
  }
}

local planeIlsSwitcher = @() {
  watch = IlsVisible
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = SIZE_TO_CONTENT
  children = IlsVisible.value ? [ planeIls(IlsPosSize[2], IlsPosSize[3])] : null
}

local function Root() {
  return {
    watch = ilsSetting
    children = planeIlsSwitcher
  }
}

return Root