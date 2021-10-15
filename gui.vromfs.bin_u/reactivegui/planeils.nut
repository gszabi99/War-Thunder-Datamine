local {IlsVisible, IlsPosSize, IlsColor, Speed, Altitude, ClimbSpeed, Tangage, Mach,
        Roll, CompassValue, BombingMode, TargetPosValid, TargetPos, TimeBeforeBombRelease,
        AimLocked, DistToSafety, Aos, Aoa, DistToTarget, CannonMode, RocketMode, BombCCIPMode,
        BlkFileName, IlsAtgmTrackerVisible, IlsAtgmTargetPos, IlsAtgmLocked, RadarTargetDist,
        RadarTargetPosValid, RadarTargetPos, AamAccelLock, BarAltitude, Overload,
        IlsLineScale, ShellCnt} = require("planeState.nut")
local {IlsTrackerVisible, TrackerVisible, GuidanceLockState, IlsTrackerX, IlsTrackerY} = require("rocketAamAimState.nut")
local {floor, cos, sin, PI} = require("std/math.nut")
local {cvt} = require("dagor.math")
local DataBlock = require("DataBlock")
local {DistanceMax, RadarModeNameId, IsRadarVisible, Irst, targets, HasDistanceScale,
  HasAzimuthScale, TargetsTrigger, Azimuth, IsCScopeVisible} = require("radarState.nut")

local {mode} = require("radarComponent.nut")

const mpsToKnots = 1.94384
const metrToFeet = 3.28084
const mpsToFpm = 196.8504
const mpsToKmh = 3.6
local baseLineWidth = hdpx(4 * LINE_WIDTH)

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
    haveJ7ERadar = false
    isBuccaneerIls = false
    is410SUM1Ils = false
    isLCOSS = false
    isASP23 = false
    isEP12 = false
    isEP08 = false
    isShimadzu = false
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
    isASP23 = blk.getBool("ilsASP23", false)
    haveJ7ERadar = blk.getBool("ilsHaveJ7ERadar", false)
    isEP12 = blk.getBool("ilsEP12", false)
    isEP08 = blk.getBool("ilsEP08", false)
    isShimadzu = blk.getBool("ilsShimadzu", false)
  }
})

local function speedometer(width, height) {
  local grid = @() {
    watch = IlsColor
    pos = [width * 0.5, height * 0.5]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = baseLineWidth * IlsLineScale.value
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
    size = [baseLineWidth * IlsLineScale.value, speedMarkLen.value]
    rendObj = ROBJ_SOLID
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
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
  lineWidth = baseLineWidth * IlsLineScale.value
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
  size = [baseLineWidth * IlsLineScale.value, ph(altMarkLen.value)]
  rendObj = ROBJ_SOLID
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
}

local climbMarkPos = Computed(@() (clamp(ClimbSpeed.value * mpsToFpm, -999, 999) % 1000 / 10).tointeger())
local climbMark = @() {
  watch = climbMarkPos
  pos = [0, ph(50 - climbMarkPos.value * 0.5)]
  size = [hdpx(30), hdpx(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * 0.5 * IlsLineScale.value
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
            lineWidth = baseLineWidth * IlsLineScale.value
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

local function flyDirection(width, height, isLockedFlyPath = false) {
  return @() {
    watch = IlsColor
    size = [width * 0.1, height * 0.1]
    pos = [width * 0.5, height * (BombCCIPMode.value || BombingMode.value || isLockedFlyPath ? 0.5 : 0.3)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value
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
        lineWidth = baseLineWidth * IlsLineScale.value
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
        lineWidth = baseLineWidth * IlsLineScale.value
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
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
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
        size = [baseLineWidth * 2 * IlsLineScale.value, baseLineWidth * 2 * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        hplace = ALIGN_CENTER
      }
    ]
  }
}

local generateCompassMarkASP = function(num) {
  return {
    size = [pw(20), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 40
        font = Fonts.ussr_ils
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        size = [baseLineWidth * 0.8 * IlsLineScale.value, baseLineWidth * 6]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        hplace = ALIGN_CENTER
      }
    ]
  }
}

local function compass(width, generateFunc, step) {
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

local function compassWrap(width, height, pos, generateFunc, scale = 1.0, step = 5.0) {
  return {
    size = [width * 0.6 * scale, height * 0.2]
    pos = [width * (1 - 0.6 * scale) * 0.5, height * pos]
    clipChildren = true
    children = compass(width * 0.6 * scale, generateFunc, step)
  }
}

local maverickAimMark = @() {
  watch = IlsAtgmLocked
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(2), ph(2)]
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
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
      lineWidth = baseLineWidth * IlsLineScale.value
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
    size = [baseLineWidth * IlsLineScale.value, ph(65)]
    rendObj = ROBJ_SOLID
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
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
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, -100, 100, 100, 100],
      [VECTOR_LINE, -100, 100, -100, 0],
      [VECTOR_LINE, 100, 100, 100, 0]
    ]
  }
}

local solutionCue = @() {
  watch = IlsColor
  size = [pw(100), baseLineWidth * IlsLineScale.value]
  rendObj = ROBJ_SOLID
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
}

local aosOffset = Computed(@() Aos.value.tointeger())
local yawIndicator = @() {
  size = [pw(3), ph(3)]
  pos = [pw(50), ph(80)]
  watch = [IlsColor, aosOffset]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.value
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, aosOffset.value * 10, 0, 50, 50],
    [VECTOR_LINE, 0, -100, 0, 100],
  ]
}

local lowerCuePos = Computed(@() clamp(0.4 - TimeBeforeBombRelease.value * 0.05, 0.1, 0.5))
local lowerCueShow = Computed(@() AimLocked.value && TimeBeforeBombRelease.value > 0.0)
local function lowerSolutionCue(height, posX) {
  return @() {
    watch = lowerCueShow
    size = flex()
    children = lowerCueShow.value ?
      @() {
        watch = [IlsColor, lowerCuePos]
        size = [pw(10), baseLineWidth * IlsLineScale.value]
        pos = [pw(posX), lowerCuePos.value * height - baseLineWidth * 0.5 * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
      }
    : null
  }
}

local cancelBombVisible = Computed(@() DistToSafety.value <= 0.0)
local function cancelBombing(posY, size) {
  return @() {
    watch = cancelBombVisible
    size = flex()
    children = cancelBombVisible.value ?
      @() {
        watch = IlsColor
        size = [pw(size), ph(size)]
        pos = [pw(50), ph(posY)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
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
      lowerSolutionCue(height, 5),
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
      cancelBombing(20, 20),
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
      cancelBombing(20, 20),
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
  lineWidth = baseLineWidth * IlsLineScale.value
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
  lineWidth = baseLineWidth * IlsLineScale.value
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
  lineWidth = baseLineWidth * IlsLineScale.value
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_SECTOR, 0, 0, 93, 93, -80, max(-80, min(DistToTargetWatch.value, -3))],
    [VECTOR_SECTOR, 0, 0, 90, 90, -90, DistToTargetWatch.value],
    [VECTOR_WIDTH, baseLineWidth * 1.5 * IlsLineScale.value],
    [VECTOR_LINE, 0, -90, 0, -82], //0
    (DistToTargetWatch.value > -30 ? [VECTOR_LINE, 78, -45, 71, -41] : []),  //60
    (DistToTargetWatch.value > -60 ? [VECTOR_LINE, 45, -78, 41, -71] : []), //30
    (DistToTargetWatch.value > 0 ? [VECTOR_LINE, 82, 0, 90, 0] : []), //90
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
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
  lineWidth = baseLineWidth * 1.5 * IlsLineScale.value
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
  lineWidth = baseLineWidth * 1.5 * IlsLineScale.value
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
        lineWidth = baseLineWidth * 1.5 * IlsLineScale.value
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
        lineWidth = baseLineWidth * 1.5 * IlsLineScale.value
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
  lineWidth = baseLineWidth * 3 * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 16, 0, 16],
    [VECTOR_LINE, 0, 32, 0, 32],
    [VECTOR_LINE, 0, 48, 0, 48],
    [VECTOR_LINE, 0, 100, 0, 100],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
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
  lineWidth = baseLineWidth * 3 * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 0, 16, 0, 16],
    [VECTOR_LINE, 0, 52, 0, 52],
    [VECTOR_LINE, 0, 68, 0, 68],
    [VECTOR_LINE, 0, 84, 0, 84],
    [VECTOR_LINE, 0, 100, 0, 100],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
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
  lineWidth = baseLineWidth * IlsLineScale.value
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
        lineWidth = baseLineWidth * IlsLineScale.value
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
          lineWidth = baseLineWidth * IlsLineScale.value
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
          lineWidth = baseLineWidth * IlsLineScale.value
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
    lineWidth = baseLineWidth * IlsLineScale.value
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
  lineWidth = baseLineWidth * IlsLineScale.value
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
        lineWidth = baseLineWidth * IlsLineScale.value
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
    lineWidth = baseLineWidth * IlsLineScale.value
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
        size = [pw(10), baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
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
      lineWidth = baseLineWidth * IlsLineScale.value
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
  lineWidth = baseLineWidth * IlsLineScale.value
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
      size = [baseLineWidth * 4 * IlsLineScale.value, baseLineWidth * 4 * IlsLineScale.value]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
    },
    {
      pos = [pw(51), pw(27)]
      size = [baseLineWidth * 4 * IlsLineScale.value, baseLineWidth * 4 * IlsLineScale.value]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
    },
    {
      pos = [pw(26), pw(48.5)]
      size = [baseLineWidth * 4 * IlsLineScale.value, baseLineWidth * 4 * IlsLineScale.value]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
    },
    {
      pos = [pw(71), pw(49)]
      size = [baseLineWidth * 4 * IlsLineScale.value, baseLineWidth * 4 * IlsLineScale.value]
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
  lineWidth = baseLineWidth * IlsLineScale.value
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 90, 90],
    [VECTOR_SECTOR, 0, 0, 50, 50, -125, -55],
    [VECTOR_SECTOR, 0, 0, 50, 50, -35, 35],
    [VECTOR_SECTOR, 0, 0, 50, 50, 55, 125],
    [VECTOR_SECTOR, 0, 0, 50, 50, 145, 215],
    [VECTOR_WIDTH, baseLineWidth * 3 * IlsLineScale.value],
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
  lineWidth = baseLineWidth * 3 * IlsLineScale.value
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

local ASPSpeedValue = Computed(@() (Speed.value * mpsToKmh).tointeger())
local ASPSpeed = @() {
  watch = ASPSpeedValue
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_DTEXT
  pos = [pw(21), ph(30)]
  color = IlsColor.value
  fontSize = 45
  font = Fonts.ussr_ils
  text = ASPSpeedValue.value.tostring()
}

local ASPAltValue = Computed(@() (Altitude.value).tointeger())
local ASPAltitude = @() {
  watch = ASPAltValue
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_DTEXT
  pos = [pw(70), ph(30)]
  color = IlsColor.value
  fontSize = 45
  font = Fonts.ussr_ils
  text = ASPAltValue.value.tostring()
}

local ASPAirSymbol = @() {
  size = [pw(70), ph(70)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.value
  color = IlsColor.value
  commands = [
    [VECTOR_LINE, -100, 0, -30, 0],
    [VECTOR_LINE, -40, 0, -40, 10],
    [VECTOR_LINE, 100, 0, 30, 0],
    [VECTOR_LINE, 40, 0, 40, 10],
    [VECTOR_LINE, 0, -30, 0, -70],
  ]
}

local ASPAirSymbolWrap = @() {
  size = flex()
  children = ASPAirSymbol
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      rotate = Roll.value
      pivot = [0, 0]
    }
  }
}

local ASPRoll = @() {
  size = [pw(15), ph(15)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.value
  color = IlsColor.value
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

local ASPCompassMark = @() {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
  color = IlsColor.value
  fillColor = IlsColor.value
  commands = [
    [VECTOR_LINE, 32, 33, 68, 33],
    [VECTOR_POLY, 49, 36, 50, 33, 51, 36]
  ]
}

local function ASPTargetMark(width, height, is_radar, is_aam = false) {
  local watchVar = is_aam ? IlsTrackerVisible : (is_radar ? RadarTargetPosValid : TargetPosValid)
  local value = is_aam ? [IlsTrackerX.value, IlsTrackerY.value] : (is_radar ? RadarTargetPos : TargetPos)
  return @() {
    watch = watchVar
    size = flex()
    children = watchVar.value ?
      @() {
        watch = IlsColor
        size = [pw(3), ph(3)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100],
          (!is_radar ? [VECTOR_LINE, 0, 0, 0, 0] : [])
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = watchVar.value ? (is_aam ? [IlsTrackerX.value, IlsTrackerY.value] : value) : [width * 0.5, height * 0.575]
          }
        }
      }
      : null
  }
}

local function basicASP23(width, height) {
  return @() {
    size = [width, height]
    children = [
      compassWrap(width, height, 0.25, generateCompassMarkASP, 0.6),
      ASPCompassMark,
      ASPSpeed,
      ASPAltitude
    ]
  }
}

local ASPLRGrid = @() {
  watch = IlsColor
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
  color = IlsColor.value
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

local function ASPRadarDist(is_ru, w_pos) {
  return @() {
    watch = DistanceMax
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_DTEXT
    pos = [pw(w_pos), ph(0)]
    color = IlsColor.value
    fontSize = 40
    font = is_ru ? Fonts.ussr_ils : Fonts.usa_ils
    text = (DistanceMax.value).tointeger()
  }
}

local ASPRadarMode = @() {
  watch = [RadarModeNameId, IsRadarVisible, Irst]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_DTEXT
  pos = [pw(-7) , Irst.value ? ph(50) : ph(15)]
  color = IlsColor.value
  fontSize = 35
  font = Fonts.hud
  text = Irst.value ? "T" : mode(RadarModeNameId, IsRadarVisible)
}

local function createTargetDistASP23(index) {
  local target = targets[index]
  local dist = HasDistanceScale.value ? target.distanceRel : 0.9;
  local distanceRel = IsCScopeVisible.value ? target.elevationRel : dist

  local angleRel = HasAzimuthScale.value ? target.azimuthRel : 0.5
  local angularWidthRel = HasAzimuthScale.value ? target.azimuthWidthRel : 1.0
  local angleLeft = angleRel - 0.5 * angularWidthRel
  local angleRight = angleRel + 0.5 * angularWidthRel

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    color = IlsColor.value
    commands = [
      [VECTOR_LINE,
        !RadarTargetPosValid.value ? 100 * angleLeft : 10,
        100 * (1 - distanceRel),
        !RadarTargetPosValid.value ? 100 * angleRight : 15,
        100 * (1 - distanceRel)
      ],
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.value ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) - 5,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) + 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.value ? [VECTOR_LINE,
        100 * angleRight + 2,
        100 * (1 - distanceRel) - 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) + 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.value ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) - 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) - 5
      ] : []),
      ((target.isDetected || target.isSelected) && !RadarTargetPosValid.value ? [VECTOR_LINE,
        100 * angleLeft - 2,
        100 * (1 - distanceRel) + 5,
        100 * angleRight + 2,
        100 * (1 - distanceRel) + 5
      ] : [])
    ]
  }
}

local targetsComponent = function(createTargetDistFunc) {
  local getTargets = function() {
    local targetsRes = []
    for(local i = 0; i < targets.len(); ++i) {
      if (!targets[i])
        continue
      targetsRes.append(createTargetDistFunc(i))
    }
    return targetsRes
  }

  return @() {
    size = flex()
    children = Irst.value && RadarTargetPosValid.value ? null : getTargets()
    watch = TargetsTrigger
  }
}

local ASPRadarRoll = @() {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
  color = IlsColor.value
  commands = [
    [VECTOR_LINE, 25, 30, 42, 30],
    [VECTOR_LINE, 58, 30, 75, 30]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      rotate = Roll.value
      pivot = [0.5, 0.3]
    }
  }
}

local function ASPLaunchPermitted(is_ru, l_pos) {
  return @() {
    watch = GuidanceLockState
    size = flex()
    children = (GuidanceLockState.value >= GuidanceLockResult.RESULT_TRACKING ?
      @() {
        size = flex()
        rendObj = ROBJ_DTEXT
        pos = [pw(l_pos), ph(80)]
        color = IlsColor.value
        fontSize = 40
        font = Fonts.hud
        text = is_ru ? "ПР" : "INRNG"
      }
      : null)
  }
}

local ASPAzimuthMark = @() {
  watch = Azimuth
  size = [pw(5), baseLineWidth * 0.8 * IlsLineScale.value]
  pos = [pw(Azimuth.value * 100 - 2.5), ph(95)]
  rendObj = ROBJ_SOLID
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
}

local function ASP23LongRange(width, height) {
  return @() {
    watch = Irst
    size = [width * 0.5, height * 0.35]
    pos = [width * 0.25, height * 0.4]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    color = IlsColor.value
    commands = [
      [VECTOR_LINE, 45, 30, 48, 30],
      [VECTOR_LINE, 52, 30, 55, 30],
      [VECTOR_LINE, 50, 24, 50, 28],
      [VECTOR_LINE, 50, 32, 50, 36]
    ]
    children = [
      (!Irst.value ? ASPLRGrid : null),
      (!Irst.value ? ASPRadarDist(true, -5) : null),
      ASPRadarMode,
      ASPRadarRoll,
      targetsComponent(createTargetDistASP23),
      ASPLaunchPermitted(true, 48),
      ASPAzimuthMark
    ]
  }
}

local function ASPCCIPDistanceGrid() {
  local minDist = Computed(@() Altitude.value - DistToSafety.value)
  return @() {
    watch = [IlsColor, minDist]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    size = flex()
    color = IlsColor.value
    commands = [
      [VECTOR_LINE, 27, 38, 27, 80],
      [VECTOR_LINE, 25, 38, 27, 38],
      [VECTOR_LINE, 25, 46.4, 27, 46.4],
      [VECTOR_LINE, 25, 54.8, 27, 54.8],
      [VECTOR_LINE, 25, 63.2, 27, 63.2],
      [VECTOR_LINE, 25, 72, 27, 72],
      [VECTOR_LINE, 25, 80, 27, 80],
      [VECTOR_WIDTH, baseLineWidth * 2.2 * IlsLineScale.value],
      [VECTOR_LINE, 27.5, (80 - minDist.value / 5000.0 * 42), 30, (80 - minDist.value / 5000.0 * 42)]
    ]
    children =
    {
      size = flex()
      rendObj = ROBJ_DTEXT
      pos = [pw(22), ph(36)]
      color = IlsColor.value
      fontSize = 40
      font = Fonts.ussr_ils
      text = "5"
    }
  }
}

local DistMarkPos = Computed(@() clamp((38 + (5000.0 - DistToTarget.value) / 5000.0 * 42), 38, 80).tointeger())
local ASPCCIPDistanceMark = @() {
  watch = DistMarkPos
  size = [pw(3), ph(2)]
  pos = [pw(27), ph(DistMarkPos.value)]
  children = {
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    size = flex()
    color = IlsColor.value
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

local function ASP23CCIP(width, height) {
  return {
    size = [width, height]
    children = [
      ASPTargetMark(width, height, false),
      ASPCCIPDistanceGrid(),
      ASPCCIPDistanceMark
    ]
  }
}

local function ASP23ModeSelector(width, height) {
  return @() {
    watch = [CCIPMode, IsRadarVisible]
    size = [width, height]
    children = [
      basicASP23(width, height),
      (IsRadarVisible.value && !CCIPMode.value ? ASP23LongRange(width, height) : ASPRoll),
      (IsRadarVisible.value && !CCIPMode.value ? ASPTargetMark(width, height, true) : null),
      (CCIPMode.value ? ASP23CCIP(width, height) : null)
    ]
  }
}



local createTargetDistJ7E = @(index) function(){
  local target = targets[index]
  local distanceRel = HasDistanceScale.value ? target.distanceRel : 0.9

  local angleRel = HasAzimuthScale.value ? target.azimuthRel : 0.5
  local angularWidthRel = HasAzimuthScale.value ? target.azimuthWidthRel : 1.0

  local angleLeft = angleRel - 0.15 * angularWidthRel
  local angleRight = angleRel + 0.15 * angularWidthRel

  return {
    watch = [HasAzimuthScale, HasDistanceScale]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = baseLineWidth * 0.6 * IlsLineScale.value
    color = IlsColor.value
    commands = !RadarTargetPosValid.value ? [
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

local function J7ERadar(width, height) {
  return {
    size = [width * 0.7, height * 0.4]
    pos = [width * 0.15, height * 0.3]
    children = [
      ASPRadarMode,
      targetsComponent(createTargetDistJ7E),
      ASPLaunchPermitted(false, 20),
      ASPAzimuthMark,
      ASPRadarDist(false, -10)
    ]
  }
}

local function J7EAdditionalHud(width, height) {
  return @() {
    watch = IsRadarVisible
    size = [width, height]
    children = [
      J7ERadar(width, height),
      (IsRadarVisible.value ? ASPTargetMark(width, height, true) : null),
      ASPTargetMark(width, height, false, true)
    ]
  }
}

local function angleTxtEP(num, isLeft, textFont) {
  return @() {
    watch = IlsColor
    rendObj = ROBJ_DTEXT
    vplace = ALIGN_BOTTOM
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.value
    fontSize = 60
    font = textFont
    text = num.tostring()
  }
}

local generateCompassMarkEP = function(num) {
  return {
    size = [pw(20), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 40
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * (num % 10 == 0 ? 2 : 3)]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        hplace = ALIGN_CENTER
      }
    ]
  }
}

local generateCompassMarkEP08 = function(num) {
  return {
    size = [pw(20), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      (num % 10 == 0 ? @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 50
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      } : null),
      (num % 10 != 0 ? @() {
        watch = IlsColor
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * 5]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        hplace = ALIGN_CENTER
      } : null)
    ]
  }
}

local EPAltCCIPWatched = Computed(@() string.format(Altitude.value < 1000 ? "%d" : "%.1f", Altitude.value < 1000 ? Altitude.value : Altitude.value / 1000))
local EPAltCCIP = @() {
  watch = [EPAltCCIPWatched, IlsColor]
  rendObj = ROBJ_DTEXT
  pos = [pw(-150), ph(-20)]
  size = flex()
  color = IlsColor.value
  fontSize = 50
  text = EPAltCCIPWatched.value
  vplace = ALIGN_CENTER
}

local function generatePitchLineEP(num, isEP12, textPad) {
  local newNum = num - 5
  return {
    size = [pw(100), ph(100)]
    flow = FLOW_VERTICAL
    children = num >= 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        padding = [0, textPad]
        commands = [
          [VECTOR_LINE, 0, 0, !isEP12 && num == 0 ? 45 : 34, 0],
          (isEP12 && num != 0 ? [VECTOR_LINE, 66, 0, 100, 0] : [VECTOR_LINE, 66, 0, 74, 0]),
          (isEP12 && num == 0 ? [VECTOR_LINE, 90, 0, 100 , 0] : []),
          (!isEP12 ? [VECTOR_LINE, num == 0 ? 55 : 66, 0, 100, 0] : []),
          [VECTOR_WIDTH, baseLineWidth * 2 * IlsLineScale.value],
          (!isEP12 && num == 0 ? [VECTOR_LINE, 50, 0, 50, 0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 37, 0, 37 , 0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 42, 0, 42, 0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 47, 0, 47, 0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 53, 0, 53, 0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 58, 0, 58, 0] : []),
          (isEP12 && num == 0 ? [VECTOR_LINE, 63, 0, 63, 0] : [])
        ]
        children =
        [
          isEP12 || newNum != 0 ? angleTxtEP(newNum, true, Fonts.hud) : null,
          !isEP12 && newNum != 0 ? angleTxtEP(newNum, false, Fonts.hud) : null
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
        padding = [10, textPad]
        commands = [
          (isEP12 ? [VECTOR_LINE, 0, 0, 7, 0] : [VECTOR_LINE, 0, 0, 34, 0]),
          (isEP12 ? [VECTOR_LINE, 15, 0, 21, 0] : []),
          (isEP12 ? [VECTOR_LINE, 28, 0, 34, 0] : []),
          (isEP12 ? [VECTOR_LINE, 100, 0, 93, 0] : [VECTOR_LINE, 100, 0, 66, 0]),
          (isEP12 ? [VECTOR_LINE, 85, 0, 79, 0] : []),
          (isEP12 ? [VECTOR_LINE, 72, 0, 66, 0] : [])
        ]
        children = newNum >= -90 ?
        [
          angleTxtEP(newNum, true, Fonts.hud),
          !isEP12 ? angleTxtEP(newNum, false, Fonts.hud) : null
        ] : null
      }
    ]
  }
}

local function pitchEP(width, height, isEP12) {
  const step = 5.0
  local children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    local num = (i * step).tointeger()

    children.append(generatePitchLineEP(num, isEP12, width * 0.17))
  }

  return {
    size = [width * 0.8, height * 0.5]
    pos = [width * 0.1, pw(50)]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.1]
      }
    }
  }
}

local EP12SpeedValue = Computed(@() Mach.value < 0.5 ? (Speed.value * mpsToKmh).tointeger() : Mach.value)
local EP12SpeedVis = Computed(@() Speed.value > 20.8)
local EP12Speed = @() {
  watch = EP12SpeedVis
  size = flex()
  children = EP12SpeedVis.value ?
  @() {
    watch = EP12SpeedValue
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_DTEXT
    pos = [pw(46), ph(80)]
    color = IlsColor.value
    fontSize = 50
    font = Fonts.hud
    text = string.format(Mach.value < 0.5 ? "%d" : "%.2f", EP12SpeedValue.value)
  } : null
}

local generateAltMarkEP = function(num) {
  local val = num < 100 ? (num * 10) : (num * 0.01)
  local small = num % 10 > 0
  return {
    size = [pw(100), ph(10)]
    pos = [pw(10), 0]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * (small ? 2 : 4), baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        vplace = ALIGN_CENTER
      },
      ( num % 20 > 0 ? null :
        @() {
          watch = IlsColor
          rendObj = ROBJ_DTEXT
          color = IlsColor.value
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = string.format(num < 100 ? "%d" : "%.1f", val)
        }
      )
    ]
  }
}

local function EPAltitude(height, generateFunc) {
  local children = []

  for (local i = 2000; i >= 0;) {
    children.append(generateFunc(i))
    i -= 5
  }

  local getOffset = @() (20.0 - Altitude.value * 0.001 - 0.25 + 0.05) * height * 2.0
  return {
    size = [pw(100), ph(100)]
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

local function EPAltitudeWrap(width, height, generateFunc) {
  return {
    size = [width * 0.2, height * 0.4]
    pos = [width * 0.7, height * 0.3]
    clipChildren = true
    children = [
      EPAltitude(height * 0.4, generateFunc)
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        commands = [
          [VECTOR_LINE, 0, 45, 10, 50],
          [VECTOR_LINE, 0, 55, 10, 50]
        ]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, Tangage.value * height * 0.07]
      }
    }
  }
}

local function EP08Alt(width, height) {
  return {
    size = [pw(15), ph(10)]
    children = [EPAltCCIP]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [width * 0.5, (Tangage.value * 0.07 + 0.47) * height]
      }
    }
  }
}

local function navigationInfo(width, height, isEP08) {
  return @() {
    size = flex()
    children = [
      pitchEP(width, height * 0.7, !isEP08),
      !isEP08 ? EP12Speed : EP08Alt(width, height),
      !isEP08 ? compassWrap(width, height, 0.3, generateCompassMarkEP, 0.4) : compassWrap(width, height, 0.85, generateCompassMarkEP08, 1.4),
      !isEP08 ? EPAltitudeWrap(width, height, generateAltMarkEP) : null
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = -Roll.value
      }
    }
  }
}

local haveShell = Computed(@() ShellCnt.value > 0)
local function EPAimMark(width, height) {
  return @() {
    watch = [TargetPosValid, CCIPMode, BombingMode, haveShell]
    size = flex()
    children = CCIPMode.value || BombingMode.value ?
      @() {
        watch = IlsColor
        size = [pw(20), ph(10)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 3, 6],
          [VECTOR_LINE, -100, -100, -100, 100],
          [VECTOR_LINE, 100, -100, 100, 100],
          [VECTOR_FILL_COLOR, Color(0,0,0,0)],
          (haveShell.value ? [VECTOR_ELLIPSE, 60, -80, 10, 20] : []),
          (TargetPosValid.value ? [VECTOR_LINE, -50, 90, 50, 90] : []),
          (TargetPosValid.value ? [VECTOR_LINE, -30, 90, -30, 70] : []),
          (TargetPosValid.value ? [VECTOR_LINE, 0, 90, 0, 70] : []),
          (TargetPosValid.value ? [VECTOR_LINE, 30, 90, 30, 70] : [])
        ]
        children = EPAltCCIP
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.value && CCIPMode.value ? TargetPos : [width * 0.5, height * 0.5]
          }
        }
      } : null
  }
}

local function EPCCRPTargetMark(width, height) {
  return @() {
    watch = [TargetPosValid, BombCCIPMode]
    size = flex()
    children = BombCCIPMode.value || BombingMode.value ?
      @() {
        watch = IlsColor
        size = [pw(2), ph(2)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100],
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.value && BombingMode.value ? TargetPos : [width * 0.5, height * 0.5]
          }
        }
      } : null
  }
}

local EP08AAMMarker = @() {
  watch = IlsTrackerVisible
  size = flex()
  children = IlsTrackerVisible.value ?
  @() {
    watch = GuidanceLockState
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_ELLIPSE, 50, 50, 0.5, 0.5] : []),
      (GuidanceLockState.value != GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 60, 47, 60, 53] : []),
      (GuidanceLockState.value != GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 40, 47, 40, 53] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 65, 45, 65, 55] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 35, 45, 35, 55] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 42, 55, 57, 55] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 55, 55, 55, 53] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 50, 55, 50, 53] : []),
      (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? [VECTOR_LINE, 45, 55, 45, 53] : [])
    ]
    children =
      @() {
        watch = AamAccelLock
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          (AamAccelLock.value ? [VECTOR_LINE, 42, 50, 48, 50] : []),
          (AamAccelLock.value ? [VECTOR_LINE, 52, 50, 58, 50] : [])
        ]
        animations = [
          { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, play = true, loop = true }
        ]
      }
  } : null
}

local function swedishEPIls(width, height) {
  return @() {
    watch = [CCIPMode, BombingMode, IlsTrackerVisible]
    size = [width, height]
    children = [
      (!CCIPMode.value && !BombingMode.value && !IlsTrackerVisible.value ? flyDirection(width, height, true) : null),
      (!CCIPMode.value && !BombingMode.value ? navigationInfo(width, height, ilsSetting.value.isEP08) : null),
      EPAimMark(width, height),
      EP08AAMMarker,
      (ilsSetting.value.isEP08 ? EPCCRPTargetMark(width, height) : null)
    ]
  }
}

local shimadzuRoll = @() {
  size = [pw(15), ph(5)]
  pos = [pw(42.5), ph(15)]
  children =
  {
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
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
        rotate = -Roll.value
      }
    }
}

local generateSpdMarkShimadzu = function(num) {
  local ofs = num == 0 ? pw(-20) : (num < 100 ? pw(-30) : pw(-40))
  return {
    size = [pw(100), ph(7.5)]
    pos = [pw(40), 0]
    children = [
      ( num % 50 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          pos = [ofs, 0]
          rendObj = ROBJ_DTEXT
          color = IlsColor.value
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = num.tostring()
        }
      ),
      @() {
        watch = IlsColor
        pos = [0, ph(25)]
        size = [baseLineWidth * 5, baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
      }
    ]
  }
}

local function ShimadzuSpeed(height, generateFunc) {
  local children = []

  for (local i = 0; i <= 1000; i += 10) {
    children.append(generateFunc(i))
  }

  local getOffset = @() (Speed.value * mpsToKnots * 0.0075 - 0.5) * height
  return {
    size = [pw(100), ph(100)]
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

local function ShimadzuSpeedWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.1, height * 0.2]
    clipChildren = true
    children = [
      ShimadzuSpeed(height * 0.5, generateFunc),
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        commands = [
          [VECTOR_LINE, 80, 45, 68, 50],
          [VECTOR_LINE, 80, 55, 68, 50]
        ]
      }
    ]
  }
}

local generateAltMarkShimadzu = function(num) {
  return {
    size = [pw(100), ph(7.5)]
    pos = [pw(15), 0]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        watch = IlsColor
        size = [baseLineWidth * 5, baseLineWidth * IlsLineScale.value]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        vplace = ALIGN_CENTER
      },
      ( num % 50 > 0 ? null :
        @() {
          watch = IlsColor
          size = flex()
          rendObj = ROBJ_DTEXT
          color = IlsColor.value
          vplace = ALIGN_CENTER
          fontSize = 40
          font = Fonts.hud
          text = string.format("%.1f", num / 100.0)
        }
      )
    ]
  }
}

local function ShimadzuAlt(height, generateFunc) {
  local children = []

  for (local i = 2000; i >= 0; i -= 10) {
    children.append(generateFunc(i))
  }

  local getOffset = @() ((20000 - BarAltitude.value) * 0.0007425 - 0.4625) * height
  return {
    size = [pw(100), ph(100)]
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

local function ShimadzuAltWrap(width, height, generateFunc) {
  return {
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.75, height * 0.2]
    clipChildren = true
    children = [
      ShimadzuAlt(height * 0.5, generateFunc),
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        commands = [
          [VECTOR_LINE, 0, 45, 10, 50],
          [VECTOR_LINE, 0, 55, 10, 50]
        ]
      }
    ]
  }
}

local MachWatch = Computed(@() (floor(Mach.value * 100)).tointeger())
local ShimadzuMach = @() {
  watch = [MachWatch, IlsColor]
  size = flex()
  pos = [pw(12), ph(72)]
  rendObj = ROBJ_DTEXT
  color = IlsColor.value
  fontSize = 50
  text = string.format(MachWatch.value < 100 ? ".%02d" : "%.2f", MachWatch.value < 100 ? MachWatch.value : MachWatch.value / 100.0)
}

local OverloadWatch = Computed(@() (floor(Overload.value * 10)).tointeger())
local ShimadzuOverload = @() {
  watch = [OverloadWatch, IlsColor]
  size = flex()
  pos = [pw(12), ph(77)]
  rendObj = ROBJ_DTEXT
  color = IlsColor.value
  fontSize = 50
  text = string.format("%.1fG", OverloadWatch.value / 10.0)
}

local function generatePitchLineShim(num) {
  local sign = num > 0 ? 1 : -1
  local newNum = num >= 0 ? num : (num - 5)
  return {
    size = [pw(100), ph(50)]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        padding = [0, 10]
        commands = [
          [VECTOR_LINE, 0, 0, 34, 0],
          [VECTOR_LINE, 66, 0, 100, 0]
        ]
        children = [angleTxt(-5, true, Fonts.hud), angleTxt(-5, false, Fonts.hud)]
      }
    ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        padding = [10, 10]
        commands = [
          [VECTOR_LINE, 0, 5 * sign, 0, 0],
          [VECTOR_LINE, 0, 0, num > 0 ? 34 : 7, 0],
          (num < 0 ? [VECTOR_LINE, 15, 0, 21, 0] : []),
          (num < 0 ? [VECTOR_LINE, 28, 0, 34, 0] : []),
          [VECTOR_LINE, 100, 5 * sign, 100, 0],
          [VECTOR_LINE, 100, 0, num > 0 ? 66 : 93, 0],
          (num < 0 ? [VECTOR_LINE, 85, 0, 79, 0] : []),
          (num < 0 ? [VECTOR_LINE, 72, 0, 66, 0] : [])
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, Fonts.hud), angleTxt(newNum, false, Fonts.hud)] : null
      }
    ]
  }
}

local function ShimadzuPitch(width, height) {
  const step = 5.0
  local children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    local num = (i * step).tointeger()

    children.append(generatePitchLineShim(num))
  }

  return {
    size = [width * 0.5, height * 0.7]
    pos = [width * 0.25, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.07]
      }
    }
  }
}

local generateCompassMarkShim = function(num) {
  return {
    size = [pw(8), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_DTEXT
        color = IlsColor.value
        hplace = ALIGN_CENTER
        fontSize = 40
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      },
      @() {
        watch = IlsColor
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * 5]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        hplace = ALIGN_CENTER
      }
    ]
  }
}

local function f16CcipMark(width, height) {
  return @() {
    watch = [IlsColor, TargetPosValid]
    size = [pw(3), ph(3)]
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    rendObj = ROBJ_VECTOR_CANVAS
    fillColor = Color(0,0,0,0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 100, 100],
      (TargetPosValid.value ? [VECTOR_LINE, -100, -100, 100, -100] : []),
      [VECTOR_WIDTH, baseLineWidth * 2 * IlsLineScale.value],
      [VECTOR_ELLIPSE, 0, 0, 0, 0],
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TargetPosValid.value ? TargetPos : [width * 0.5, height * 0.6]
      }
    }
  }
}

local function f16CcrpMark(width, height) {
  return {
    size = flex()
    children = [
      {
        size = flex()
        children = [
          lowerSolutionCue(height, -5),
          bombFallingLine()
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [TargetPos[0], height * 0.1]
            rotate = -Roll.value
            pivot=[0.1, TargetPos[1] / height - 0.1]
          }
        }
      },
      {
        size = [pw(3), ph(3)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, -100, -100, 100, -100],
          [VECTOR_LINE, -100, -100, -100, 100],
          [VECTOR_LINE, -100, 100, 100, 100],
          [VECTOR_LINE, 100, -100, 100, 100],
          [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value * 2],
          [VECTOR_LINE, 0, 0, 0, 0]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPos
          }
        }
      },
      cancelBombing(50, 40)
    ]
  }
}

local ShimadzuMode = @() {
  watch = [CCIPMode, BombingMode]
  size = flex()
  pos = [pw(78), ph(77)]
  rendObj = ROBJ_DTEXT
  color = IlsColor.value
  fontSize = 50
  font = Fonts.hud
  text = CCIPMode.value ? "CCIP" : (BombingMode.value ? "CCRP" : "NAV")
}

local function ShimadzuIls(width, height) {
  return {
    size = [width, height]
    children = [
      flyDirection(width, height, true),
      shimadzuRoll,
      ShimadzuSpeedWrap(width, height, generateSpdMarkShimadzu),
      ShimadzuMach,
      ShimadzuAltWrap(width, height, generateAltMarkShimadzu),
      ShimadzuPitch(width, height),
      ShimadzuOverload,
      ShimadzuMode,
      compassWrap(width, height, 0.85, generateCompassMarkShim, 1.0, 2.0),
      {
        size = [pw(2), ph(3)]
        pos = [pw(50), ph(92)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 0, 0, -100, 100],
          [VECTOR_LINE, 0, 0, 100, 100]
        ]
      },
      {
        size = [pw(2), ph(10)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [[VECTOR_LINE, 0, 0, 0, 100]]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [Aos.value * width * 0.02 + 0.5 * width, 0.4 * height]
          }
        }
      },
      @() {
        watch = CCIPMode
        size = flex()
        children = [
          (CCIPMode.value ? f16CcipMark(width, height) : null),
          (CCIPMode.value ? cancelBombing(50, 40) : null)
        ]
      },
      @() {
        watch = BombingMode
        size = flex()
        children = [BombingMode.value ? f16CcrpMark(width, height) : null]
      }
    ]
  }
}

local planeIls = @(width, height) function() {

  local {isAVQ7, haveAVQ7Bombing, haveAVQ7CCIP, isASP17, isBuccaneerIls,
    is410SUM1Ils, isLCOSS, isASP23, haveJ7ERadar, isEP12, isEP08, isShimadzu} = ilsSetting.value

  return {
    watch = [BombingMode, CCIPMode, TrackerVisible, ilsSetting]
    children = [
      (isAVQ7 ? basicInformation(width, height) : null),
      (haveAVQ7Bombing && BombingMode.value ? bombingMode(width, height) : null),
      (haveAVQ7CCIP && CCIPMode.value ? CCIP(width, height) : null),
      (isAVQ7 && (!BombingMode.value || !haveAVQ7Bombing) &&
       (!CCIPMode.value || !haveAVQ7CCIP) ? compassWrap(width, height, 0.1, generateCompassMark) : null),
      (isASP17 ? ASP17(width, height) : null),
      (isBuccaneerIls ? buccaneerHUD(width, height) : null),
      (is410SUM1Ils ? basic410SUM(width, height) : null),
      (is410SUM1Ils && CCIPMode.value ? SUMCCIPMode(width, height) : null),
      (is410SUM1Ils && TrackerVisible.value ? SumAAMMode(width, height) : null),
      (is410SUM1Ils && BombingMode.value ? SumBombingSight(width, height) : null),
      (is410SUM1Ils && !BombingMode.value && !CCIPMode.value ? SUMGunReticle(width, height) : null),
      (isLCOSS ? LCOSS(width, height) : null),
      (isASP23 ? ASP23ModeSelector(width, height) : null),
      (haveJ7ERadar && (!BombingMode.value || !haveAVQ7Bombing) &&
       (!CCIPMode.value || !haveAVQ7CCIP) ? J7EAdditionalHud(width, height) : null),
      (isEP08 || isEP12 ? swedishEPIls(width, height) : null),
      (isShimadzu ? ShimadzuIls(width, height) : null)
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

return planeIlsSwitcher