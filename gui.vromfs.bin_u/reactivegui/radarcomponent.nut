//local frp = require("frp")
//local {isEqual} = require("std/underscore.nut")
local {PI, floor, cos, sin, fabs, sqrt} = require("std/math.nut")
local compass = require("compass.nut")
local {HasCompass, CompassValue} = require("compassState.nut")
local {isPlayingReplay} = require("hudState.nut")
local {hudFontHgt, fontOutlineFxFactor, greenColor, fontOutlineColor,
  isColorOrWhite} = require("style/airHudStyle.nut")

local { selectedTargetSpeedBlinking, selectedTargetBlinking, targetAspectEnabled, modeNames,
  targets, screenTargets, azimuthMarkers, forestall, selectedTarget, radarPosSize, IsRadarHudVisible,
  IsNoiseSignaVisible, MfdRadarEnabled, Speed, IsRadarVisible, RadarModeNameId,
  Azimuth, Elevation, Distance, AzimuthHalfWidth, ElevationHalfWidth, DistanceGateWidthRel, NoiseSignal,
  IsRadar2Visible, Radar2ModeNameId, Azimuth2, Elevation2, Distance2, AzimuthHalfWidth2, ElevationHalfWidth2,
  NoiseSignal2, AimAzimuth, TurretAzimuth, TargetRadarAzimuthWidth, TargetRadarDist, AzimuthMin, AzimuthMax,
  ElevationMin, ElevationMax, IsBScopeVisible, IsCScopeVisible, ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax,
  TargetsTrigger, ScreenTargetsTrigger, ViewMode, MfdViewMode, HasAzimuthScale, HasDistanceScale, ScanPatternsMax,
  DistanceMax, DistanceMin, DistanceScalesMax, AzimuthMarkersTrigger, Irst, RadarScale, IsForestallVisible,
  ScanZoneWatched, LockZoneWatched, IsScanZoneAzimuthVisible, IsScanZoneElevationVisible,
  IsLockZoneVisible, IsAamLaunchZoneVisible, AamLaunchZoneDist, AamLaunchZoneDistMin,
  AamLaunchZoneDistMax, IndicationForCollapsedRadar, VelocitySearch,
  AzimuthRange, AzimuthRangeInv, ElevationRangeInv} = require("radarState.nut")

local areaBackgroundColor = Color(0,0,0,120)

local defLineWidth = hdpx(1.2)

local styleText = {
  color = greenColor
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

local styleLineForeground = {
  color = greenColor
  lineWidth = hdpx(LINE_WIDTH)
}

const AIM_LINE_WIDTH = 2.0
const TURRET_LINE_WIDTH = 1.0

local compassSize = [hdpx(500), hdpx(32)]
local compassStep = 5.0
local compassOneElementWidth = compassSize[1]

local getCompassStrikeWidth = @(oneElementWidth, step) 360.0 * oneElementWidth / step

//animation trigger
local frameTrigger = {}
selectedTargetBlinking.subscribe(@(v) v ? ::anim_start(frameTrigger) : ::anim_request_stop(frameTrigger))
local speedTargetTrigger = {}
selectedTargetSpeedBlinking.subscribe(@(v) v ? ::anim_start(speedTargetTrigger) : ::anim_request_stop(speedTargetTrigger))

const targetLifeTime = 5.0

local targetsComponent = @(size, createTargetFunc, color) function() {

  local children = targets.filter(@(t) t != null)
    .map(@(_, i) createTargetFunc(i, hdpx(5) * 0, size, color))

  return {
    size
    children
    watch = TargetsTrigger //needed
  }
}

local function B_ScopeSquareBackground(size, color) {
  local scanAzimuthMinRelW = Computed(@() ScanAzimuthMin.value * AzimuthRangeInv.value)
  local scanAzimuthMaxRelW = Computed(@() ScanAzimuthMax.value * AzimuthRangeInv.value)

  local gridSecondaryCommandsW = Computed(function(){
    local scanAzimuthMinRel = scanAzimuthMinRelW.value
    local scanAzimuthMaxRel = scanAzimuthMaxRelW.value
    local azimuthRangeInv = AzimuthRangeInv.value

    local gridSecondaryCommands = []

    if (HasDistanceScale.value)
      gridSecondaryCommands = [
        [VECTOR_LINE, 50 + scanAzimuthMinRel * 100, 25, 50 + scanAzimuthMaxRel * 100, 25],
        [VECTOR_LINE, 50 + scanAzimuthMinRel * 100, 50, 50 + scanAzimuthMaxRel * 100, 50],
        [VECTOR_LINE, 50 + scanAzimuthMinRel * 100, 75, 50 + scanAzimuthMaxRel * 100, 75]
      ]

    if (HasAzimuthScale.value) {
      local azimuthRelStep = PI / 12.0 * azimuthRangeInv
      local azimuthRel = 0.0
      while (azimuthRel > ScanAzimuthMin.value * azimuthRangeInv) {
        gridSecondaryCommands.append([
          VECTOR_LINE,
          50 + azimuthRel * 100, 0,
          50 + azimuthRel * 100, 100
        ])
        azimuthRel -= azimuthRelStep
      }
      azimuthRel = 0.0
      while (azimuthRel < ScanAzimuthMax.value * azimuthRangeInv) {
        gridSecondaryCommands.append([
          VECTOR_LINE,
          50 + azimuthRel * 100, 0,
          50 + azimuthRel * 100, 100
        ])
        azimuthRel += azimuthRelStep
      }
    }
    return gridSecondaryCommands
  })

  local back = {
    rendObj = ROBJ_SOLID
    size
    color = areaBackgroundColor
  }

  local frame = {
    rendObj = ROBJ_VECTOR_CANVAS
    size
    color
    lineWidth = hdpx(LINE_WIDTH)
    gridSecondaryCommands = [
      [VECTOR_LINE, 0, 0, 0, 100],
      [VECTOR_LINE, 0, 100, 100, 100],
      [VECTOR_LINE, 100, 100, 100, 0],
      [VECTOR_LINE, 100, 0, 0, 0]
    ]
  }

  local function gridMain() {
    local scanAzimuthMinRel = scanAzimuthMinRelW.value
    local scanAzimuthMaxRel = scanAzimuthMaxRelW.value
    local finalColor = isColorOrWhite(color)
    return {
      watch = [scanAzimuthMaxRelW, scanAzimuthMinRelW]
      rendObj = ROBJ_VECTOR_CANVAS
      size
      color = finalColor
      lineWidth = hdpx(LINE_WIDTH)
      opacity = 0.7
      commands = [
        [
          VECTOR_LINE,
          50 + scanAzimuthMinRel * 100, 0,
          50 + scanAzimuthMinRel * 100, 100
        ],
        [
          VECTOR_LINE,
          50 + scanAzimuthMaxRel * 100, 0,
          50 + scanAzimuthMaxRel * 100, 100
        ],
      ]
    }
  }
  local gridSecondary = @() {
    watch = [gridSecondaryCommandsW]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = defLineWidth
    fillColor = 0
    size
    color = isColorOrWhite(color)
    commands = gridSecondaryCommandsW.value
  }
  return {
    size = SIZE_TO_CONTENT
    children = [ back, frame, gridMain, gridSecondary ]
  }
}

local B_ScopeSquareTargetSectorComponent = @(size, valueWatched, distWatched, halfWidthWatched, color) function() {
  local function tankRadar() {
    local azimuthRange = AzimuthRange.value ?? 1
    local val = valueWatched.value ?? 1
    local distWatchedV = distWatched.value ?? 1
    local halfWidth = halfWidthWatched.value ?? 1

    local halfAzimuthWidth = 100.0 * (azimuthRange > 0 ? halfWidth / azimuthRange : 0)
    local com = [[VECTOR_POLY, -halfAzimuthWidth, 100 * (1 - distWatchedV), halfAzimuthWidth, 100 * (1 - distWatchedV),
          halfAzimuthWidth, 100, -halfAzimuthWidth, 100]]

    if (val * 100 - halfAzimuthWidth < 0)
      com.append([VECTOR_POLY, -halfAzimuthWidth + 100, 100 * (1 - distWatchedV), halfAzimuthWidth + 100, 100 * (1 - distWatchedV),
          halfAzimuthWidth + 100, 100, -halfAzimuthWidth + 100, 100])
    if (val * 100 + halfAzimuthWidth > 100)
      com.append([VECTOR_POLY, -halfAzimuthWidth - 100, 100 * (1 - distWatchedV), halfAzimuthWidth - 100, 100 * (1 - distWatchedV),
          halfAzimuthWidth - 100, 100, -halfAzimuthWidth - 100, 100])
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = defLineWidth
      watch = [valueWatched, distWatched, halfWidthWatched, AzimuthRange]
      opacity = 0.42
      size
      commands = com
    }
  }

  local function aircraftRadar() {
    local azimuthRange = AzimuthRange.value
    local halfAzimuthWidth = 100.0 * (azimuthRange > 0 ? halfWidthWatched.value / azimuthRange : 0)
    local com = [
      [VECTOR_POLY, 50 - halfAzimuthWidth, 100 * (1 - distWatched.value),
                    50 + halfAzimuthWidth, 100 * (1 - distWatched.value),
                    50 + halfAzimuthWidth, 100,
                    50 - halfAzimuthWidth, 100]]
    return {
      watch = [AzimuthRange, halfWidthWatched, distWatched]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = defLineWidth
      opacity = 0.2
      color
      fillColor = isColorOrWhite(color)
      size
      commands = com
    }
  }

  local showRadar = distWatched && halfWidthWatched && halfWidthWatched.value > 0
  local isTank =  AzimuthRange.value > PI

  return {
    watch = [valueWatched, distWatched, halfWidthWatched, AzimuthRange]
    children = !showRadar ? null
      : isTank ? tankRadar
      : aircraftRadar
    pos = [valueWatched.value * size[0], 0]
  }
}

local B_ScopeSquareAzimuthComponent = @(size, valueWatched, distWatched, halfWidthWatched, tanksOnly, color) function() {
  local function part1(){
    local azimuthRange = AzimuthRange.value
    local halfAzimuthWidth = 100.0 * (azimuthRange > 0 ? halfWidthWatched.value / azimuthRange : 0)

    return {
      watch = [AzimuthRange, halfWidthWatched]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = defLineWidth
      color
      fillColor = isColorOrWhite(color)
      opacity = 0.4
      size
      commands = [
        [VECTOR_POLY, -halfAzimuthWidth, 0, halfAzimuthWidth, 0, halfAzimuthWidth, 100, -halfAzimuthWidth, 100]
      ]
    }
  }
  local commandsW = distWatched
    ? Computed(@() [[VECTOR_LINE_DASHED, 0, 100.0 * (1.0 - distWatched.value), 0, 100.0, hdpx(10), hdpx(5)]])
    : Watched([[VECTOR_LINE, 0, 0, 0, 100.0]])

  local function part2(){
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      size
      watch = commandsW
      color = isColorOrWhite(color)
      lineWidth = hdpx(LINE_WIDTH)
      commands = commandsW.value
    }
  }

  local showPart1 = (!distWatched || !halfWidthWatched) ? null : distWatched.value == 1.0 && halfWidthWatched.value > 0
  local isTank = AzimuthRange.value > PI
  local show = !tanksOnly || isTank
  return {
    watch = [distWatched, halfWidthWatched, valueWatched, AzimuthRange]
    pos = [valueWatched.value * size[0], 0]
    children = !show ? null
      : showPart1 ? part1
      : part2
  }
}

local B_ScopeSquareLaunchRangeComponent = @(size, aamLaunchZoneDist, aamLaunchZoneDistMin, aamLaunchZoneDistMax, color) function() {

  local commands = [
    [VECTOR_LINE, 80, (1.0 - aamLaunchZoneDist.value) * 100,    100, (1.0 - aamLaunchZoneDist.value)    * 100],
    [VECTOR_LINE, 90, (1.0 - aamLaunchZoneDistMin.value) * 100, 100, (1.0 - aamLaunchZoneDistMin.value) * 100],
    [VECTOR_LINE, 90, (1.0 - aamLaunchZoneDistMax.value) * 100, 100, (1.0 - aamLaunchZoneDistMax.value) * 100]
  ]

  return {
    watch = [aamLaunchZoneDist, aamLaunchZoneDistMin, aamLaunchZoneDistMax]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(4)
    color = isColorOrWhite(color)
    fillColor = 0
    size
    opacity = 0.42
    commands
  }
}

local distanceGateWidthRelMin = 0.05
local angularGateWidthMultSquare = 4.0

local distanceGateWidthMult = 2.0
local iffDistRelMult = 0.5

local createTargetOnRadarSquare = @(index, radius, size, color) function() {


  local res = { watch = [HasAzimuthScale, HasDistanceScale, IsRadar2Visible, AzimuthHalfWidth2, AzimuthHalfWidth, DistanceGateWidthRel] }
  local target = targets[index]

  if (target == null)
    return res

  local opacity = (1.0 - target.ageRel) * target.signalRel

  local angleRel = HasAzimuthScale.value ? target.azimuthRel : 0.5
  local angularWidthRel = HasAzimuthScale.value ? target.azimuthWidthRel : 1.0
  local angleLeft = angleRel - 0.5 * angularWidthRel
  local angleRight = angleRel + 0.5 * angularWidthRel

  local distanceRel = HasDistanceScale.value ? target.distanceRel : 0.9
  local radialWidthRel = target.distanceWidthRel

  local selectionFrame = null

  local frameCommands = []

  local azimuthHalfWidth = IsRadar2Visible.value ? AzimuthHalfWidth2.value : AzimuthHalfWidth.value
  local angularGateWidthRel = angularGateWidthMultSquare * 2.0 * azimuthHalfWidth / AzimuthRange.value
  local angleGateLeftRel = angleRel - 0.5 * angularGateWidthRel
  local angleGateRightRel = angleRel + 0.5 * angularGateWidthRel

  local distanceGateWidthRel = max(DistanceGateWidthRel.value, distanceGateWidthRelMin) * distanceGateWidthMult
  local distanceInner = distanceRel - 0.5 * distanceGateWidthRel
  local distanceOuter = distanceRel + 0.5 * distanceGateWidthRel

  if (target.isDetected || target.isSelected) {
    frameCommands.append(
      [ VECTOR_LINE,
        100 * angleGateLeftRel,
        100 * (1 - distanceInner),
        100 * angleGateLeftRel,
        100 * (1 - distanceOuter)
      ],
      [ VECTOR_LINE,
        100 * angleGateRightRel,
        100 * (1 - distanceInner),
        100 * angleGateRightRel,
        100 * (1 - distanceOuter)
      ]
    )
  }
  if (target.isSelected) {
    frameCommands.append(
      [ VECTOR_LINE,
        100 * angleGateLeftRel,
        100 * (1 - distanceInner),
        100 * angleGateRightRel,
        100 * (1 - distanceInner)
      ],
      [ VECTOR_LINE,
        100 * angleGateLeftRel,
        100 * (1 - distanceOuter),
        100 * angleGateRightRel,
        100 * (1 - distanceOuter)
      ]
    )
  }
  if (!target.isEnemy) {
    local iffMarkDistanceRel = distanceRel + iffDistRelMult * distanceGateWidthRel
    frameCommands.append(
      [ VECTOR_LINE,
        100 * angleLeft,
        100 * (1 - iffMarkDistanceRel),
        100 * angleRight,
        100 * (1 - iffMarkDistanceRel)
      ]
    )
  }

  selectionFrame = target.isSelected
    ? {
      rendObj = ROBJ_VECTOR_CANVAS
      size
      lineWidth = hdpx(3)
      color = isColorOrWhite(color)
      fillColor = 0
      pos = [radius, radius]
      commands = frameCommands
      animations = [{ prop = AnimProp.opacity, from = 0.0, to = 1, duration = 0.5, play = selectedTargetBlinking.value, loop = true, easing = InOutSine, trigger = frameTrigger}]
    }
    : {
      rendObj = ROBJ_VECTOR_CANVAS
      size
      lineWidth = hdpx(3)
      color = isColorOrWhite(color)
      fillColor = 0
      pos = [radius, radius]
      commands = frameCommands
    }

  return res.__update({
    rendObj = ROBJ_VECTOR_CANVAS
    size
    lineWidth = 100 * radialWidthRel
    fillColor = 0
    color = isColorOrWhite(color)
    opacity = opacity
    commands = [
      [ VECTOR_LINE,
        100 * angleLeft,
        100 * (1 - distanceRel),
        100 * angleRight,
        100 * (1 - distanceRel)
      ]
    ]
    transform = {
      pivot = [0.5, 0.5]
      translate = [
        -radius,
        -radius
      ]
    }
    children = selectionFrame
  })
}


local function arrowIcon(size, color) {
  return {

    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = defLineWidth
    color
    fillColor = color
    size = size
    commands = [
      [VECTOR_POLY, 50, 0,  0, 50,  35, 50,  35, 100,
        65, 100,  65, 50,  100, 50]
    ]
  }
}


local function groundNoiseIcon(size, color) {
  return {
    size = size
    children = [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = size
        color
        fillColor = color
        commands = [
          [VECTOR_RECTANGLE, 0, 75, 100, 32]
        ]
      },
      {
        pos = [size[0] * 0.15, 0]
        children = arrowIcon([size[0] * 0.25, size[1] * 0.75], color)
        transform = {
          pivot = [0.5, 0.5]
          rotate = 180.0
        }
      },
      {
        pos = [size[0] * (1.0 - 0.35), 0]
        children = arrowIcon([size[0] * 0.25, size[1] * 0.75], color)
      }
    ]
  }
}


local function noiseSignalComponent(signalWatched, size, isIconOnLeftSide, color) {

  local indicator = @() {

    watch = [signalWatched]
    size
    flow = FLOW_VERTICAL
    gap = size[1] * (1.0 - 0.18 * 4) / 3.0
    children = array(4).map(@(_, i) {
      rendObj = ROBJ_SOLID
      size = [size[0], size[1] * 0.18]
      color
      fillColor = color
      opacity = signalWatched.value > (3 - i) ? 1.0 : 0.21
    })
  }

  local icon = groundNoiseIcon([size[1], size[1]], color)

  local children = isIconOnLeftSide
    ? [icon, indicator]
    : [indicator, icon]

  return {
    flow = FLOW_HORIZONTAL
    gap = size[1] * 0.2
    children
  }
}


local function noiseSignal(size, pos1, pos2, color) {
  local showSignal = Computed(@() IsNoiseSignaVisible.value && !MfdRadarEnabled.value)
  local showSignal1 = Computed(@() showSignal.value && IsRadarVisible.value && NoiseSignal.value > 0.5)
  local showSignal2 = Computed(@() showSignal.value && IsRadar2Visible.value && NoiseSignal2.value > 0.5)
  local noize1 = noiseSignalComponent(NoiseSignal, size, true, color)
  local noize2 = noiseSignalComponent(NoiseSignal2, size, true, color)
  local signal1 = @() {watch = showSignal1, size, pos=pos1, children =  showSignal1.value ? noize1 : null}
  local signal2 = @() {watch = showSignal2, size, pos=pos2, children =  showSignal2.value ? noize2 : null}

  return {
    children = [signal1, signal2]
  }
}


local radToDeg = 180.0 / 3.14159

local function getRadarModeText(radarModeNameWatch, isRadarVisibleWatch) {
  local texts = []
  if (radarModeNameWatch.value >= 0)
    texts.append(::loc(modeNames[radarModeNameWatch.value]))
  else if (isRadarVisibleWatch.value)
    texts.append(Irst.value ? ::loc("hud/irst") : ::loc("hud/radarEmitting"))
 return "".join(texts)
}


local makeRadarModeText = @(textConfig, color) function() {
  return {
    watch = [RadarModeNameId, IsRadarVisible]
    rendObj = ROBJ_DTEXT
    size = SIZE_TO_CONTENT
    text = getRadarModeText(RadarModeNameId, IsRadarVisible)
    color
  }.__merge(textConfig)
}

local makeRadar2ModeText = @(textConfig, color) function() {
  return {
    watch = [Radar2ModeNameId, IsRadar2Visible]
    rendObj = ROBJ_DTEXT
    size = SIZE_TO_CONTENT
    text = getRadarModeText(Radar2ModeNameId, IsRadar2Visible)
    color
  }.__merge(textConfig)
}

local offsetScaleFactor = 1.3

local B_ScopeSquareMarkers = @(size, color) function() {

  local res = { watch = [HasAzimuthScale, ScanAzimuthMax, ScanAzimuthMin, HasDistanceScale,
                         IsRadarVisible, IsRadar2Visible, IndicationForCollapsedRadar] }

  local isCollapsed = !IsRadarVisible.value && !IsRadar2Visible.value
  local hiddenText = (isCollapsed && !IndicationForCollapsedRadar.value)
  if (hiddenText)
    return res

  return res.__update({
    size = [offsetScaleFactor * size[0], offsetScaleFactor * size[1]]
    children = [
      !HasAzimuthScale.value || ScanAzimuthMax.value <= ScanAzimuthMin.value
      ? null
      : @() {
        watch = [ScanAzimuthMin, ScanAzimuthMax,
          ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
        rendObj = ROBJ_DTEXT
        pos = [0, - hdpx(20)]
        color
        text = "".concat(floor((ScanAzimuthMax.value - ScanAzimuthMin.value) * radToDeg + 0.5),
                ::loc("measureUnits/deg"),
                "x",
                floor((ScanElevationMax.value - ScanElevationMin.value) * radToDeg + 0.5),
                ::loc("measureUnits/deg"),
                (ScanPatternsMax.value > 1 ? "*" : " "))
      },
      !HasDistanceScale.value ? null
      : @() {
        watch = [VelocitySearch, DistanceMax, DistanceScalesMax ]
        rendObj = ROBJ_DTEXT
        color
        pos = [max(size[0] * 0.75, hdpx(70)), -hdpx(20)]
        text = "".concat(VelocitySearch.value
                ? ::cross_call.measureTypes.SPEED.getMeasureUnitsText(DistanceMax.value, true, false, false)
                : ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMax.value * 1000.0, true, false, false),
                (DistanceScalesMax.value > 1 ? "*" : " "))
      },
      !HasDistanceScale.value || isCollapsed ? null
      : @() {
        watch = [VelocitySearch, DistanceMin ]
        rendObj = ROBJ_DTEXT
        color
        pos = [max(size[0] * 0.75, hdpx(70)), size[1] + hdpx(6)]
        text = VelocitySearch.value
          ? ::cross_call.measureTypes.SPEED.getMeasureUnitsText(DistanceMin.value, true, false, false)
          : ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMin.value * 1000.0, true, false, false)
      },
      isCollapsed ? null
      : @() {
        watch = [AzimuthMin]
        rendObj = ROBJ_DTEXT
        color = isColorOrWhite(color)
        pos = [hdpx(4), hdpx(4)]
        text = "".concat(floor(AzimuthMin.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      },
      isCollapsed ? null
      : @() {
        halign = ALIGN_RIGHT
        watch = [AzimuthMax]
        size = [size[0], SIZE_TO_CONTENT]
        rendObj = ROBJ_DTEXT
        color = isColorOrWhite(color)
        pos = [-hdpx(4), hdpx(4)]
        text = "".concat(floor(AzimuthMax.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      },
      isCollapsed ? null
      : makeRadarModeText({
          pos = [size[0] * 0.5, -hdpx(20)]
        }, color),
      isCollapsed ? null
      : makeRadar2ModeText({
          pos = [size[0] * 0.5, -hdpx(50)]
        }, color),
      noiseSignal(
        [max(size[0] * 0.06, hdpx(20)), max(size[0] * 0.06, hdpx(20))],
        [size[0] * 0.5 - max(size[0] * 0.15, hdpx(60)), -hdpx(25)],
        [size[0] * 0.5 - max(size[0] * 0.15, hdpx(60)), -hdpx(55)],
        color)
    ]
  })
}

local function B_ScopeSquare(size, color) {
  local bkg = B_ScopeSquareBackground(size, color)
  local scopeTgtSectorComp = B_ScopeSquareTargetSectorComponent(size, TurretAzimuth, TargetRadarDist, TargetRadarAzimuthWidth, color)
  local scopeSquareAzimuthComp1 = B_ScopeSquareAzimuthComponent(size, TurretAzimuth, null, null, true, color)
  local groundReflComp = @() {

    size
    rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
    isSquare = true
    xFragments = 30
    yFragments = 10
    color = isColorOrWhite(color)
  }
  local scopeSquareAzimuthComp2 = B_ScopeSquareAzimuthComponent(size, Azimuth, Distance, AzimuthHalfWidth, false, color)
  local scopeSquareAzimuthComp3 = B_ScopeSquareAzimuthComponent(size, Azimuth2, Distance2, AzimuthHalfWidth2, false, color)
  local scopeSqLaunchRangeComp = B_ScopeSquareLaunchRangeComponent(size, AamLaunchZoneDist,
                                                        AamLaunchZoneDistMin, AamLaunchZoneDistMax, color)
  local tgts = targetsComponent(size, createTargetOnRadarSquare, color)
  local markers = B_ScopeSquareMarkers(size, color)
  return function() {
    local children = [ bkg, scopeTgtSectorComp, scopeSquareAzimuthComp1, groundReflComp ]
    if (IsRadarVisible.value)
      children.append(scopeSquareAzimuthComp2)
    if (IsRadar2Visible.value)
      children.append(scopeSquareAzimuthComp3)
    if (IsAamLaunchZoneVisible.value && HasDistanceScale.value)
      children.append(scopeSqLaunchRangeComp)
    children.append(tgts)
    return {
      watch = [ MfdRadarEnabled,
                IsRadarVisible, RadarModeNameId,
                IsRadar2Visible, Radar2ModeNameId,
                IsAamLaunchZoneVisible, HasDistanceScale ]
      children = [
        {
          size = SIZE_TO_CONTENT
          clipChildren = true
          children
        },
        markers
      ]
    }
  }
}

local function B_ScopeBackground(size, color) {

  local circle = {
    rendObj = ROBJ_VECTOR_CANVAS
    size
    color
    fillColor = areaBackgroundColor
    lineWidth = hdpx(LINE_WIDTH)
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
  }

  local function gridSecondary() {
    local commands = HasDistanceScale.value ?
    [
      [VECTOR_ELLIPSE, 50, 50, 12.5, 12.5],
      [VECTOR_ELLIPSE, 50, 50, 25.0, 25.0],
      [VECTOR_ELLIPSE, 50, 50, 37.5, 37.5]
    ] :
    [
      [VECTOR_ELLIPSE, 50, 50, 45.0, 45.0]
    ]

    const angleGrad = 30.0
    local angle = PI * angleGrad / 180.0
    local dashCount = 360.0 / angleGrad
    for(local i = 0; i < dashCount; ++i) {
      commands.append([
        VECTOR_LINE, 50, 50,
        50 + cos(i * angle) * 50.0,
        50 + sin(i * angle) * 50.0
      ])
    }
    return {
      watch = HasDistanceScale
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = defLineWidth
      color = isColorOrWhite(color)
      fillColor = 0
      size
      commands = commands
    }
  }

  return {
    children = [
      circle
      gridSecondary
    ]
  }
}

local function B_ScopeAzimuthComponent(size, valueWatched, distWatched, halfWidthWatched, color, lineWidth = hdpx(LINE_WIDTH)) {
  local showPart1 = (!distWatched || !halfWidthWatched) ? Watched(false) : Computed(@() distWatched.value == 1.0 && (halfWidthWatched.value ?? 0) > 0) //wtf this condition mean?

  local function part1() {
    local sectorCommands = [VECTOR_POLY, 50, 50]
    local step = PI * 0.05
    local angleCenter = AzimuthMin.value + AzimuthRange.value * valueWatched.value - PI * 0.5
    local angleFinish = angleCenter + halfWidthWatched.value
    local angle = angleCenter - halfWidthWatched.value

    while (angle <= angleFinish) {
      sectorCommands.append(50.0 + 50.0 * cos(angle))
      sectorCommands.append(50.0 + 50.0 * sin(angle))
      if (angle == angleFinish)
        break;
      angle += step
      if (angle > angleFinish)
        angle = angleFinish
    }

    return {
      watch = [valueWatched, AzimuthMin, halfWidthWatched]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = defLineWidth
      color
      fillColor = isColorOrWhite(color)
      opacity = 0.4
      size
      commands = [sectorCommands]
    }
  }

  local function part2() {
    local angle = AzimuthMin.value + AzimuthRange.value * valueWatched.value - PI * 0.5
    local distV = distWatched?.value
    local commands = distV!=null ? [VECTOR_LINE_DASHED] : [VECTOR_LINE]
    commands.append(
      50, 50,
      50.0 + 50.0 * (distV ?? 1.0) * cos(angle),
      50.0 + 50.0 * (distV ?? 1.0) * sin(angle)
    )
    if (distV!=null)
      commands.append(hdpx(10), hdpx(5))

    return {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(lineWidth)
      color = isColorOrWhite(color)
      size
      watch = [valueWatched, distWatched, AzimuthMin, AzimuthRange]
      commands = [commands]
    }
  }

  return @() {
    watch = showPart1
    size = SIZE_TO_CONTENT
    children = showPart1.value ? part1 : part2
  }
}

local rad2deg = 180.0 / PI

local function B_ScopeHalfLaunchRangeComponent(size, azimuthMin, azimuthMax, aamLaunchZoneDistMin, aamLaunchZoneDistMax, color) {
  return function(){
    local scanAngleStart = azimuthMin.value - PI * 0.5
    local scanAngleFinish = azimuthMax.value - PI * 0.5
    local scanAngleStartDeg = scanAngleStart * rad2deg
    local scanAngleFinishDeg = scanAngleFinish * rad2deg

    local commands = [
      [VECTOR_SECTOR, 50, 50, aamLaunchZoneDistMin.value * 50, aamLaunchZoneDistMin.value * 50, scanAngleStartDeg, scanAngleFinishDeg],
      [VECTOR_SECTOR, 50, 50, aamLaunchZoneDistMax.value * 50, aamLaunchZoneDistMax.value * 50, scanAngleStartDeg, scanAngleFinishDeg]
    ]

    local children = {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(4)
      color = isColorOrWhite(color)
      fillColor = 0
      size
      opacity = 0.42
      commands = commands
    }

    return styleLineForeground.__merge({
      children
      watch = [azimuthMin, azimuthMax, aamLaunchZoneDistMin, aamLaunchZoneDistMax ]
    })
  }
}


local B_ScopeSectorComponent = @(size, valueWatched, distWatched, halfWidthWatched, color) function() {
  local show = (distWatched==null || halfWidthWatched==null) ? Watched(false) : Computed(@() halfWidthWatched.value > 0)
  halfWidthWatched = halfWidthWatched ?? Watched(0.0)
  distWatched = distWatched ?? Watched(1.0)

  local function children() {
    local sectorCommands = [VECTOR_POLY, 50, 50]
    local step = PI * 0.05
    local angleCenter = AzimuthMin.value + AzimuthRange.value *
      (valueWatched?.value ?? 0.5) - PI * 0.5
    local angleFinish = angleCenter + halfWidthWatched.value
    local angle = angleCenter - halfWidthWatched.value

    while (angle <= angleFinish) {
      sectorCommands.append(50.0 + distWatched.value * 50 * cos(angle))
      sectorCommands.append(50.0 + distWatched.value * 50 * sin(angle))
      if (angle == angleFinish)
        break;
      angle += step
      if (angle > angleFinish)
        angle = angleFinish
    }

    return {
      watch = [valueWatched, distWatched, halfWidthWatched, AzimuthMin]
      rendObj = ROBJ_VECTOR_CANVAS
      color
      lineWidth = defLineWidth
      fillColor = isColorOrWhite(color)
      opacity = 0.2
      size
      commands = [sectorCommands]
    }
  }

  return {
    watch = show
    size = SIZE_TO_CONTENT
    children = show.value ? children : null
  }
}

local angularGateBeamWidthMin = 2.0 * 0.0174

local angularGateWidthMultMinPolar = 4.0
local angularGateWidthMultMaxPolar = 6.0
local angularGateWidthMultMinDistanceRelPolar = 0.06
local angularGateWidthMultMaxDistanceRelPolar = 0.33

local function calcAngularGateWidthPolar(distance_rel, azimuth_half_width) {
  if (azimuth_half_width > 0.17)
    return 2.0
  local blend = min((distance_rel - angularGateWidthMultMinDistanceRelPolar) / (angularGateWidthMultMaxDistanceRelPolar - angularGateWidthMultMinDistanceRelPolar), 1.0)
  return angularGateWidthMultMinPolar * blend + angularGateWidthMultMaxPolar * (1.0 - blend)
}

local createTargetOnRadarPolar = @(index, radius, size, color) function() {

  local res = { watch = [HasAzimuthScale, AzimuthMin, AzimuthRange, HasDistanceScale] }

  local target = targets[index]

  if (target == null)
    return res

  local angle = HasAzimuthScale.value ? AzimuthMin.value + AzimuthRange.value * target.azimuthRel - PI * 0.5 : -PI * 0.5
  local angularWidth = AzimuthRange.value * target.azimuthWidthRel
  local angleLeftDeg = (angle - 0.5 * angularWidth) * 180.0 / PI
  local angleRightDeg = (angle + 0.5 * angularWidth) * 180.0 / PI

  local distanceRel = HasDistanceScale.value ? target.distanceRel : 0.9
  local radialWidthRel = HasAzimuthScale.value ? target.distanceWidthRel : 1.0

  local selectionFrame = null

  local azimuthHalfWidth = IsRadar2Visible.value ? AzimuthHalfWidth2.value : AzimuthHalfWidth.value
  local angularGateWidthMult = calcAngularGateWidthPolar(distanceRel, azimuthHalfWidth)
  local angularGateWidth = angularGateWidthMult * 2.0 * max(azimuthHalfWidth, angularGateBeamWidthMin)
  local angleGateLeft  = angle - 0.5 * angularGateWidth
  local angleGateRight = angle + 0.5 * angularGateWidth
  if (AzimuthMax.value - AzimuthMin.value < PI) {
    angleGateLeft  = max(angleGateLeft, AzimuthMin.value - PI * 0.5)
    angleGateRight = min(angleGateRight, AzimuthMax.value - PI * 0.5)
  }
  local angleGateLeftDeg = angleGateLeft * 180.0 / PI
  local angleGateRightDeg = angleGateRight * 180.0 / PI
  local distanceGateWidthRel = max(DistanceGateWidthRel.value, distanceGateWidthRelMin) * distanceGateWidthMult
  local radiusInner = distanceRel - 0.5 * distanceGateWidthRel
  local radiusOuter = distanceRel + 0.5 * distanceGateWidthRel
  local frameCommands = []
  if (target.isDetected || target.isSelected) {
    frameCommands.append(
      [ VECTOR_LINE,
        50 + 50 * cos(angleGateLeft) * radiusInner,
        50 + 50 * sin(angleGateLeft) * radiusInner,
        50 + 50 * cos(angleGateLeft) * radiusOuter,
        50 + 50 * sin(angleGateLeft) * radiusOuter
      ],
      [ VECTOR_LINE,
        50 + 50 * cos(angleGateRight) * radiusInner,
        50 + 50 * sin(angleGateRight) * radiusInner,
        50 + 50 * cos(angleGateRight) * radiusOuter,
        50 + 50 * sin(angleGateRight) * radiusOuter
      ]
    )
  }

  if (target.isSelected) {
    frameCommands.append(
      [ VECTOR_SECTOR, 50, 50, 50 * radiusInner, 50 * radiusInner, angleGateLeftDeg, angleGateRightDeg ],
      [ VECTOR_SECTOR, 50, 50, 50 * radiusOuter, 50 * radiusOuter, angleGateLeftDeg, angleGateRightDeg ]
    )
  }

  if (!target.isEnemy) {
    local iffMarkDistanceRel = distanceRel + iffDistRelMult * distanceGateWidthRel
    frameCommands.append(
      [ VECTOR_SECTOR, 50, 50, 50 * iffMarkDistanceRel, 50 * iffMarkDistanceRel, angleLeftDeg, angleRightDeg ]
    )
  }

  selectionFrame = target.isSelected
    ? {
      rendObj = ROBJ_VECTOR_CANVAS
      size
      lineWidth = hdpx(3)
      color = isColorOrWhite(color)
      fillColor = 0
      pos = [radius, radius]
      commands = frameCommands
      animations = [{ prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.5, play = selectedTargetBlinking.value, loop = true, easing = InOutSine, trigger = frameTrigger}]
    }
    : {
      rendObj = ROBJ_VECTOR_CANVAS
      size
      lineWidth = hdpx(3)
      color = isColorOrWhite(color)
      fillColor = 0
      pos = [radius, radius]
      commands = frameCommands
    }

  return res.__update({
    rendObj = ROBJ_VECTOR_CANVAS
    size
    lineWidth = 100 * radialWidthRel
    color = isColorOrWhite(color)
    fillColor = 0
    opacity = (1.0 - targets[index].ageRel)
    commands = [
      [ VECTOR_SECTOR, 50, 50, 50 * distanceRel, 50 * distanceRel, angleLeftDeg, angleRightDeg ]
    ]
    transform = {
      pivot = [0.5, 0.5]
      translate = [
        -radius,
        -radius
      ]
    }
    children = selectionFrame
  })
}

local B_ScopeCircleMarkers = @(size, color) function() {

  local res = { watch = [IsRadarVisible, IsRadar2Visible, IndicationForCollapsedRadar, HasDistanceScale,
                         HasAzimuthScale, ScanAzimuthMax, ScanAzimuthMin, ScanElevationMax, ScanElevationMin, ScanPatternsMax] }
  local hiddenText = (!IsRadarVisible.value && !IsRadar2Visible.value && !IndicationForCollapsedRadar.value)

  if (hiddenText)
    return res

  local isCollapsed = !IsRadarVisible.value && !IsRadar2Visible.value
  return res.__update({
    size = [offsetScaleFactor * size[0], offsetScaleFactor * size[1]]
    children = [
      !HasAzimuthScale.value || ScanAzimuthMax.value <= ScanAzimuthMin.value
        ? null
        : @() styleText.__merge({
          watch = [ HasAzimuthScale, ScanAzimuthMin, ScanAzimuthMax,
                    ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
          rendObj = ROBJ_DTEXT
          pos = [-size[0] * 0.30, size[1] * 0.5 + hdpx(5)]
          hplace = ALIGN_LEFT
          text = "".concat(floor((ScanAzimuthMax.value - ScanAzimuthMin.value) * radToDeg + 0.5),
                   ::loc("measureUnits/deg"), "x",
                   floor((ScanElevationMax.value - ScanElevationMin.value) * radToDeg + 0.5),
                   ::loc("measureUnits/deg"),
                   (ScanPatternsMax.value > 1
                      ? "*"
                      : " "))
      }),
      !HasDistanceScale.value ? null
        : @() styleText.__merge({
          rendObj = ROBJ_DTEXT
          pos = [size[0] + hdpx(4), size[1] * 0.5 + hdpx(5)]
          watch = [VelocitySearch, DistanceMax, DistanceScalesMax ]
          text = "".concat(VelocitySearch.value
                    ? ::cross_call.measureTypes.SPEED.getMeasureUnitsText(
                      DistanceMax.value, true, false, false)
                    : ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(
                      DistanceMax.value * 1000.0, true, false, false),
                    (DistanceScalesMax.value > 1
                      ? "*"
                      : " "))
      }),
      isCollapsed ? null
        : styleText.__merge({
          rendObj = ROBJ_DTEXT
          pos = [size[0] * 0.5 - hdpx(4), -hdpx(18)]
          text = "".concat("0", ::loc("measureUnits/deg"))
      }),
      styleText.__merge({
        rendObj = ROBJ_DTEXT
        pos = [size[0] + hdpx(4), size[1] * 0.5 - hdpx(15)]
        text = "".concat("90", ::loc("measureUnits/deg"))
      }),
      styleText.__merge({
        rendObj = ROBJ_DTEXT
        pos = [size[0] * 0.5 - hdpx(18), size[1] + hdpx(4)]
        text = "".concat("180", ::loc("measureUnits/deg"))
      }),
      styleText.__merge({
        rendObj = ROBJ_DTEXT
        pos = [-size[0] * 0.15, size[1] * 0.5 - hdpx(15)]
        hplace = ALIGN_LEFT
        text = "".concat("270", ::loc("measureUnits/deg"))
      }),
      isCollapsed ? @() { watch = [IsRadarVisible, IsRadar2Visible] }
      : makeRadarModeText({
          pos = [size[0] * (0.5 - 0.15), -hdpx(20)]
        }, color),
      isCollapsed ? @() { watch = [IsRadarVisible, IsRadar2Visible] }
      : makeRadar2ModeText({
          pos = [size[0] * (0.5 + 0.05), -hdpx(20)]
        }, color),
      noiseSignal(
        [size[0] * 0.06, size[0] * 0.06],
        [size[0] * (0.5 - 0.30), -hdpx(25)],
        [size[0] * (0.5 + 0.20), -hdpx(25)],
        color)
    ]
  })
}

local function B_Scope(size, color) {
  local bkg = B_ScopeBackground(size, color)
  local azComp1 = B_ScopeAzimuthComponent(size, AimAzimuth, null, null, color, AIM_LINE_WIDTH)
  local azComp2 = B_ScopeAzimuthComponent(size, TurretAzimuth, null, null, color, TURRET_LINE_WIDTH)
  local sectorComp = B_ScopeSectorComponent(size, TurretAzimuth, TargetRadarDist, TargetRadarAzimuthWidth, color)
  local azComp3 = B_ScopeAzimuthComponent(size, Azimuth, Distance, AzimuthHalfWidth, color)
  local azComp4 = B_ScopeAzimuthComponent(size, Azimuth2, Distance2, AzimuthHalfWidth2, color)
  local tgts = targetsComponent(size, createTargetOnRadarPolar, color)
  local sizeBScope = [size[0] + hdpx(2), size[1] + hdpx(2)]
  local markers = B_ScopeCircleMarkers(size, color)

  return function() {
    local children = [ bkg, azComp1, azComp2, sectorComp ]
    if (IsRadarVisible.value)
      children.append(azComp3)
    if (IsRadar2Visible.value)
      children.append(azComp4)
    children.append(tgts)
    return {
      watch = [IsRadarVisible, IsRadar2Visible]
       children = [
          {
            size = sizeBScope
            clipChildren = true
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            children
          },
          markers
      ]
    }
  }
}

local function B_ScopeHalfBackground(size, color) {
  local angleLimStartS = AzimuthMin.value - PI * 0.5
  local angleLimFinishS = AzimuthMax.value - PI * 0.5

  local function circle() {
    local angleLimStart = angleLimStartS
    local angleLimFinish = angleLimFinishS
    local angleLimStartDeg = angleLimStart * rad2deg
    local angleLimFinishDeg = angleLimFinish * rad2deg
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      size = size
      watch = [AzimuthMin, AzimuthMax]
      color
      fillColor = areaBackgroundColor
      lineWidth = hdpx(LINE_WIDTH)
      commands = [
        [VECTOR_SECTOR, 50, 50, 50, 50, angleLimStartDeg, angleLimFinishDeg],
        [
          VECTOR_LINE, 50, 50,
          50 + cos(angleLimStart) * 50.0,
          50 + sin(angleLimStart) * 50.0
        ],
        [
          VECTOR_LINE, 50, 50,
          50 + cos(angleLimFinish) * 50.0,
          50 + sin(angleLimFinish) * 50.0
        ]
      ]
    }
  }

  local scanAngleStartS = Computed(@() ScanAzimuthMin.value - PI * 0.5)
  local scanAngleFinishS = Computed(@() ScanAzimuthMax.value - PI * 0.5)

  const angleGrad = 15.0
  local angle = PI * angleGrad / 180.0
  local dashCount = 360.0 / angleGrad
  local defSecGrid = []
  local gridSecondaryCom = Computed(function(){
    local scanAngleStart = scanAngleStartS.value
    local scanAngleFinish = scanAngleFinishS.value
    local scanAngleStartDeg = scanAngleStart * rad2deg
    local scanAngleFinishDeg = scanAngleFinish * rad2deg

    local res = HasDistanceScale.value
    ? [
        [VECTOR_SECTOR, 50, 50, 12.5, 12.5, scanAngleStartDeg, scanAngleFinishDeg],
        [VECTOR_SECTOR, 50, 50, 25.0, 25.0, scanAngleStartDeg, scanAngleFinishDeg],
        [VECTOR_SECTOR, 50, 50, 37.5, 37.5, scanAngleStartDeg, scanAngleFinishDeg],
      ]
    : defSecGrid

    for(local i = 0; i < dashCount; ++i) {
      local currAngle = i * angle
      if (currAngle < scanAngleStart + 2 * PI || currAngle > scanAngleFinish + 2 * PI)
        continue

      res.append([
        VECTOR_LINE, 50, 50,
        50 + cos(currAngle) * 50.0,
        50 + sin(currAngle) * 50.0
      ])
    }
    return res
  })

  local gridSecondary = @() {
    watch = gridSecondaryCom
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = defLineWidth
    color = isColorOrWhite(color)
    fillColor = 0
    size
    commands = gridSecondaryCom.value
  }

  local function gridMain(){
    local scanAngleStart = scanAngleStartS.value
    local scanAngleFinish = scanAngleFinishS.value

    return {
      watch = [scanAngleStartS, scanAngleFinishS]
      rendObj = ROBJ_VECTOR_CANVAS
      size
      color = isColorOrWhite(color)
      lineWidth = hdpx(2 * LINE_WIDTH)
      commands = [
        [
          VECTOR_LINE, 50, 50,
          50 + cos(scanAngleStart) * 50.0,
          50 + sin(scanAngleStart) * 50.0
        ],
        [
          VECTOR_LINE, 50, 50,
          50 + cos(scanAngleFinish) * 50.0,
          50 + sin(scanAngleFinish) * 50.0
        ]
      ]
    }
  }
  return function() {
    return {
      children = [
        circle
        gridSecondary
        gridMain
      ]
    }
  }
}

local B_ScopeHalfCircleMarkers = @(size, color, fontScale) function() {

  local res = { watch = [IsRadarVisible, IsRadar2Visible, IndicationForCollapsedRadar, HasDistanceScale,
                         HasAzimuthScale, ScanAzimuthMax, ScanAzimuthMin] }

  local hiddenText = !IsRadarVisible.value && !IsRadar2Visible.value && !IndicationForCollapsedRadar.value

  if (hiddenText)
    return res

  local scanRangeX = size[0] * 0.47
  local scanRangeY = size[1] * 0.51
  local scanYaw = size[0] * 0.58
  local scanPitch = size[0] * 0.51
  return res.__update({
    size = [offsetScaleFactor * size[0], offsetScaleFactor * size[1]]
    children = [
      {
        size = [0, SIZE_TO_CONTENT]
        children = !HasAzimuthScale.value || ScanAzimuthMax.value <= ScanAzimuthMin.value ? null
          : @() styleLineForeground.__merge({
            watch = [ ScanAzimuthMin, ScanAzimuthMax,
                      ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
            rendObj = ROBJ_DTEXT
            size = SIZE_TO_CONTENT
            color
            fontSize = hudFontHgt * fontScale
            pos = [scanRangeX, scanRangeY]
            hplace = ALIGN_RIGHT
            text = "".concat( floor((ScanAzimuthMax.value - ScanAzimuthMin.value) * radToDeg + 0.5),
                            ::loc("measureUnits/deg"), "x",
                            floor((ScanElevationMax.value - ScanElevationMin.value) * radToDeg + 0.5),
                            ::loc("measureUnits/deg"),
                            (ScanPatternsMax.value > 1
                              ? "*"
                              : " "))
          })
      }
      !HasDistanceScale.value ? null
        : @() styleLineForeground.__merge({
          watch = [ VelocitySearch, DistanceMax, DistanceScalesMax ]
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          color
          fontSize = hudFontHgt * fontScale
          pos = [scanYaw, scanPitch]
          text =  "".concat(VelocitySearch.value
                    ? ::cross_call.measureTypes.SPEED.getMeasureUnitsText(
                      DistanceMax.value, true, false, false)
                    : ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(
                      DistanceMax.value * 1000.0, true, false, false),
                    (DistanceScalesMax.value > 1
                      ? "*"
                      : " "))
      })
      makeRadarModeText({
          pos = [size[0] * (0.5 - 0.15), -hdpx(20)]
        }, color)
      makeRadar2ModeText({
          pos = [size[0] * (0.5 + 0.05), -hdpx(20)]
        }, color)
      noiseSignal(
        [size[0] * 0.06, size[1] * 0.06],
        [size[0] * (0.5 - 0.30), -hdpx(25)],
        [size[0] * (0.5 + 0.20), -hdpx(25)],
        color)
    ]
  })
}

local function B_ScopeHalf(size, color, fontScale) {
  local bkg = B_ScopeHalfBackground(size, color)
  local sector = B_ScopeSectorComponent(size, null, TargetRadarDist, TargetRadarAzimuthWidth, color)
  local reflections = @(){

    size
    color = isColorOrWhite(color)
    rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
    isSquare = false
    xFragments = 20
    yFragments = 8
  }

  local sizeBScopeHalf = [size[0] + hdpx(2), 0.5 * size[1]]
  local markers = B_ScopeHalfCircleMarkers(size, color, fontScale)
  local az1 = B_ScopeAzimuthComponent(size, Azimuth, Distance, AzimuthHalfWidth, color)
  local az2 = B_ScopeAzimuthComponent(size, Azimuth2, Distance2, AzimuthHalfWidth2, color)
  local aamLaunch = B_ScopeHalfLaunchRangeComponent(size, AzimuthMin, AzimuthMax,
                                                      AamLaunchZoneDistMin, AamLaunchZoneDistMax, color)
  local tgts = targetsComponent(size, createTargetOnRadarPolar, color)
  return function() {
    local children = [ bkg, sector, reflections ]
    if (IsRadarVisible.value)
      children.append(az1)
    if (IsRadar2Visible.value)
      children.append(az2)
    if (IsAamLaunchZoneVisible.value && HasDistanceScale.value)
      children.append(aamLaunch)
    children.append(tgts)
    return {
      watch = [IsRadarVisible, IsRadar2Visible, HasDistanceScale, IsAamLaunchZoneVisible]
      children = [
        {
          size = sizeBScopeHalf
          pos = [0, 0]
          halign = ALIGN_CENTER
          clipChildren = true
          children
        },
        markers
      ]
    }
  }
}

local function C_ScopeSquareBackground(size, color) {

  local back = {
    rendObj = ROBJ_SOLID
    size
    color = areaBackgroundColor
  }

  local frame = {
    rendObj = ROBJ_VECTOR_CANVAS
    size
    color
    fillColor = isColorOrWhite(color)
    commands = [
      [VECTOR_LINE, 0, 0, 0, 100],
      [VECTOR_LINE, 0, 100, 100, 100],
      [VECTOR_LINE, 100, 100, 100, 0],
      [VECTOR_LINE, 100, 0, 0, 0]
    ]
  }

  local offsetW = Computed(@() 100 * (0.5 - (0.0 - ElevationMin.value) * ElevationRangeInv.value))
  local function crosshair() {
    return {
      watch = offsetW
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(3)
      color = isColorOrWhite(color)
      size
      opacity = 0.62
      commands = [
        [VECTOR_LINE, 50, 0, 50, 100],
        [VECTOR_LINE, 0, 50 + offsetW.value, 100, 50 + offsetW.value],
      ]
    }
  }

  return function() {
    local azimuthRangeInv   = AzimuthRangeInv.value
    local elevationRangeInv = ElevationRangeInv.value

    local scanAzimuthMinRel = ScanAzimuthMin.value * azimuthRangeInv
    local scanAzimuthMaxRel = ScanAzimuthMax.value * azimuthRangeInv
    local scanElevationMinRel = (ScanElevationMin.value - ElevationHalfWidth.value) * elevationRangeInv
    local scanElevationMaxRel = (ScanElevationMax.value + ElevationHalfWidth.value) * elevationRangeInv
    local finalColor = isColorOrWhite(color)
    local offset = offsetW.value
    local gridMain = {
      rendObj = ROBJ_VECTOR_CANVAS
      size
      color = finalColor
      fillColor = 0
      lineWidth = hdpx(2*LINE_WIDTH)
      opacity = 0.7
      commands = [
        [
          VECTOR_RECTANGLE,
          50 + scanAzimuthMinRel * 100, 100 - (50 + scanElevationMaxRel * 100) + offset,
          (scanAzimuthMaxRel - scanAzimuthMinRel) * 100, (scanElevationMaxRel - scanElevationMinRel) * 100
        ]
      ]
    }

    local gridSecondaryCommands = []

    local azimuthRelStep = PI / 12.0 * azimuthRangeInv
    local azimuthRel = 0.0
    while (azimuthRel > ScanAzimuthMin.value * azimuthRangeInv) {
      gridSecondaryCommands.append([
        VECTOR_LINE,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMaxRel * 100) + offset,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMinRel * 100) + offset
      ])
      azimuthRel -= azimuthRelStep
    }
    azimuthRel = 0.0
    while (azimuthRel < ScanAzimuthMax.value * azimuthRangeInv) {
      gridSecondaryCommands.append([
        VECTOR_LINE,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMaxRel * 100) + offset,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMinRel * 100) + offset
      ])
      azimuthRel += azimuthRelStep
    }

    local elevationRelStep = PI / 12.0 * elevationRangeInv
    local elevationRel = 0.0
    while (elevationRel > ScanElevationMin.value * elevationRangeInv) {
      gridSecondaryCommands.append([
        VECTOR_LINE,
        50 + scanAzimuthMinRel * 100, 100 - (50 + elevationRel * 100) + offset,
        50 + scanAzimuthMaxRel * 100, 100 - (50 + elevationRel * 100) + offset
      ])
      elevationRel -= elevationRelStep
    }
    elevationRel = 0.0
    while (elevationRel < ScanElevationMax.value * elevationRangeInv) {
      gridSecondaryCommands.append([
        VECTOR_LINE,
        50 + scanAzimuthMinRel * 100, 100 - (50 + elevationRel * 100) + offset,
        50 + scanAzimuthMaxRel * 100, 100 - (50 + elevationRel * 100) + offset
      ])
      elevationRel += elevationRelStep
    }

    local gridSecondary ={
      rendObj = ROBJ_VECTOR_CANVAS
      size
      color
      lineWidth = defLineWidth
      opacity = 0.42
      commands = gridSecondaryCommands
    }

    local children = [back, frame, crosshair, gridMain, gridSecondary]
    return styleLineForeground.__merge({
      watch = [ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax, ElevationHalfWidth,
               AzimuthRangeInv, ElevationRangeInv]
      size = SIZE_TO_CONTENT
      children
    })
  }
}

local function C_ScopeSquareAzimuthComponent(size, azimuthWatched, elevatonWatched, halfAzimuthWidthWatched, halfElevationWidthWatched, color) {
  return function() {
    local azimuthRange = AzimuthRange.value
    local halfAzimuthWidth   = 100.0 * (azimuthRange > 0 ? halfAzimuthWidthWatched.value / azimuthRange : 0)
    local halfElevationWidth = 100.0 * (azimuthRange > 0 ? halfElevationWidthWatched.value * ElevationRangeInv.value : 0)

    local children = @() {

      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = defLineWidth
      color
      fillColor = isColorOrWhite(color)
      opacity = 0.6
      size
      commands = [
        [
          VECTOR_POLY,
          -halfAzimuthWidth, -halfElevationWidth,  halfAzimuthWidth, -halfElevationWidth,
           halfAzimuthWidth,  halfElevationWidth, -halfAzimuthWidth,  halfElevationWidth
        ]
      ]
    }

    return styleLineForeground.__merge({
      size = SIZE_TO_CONTENT
      children
      watch = [azimuthWatched, elevatonWatched, halfAzimuthWidthWatched, halfElevationWidthWatched]
      pos = [azimuthWatched.value * size[0], (1.0 - elevatonWatched.value) * size[1]]
    })
  }
}

local angularGateWidthMult = 4

local createTargetOnRadarCScopeSquare = @(index, radius, size, color) function() {

  local res = { watch = [HasAzimuthScale, AzimuthHalfWidth, AzimuthRange, ElevationHalfWidth, ElevationRangeInv] }

  local target = targets[index]

  if (target == null)
    return res

  local opacity = (1.0 - target.ageRel) * target.signalRel

  if (!target.isDetected) {
    local inSelectedTargetRangeGate = false
    foreach(secondTargetId, secondTarget in targets) {
      if (secondTarget != null &&
          secondTargetId != index && secondTarget.isDetected &&
          fabs(target.distanceRel - secondTarget.distanceRel) < 0.05) {
        inSelectedTargetRangeGate = true
        break
      }
    }
    if (!inSelectedTargetRangeGate)
      opacity = 0
  }

  if (!target.isSelected && !target.isDetected && target.isEnemy)
    return res

  local azimuthRel = HasAzimuthScale.value ? target.azimuthRel : 0.0
  local azimuthWidthRel = target.azimuthWidthRel
  local azimuthLeft = azimuthRel - azimuthWidthRel * 0.5

  local elevationRel = target.elevationRel
  local elevationWidthRel = target.elevationWidthRel
  local elevationLowerRel = elevationRel - elevationWidthRel * 0.5

  local frameCommands = []
  local azimuthGateWidthRel = angularGateWidthMult * 2.0 * max(AzimuthHalfWidth.value, angularGateBeamWidthMin) / AzimuthRange.value
  local azimuthGateLeftRel = azimuthRel - 0.5 * azimuthGateWidthRel
  local azimuthGateRightRel = azimuthRel + 0.5 * azimuthGateWidthRel
  local elevationGateWidthRel = angularGateWidthMult * 2.0 * max(ElevationHalfWidth.value, angularGateBeamWidthMin) * ElevationRangeInv.value
  local elevationGateLowerRel = elevationRel - 0.5 * elevationGateWidthRel
  local elevationGateUpperRel = elevationRel + 0.5 * elevationGateWidthRel

  if (target.isDetected || target.isSelected) {
    frameCommands.append(
      [ VECTOR_LINE,
        100 * azimuthGateLeftRel,
        100 * (1.0 - elevationGateLowerRel),
        100 * azimuthGateLeftRel,
        100 * (1.0 - elevationGateUpperRel)
      ],
      [ VECTOR_LINE,
        100 * azimuthGateRightRel,
        100 * (1.0 - elevationGateLowerRel),
        100 * azimuthGateRightRel,
        100 * (1.0 - elevationGateUpperRel)
      ]
    )
  }

  if (target.isSelected) {
    frameCommands.append(
      [ VECTOR_LINE,
        100 * azimuthGateLeftRel,
        100 * (1.0 - elevationGateLowerRel),
        100 * azimuthGateRightRel,
        100 * (1.0 - elevationGateLowerRel)
      ],
      [ VECTOR_LINE,
        100 * azimuthGateLeftRel,
        100 * (1.0 - elevationGateUpperRel),
        100 * azimuthGateRightRel,
        100 * (1.0 - elevationGateUpperRel)
      ]
    )
  }

  local selectionFrame = {
    rendObj = ROBJ_VECTOR_CANVAS
    size
    lineWidth = hdpx(3)
    color = isColorOrWhite(color)
    fillColor = 0
    pos = [radius, radius]
    commands = frameCommands
  }
  if (target.isSelected)
    selectionFrame.__update({
      animations = [{ prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.5,
        play = selectedTargetBlinking.value, loop = true, easing = InOutSine,
        trigger = frameTrigger
      }]
      key = selectedTargetBlinking
    })

  return res.__update({
    rendObj = ROBJ_VECTOR_CANVAS
    size
    color = isColorOrWhite(color)
    fillColor = isColorOrWhite(color)
    opacity = opacity
    commands = [
      [ VECTOR_RECTANGLE,
        100 * azimuthLeft,
        100 * (1.0 - elevationLowerRel),
        100 * azimuthWidthRel,
        100 * -elevationWidthRel
      ]
    ]
    transform = {
      pivot = [0.5, 0.5]
      translate = [
        -radius,
        -radius
      ]
    }
    children = selectionFrame
  })
}

local C_ScopeSquareMarkers = @(size, color) function() {

  local res = { watch = [ IsBScopeVisible, HasAzimuthScale, ScanAzimuthMax, ScanAzimuthMin, HasDistanceScale ] }

  return res.__update({
    size = [offsetScaleFactor * size[0], offsetScaleFactor * size[1]]
    children = [
      IsBScopeVisible.value || !HasAzimuthScale.value || ScanAzimuthMax.value <= ScanAzimuthMin.value
      ? null
      : @() {
        watch = [ScanAzimuthMin, ScanAzimuthMax,
          ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
        rendObj = ROBJ_DTEXT
        pos = [0, - hdpx(20)]
        color
        text = "".concat(floor((ScanAzimuthMax.value - ScanAzimuthMin.value) * radToDeg + 0.5),
                ::loc("measureUnits/deg"),
                "x",
                floor((ScanElevationMax.value - ScanElevationMin.value) * radToDeg + 0.5),
                ::loc("measureUnits/deg"),
                (ScanPatternsMax.value > 1 ? "*" : " "))
      },
      IsBScopeVisible.value || !HasDistanceScale.value ? null
      : @() {
        watch = [VelocitySearch, DistanceMax, DistanceScalesMax ]
        rendObj = ROBJ_DTEXT
        color
        pos = [size[0] * 0.75, -hdpx(20)]
        text = "".concat(VelocitySearch.value
                ? ::cross_call.measureTypes.SPEED.getMeasureUnitsText(DistanceMax.value, true, false, false)
                : ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMax.value * 1000.0, true, false, false),
                (DistanceScalesMax.value > 1 ? "*" : " "))
      },
      @() styleLineForeground.__merge({
        watch = ElevationMax
        rendObj = ROBJ_DTEXT
        color
        pos = [size[0] + hdpx(4), hdpx(4)]
        text = "".concat(floor(ElevationMax.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      }),
      @() styleLineForeground.__merge({
        watch = [ ElevationMin, ElevationRangeInv ]
        color
        rendObj = ROBJ_DTEXT
        pos = [size[0] + hdpx(4), (1.0 - (0.0 - ElevationMin.value) * ElevationRangeInv.value) * size[1] - hdpx(4)]
        text = "".concat("0", ::loc("measureUnits/deg"))
      }),
      @() styleLineForeground.__merge({
        watch = ElevationMin
        rendObj = ROBJ_DTEXT
        color
        pos = [size[0] + hdpx(4), size[1] - hdpx(20)]
        text = "".concat(floor(ElevationMin.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      }),
      @() styleLineForeground.__merge({
        watch = AzimuthMin
        rendObj = ROBJ_DTEXT
        pos = [hdpx(4), hdpx(4)]
        color = isColorOrWhite(color)
        text = "".concat(floor(AzimuthMin.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      }),
      {
        size = [size[0], SIZE_TO_CONTENT]
        children = @() styleLineForeground.__merge({
          watch = AzimuthMax
          rendObj = ROBJ_DTEXT
          pos = [-hdpx(4), hdpx(4)]
          color = isColorOrWhite(color)
          hplace = ALIGN_RIGHT
          text = "".concat(floor(AzimuthMax.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
        })
      },
      IsBScopeVisible.value ? null
      : makeRadarModeText({
          pos = [size[0] * 0.5, -hdpx(20)]
        }, color),
      IsBScopeVisible.value ? null
      : makeRadar2ModeText({
          pos = [size[0] * 0.5, -hdpx(50)]
        }, color)
    ]
  })
}

local function C_Scope(size, color) {
  local bkg = C_ScopeSquareBackground(size, color)
  local azim1 = C_ScopeSquareAzimuthComponent(size, Azimuth, Elevation, AzimuthHalfWidth, ElevationHalfWidth, color)
  local azim2 = C_ScopeSquareAzimuthComponent(size, Azimuth2, Elevation2, AzimuthHalfWidth2, ElevationHalfWidth2, color)
  local tgts = targetsComponent(size, createTargetOnRadarCScopeSquare, color)
  local markers = C_ScopeSquareMarkers(size, color)

  return function() {
    local children = [bkg]
    if (IsRadarVisible.value)
      children.append(azim1)
    if (IsRadar2Visible.value)
      children.append(azim2)
    children.append(tgts)

    return {
      watch = [IsRadarVisible, IsRadar2Visible]
      children = [
        {
          clipChildren = true
          children
        }
        markers
      ]
    }
  }
}

local mkRadarTgtsDist = @(dist, id, width, color) styleText.__merge({
  rendObj = ROBJ_DTEXT
  color
  size = [width * 4, SIZE_TO_CONTENT]
  pos = [width + hdpx(5), 0]
  fontSize = hudFontHgt
  fontFxFactor = min(hdpx(8), 8)
  text = (dist != null && dist > 0.0) ? ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(dist) : ""
})

local mkRadarTgtsSpd = @(id, width, color) styleText.__merge({
  rendObj = ROBJ_DTEXT
  color
  size = [width * 4, SIZE_TO_CONTENT]
  pos = [width + hdpx(5), hdpx(35) * sh(100) / 1080]
  fontSize = hudFontHgt
  fontFxFactor = min(hdpx(8), 8)
  animations = [{ prop = AnimProp.opacity, from = 0.42, to = 1, duration = 0.5,
    play = selectedTargetBlinking.value, loop = true, easing = InOutSine, trigger = speedTargetTrigger
  }]
  behavior = Behaviors.RtPropUpdate
  function update() {
    local spd = screenTargets?[id]?.speed
    return {
      text = (spd != null && spd > -3000.0)
        ?  ::cross_call.measureTypes.CLIMBSPEED.getMeasureUnitsText(spd) : ""
    }
  }
})

local createTargetOnScreen = @(id, width, color) function() {

  local dist = screenTargets?[id]?.dist

  local function updateTgtVelocityVector() {

    local target = screenTargets?[id]
    if (targetAspectEnabled.value && target != null && target.speed > -3000.0) {
      local targetLateralSpeed = target.azimuthRate * target.dist
      local targetRadialSpeed = target.speed - Speed.value
      local targetSpeed = sqrt(targetLateralSpeed * targetLateralSpeed + targetRadialSpeed * targetRadialSpeed)
      local targetSpeedInv = 1.0 / max(targetSpeed, 1.0)
      local innerRadius = 10
      local outerRadius = 50
      local speedToOuterRadius = 0.1
      return {
        commands = [
          [ VECTOR_ELLIPSE, 50, 50, innerRadius, innerRadius],
          [ VECTOR_LINE,
            50 + targetLateralSpeed * targetSpeedInv * innerRadius,
            50 + targetRadialSpeed  * targetSpeedInv * innerRadius,
            50 + targetLateralSpeed * targetSpeedInv * min(innerRadius + targetSpeed * speedToOuterRadius, outerRadius),
            50 + targetRadialSpeed  * targetSpeedInv * min(innerRadius + targetSpeed * speedToOuterRadius, outerRadius)
          ]
        ]
      }
    }
    return { commands = null }
  }

  return {
    size = [width, width]
    behavior = Behaviors.RtPropUpdate
    animations = [{ prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.5, play = selectedTargetBlinking.value, loop = true, easing = InOutSine, trigger = frameTrigger}]
    update = function() {
      local tgt = screenTargets?[id]
      return {
        transform = {
          translate = [
            (tgt?.x ?? -100) - 0.5 * width,
            (tgt?.y ?? -100) - 0.5 * width
          ]
        }
      }
    }
    children = [
       {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(4)
        color
        size = [width, width]
        commands = [
          [VECTOR_LINE, 0, 0, 0, 100],
          [VECTOR_LINE, 0, 100, 100, 100],
          [VECTOR_LINE, 100, 100, 100, 0],
          [VECTOR_LINE, 100, 0, 0, 0],
        ]
      },
      {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(4)
        color
        fillColor = 0
        pos = [-0.25 * width, width]
        size = [1.5 * width, 1.5 * width]
        behavior = Behaviors.RtPropUpdate
        update = updateTgtVelocityVector
      },
      mkRadarTgtsDist(dist, id, width, color),
      mkRadarTgtsSpd(id, width, color)
    ]
  }
}


local forestallRadius = hdpx(15)
local targetOnScreenWidth = hdpx(50)

local targetsOnScreenComponent = @(color) function() {

  if (!HasAzimuthScale.value)
    return null
  else if (!screenTargets)
    return null

  local targetsRes = []
  foreach (id, target in screenTargets) {
    if (!target)
      continue
    targetsRes.append(createTargetOnScreen(id, targetOnScreenWidth, color))
  }

  return {
    size = [sw(100), sh(50)]
    children = targetsRes
    watch = [ ScreenTargetsTrigger, HasAzimuthScale ]
  }
}

local forestallVisible = @(color) function() {

  return styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    color
    size = [2 * forestallRadius, 2 * forestallRadius]
    lineWidth = hdpx(2 * LINE_WIDTH)
    animations = [{ prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.5, play = selectedTargetBlinking.value, loop = true, easing = InOutSine, trigger = frameTrigger}]
    fillColor = 0
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [forestall.x - forestallRadius, forestall.y - forestallRadius]
      }
    }
  })
}

local forestallComponent = @(color) function() {
  return {
    size = [sw(100), sh(100)]
    children = IsForestallVisible.value ? forestallVisible(color) : null
    watch = IsForestallVisible
  }
}

local scanZoneAzimuthComponent = @(color) function() {


  if (!IsScanZoneAzimuthVisible.value)
    return { watch = IsScanZoneAzimuthVisible}

  local width = sw(100)
  local height = sh(100)

  local {x0,y0,x1,y1} = ScanZoneWatched.value
  local _x0 = (x0 + x1) * 0.5
  local _y0 = (y0 + y1) * 0.5
  local mw = 100 / width
  local mh = 100 / height
  local px0 = (x0 - _x0) * mw
  local py0 = (y0 - _y0) * mh
  local px1 = (x1 - _x0) * mw
  local py1 = (y1 - _y0) * mh

  local commands = [
    [ VECTOR_LINE, px0, py0, px1, py1 ]
  ]
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(4)
    watch = [ScanZoneWatched, IsScanZoneAzimuthVisible]
    opacity = 0.3
    fillColor = 0
    size = [width, height]
    color
    pos = [_x0, _y0]
    commands
  }
}

local scanZoneElevationComponent = @(color) function() {

  if (!IsScanZoneElevationVisible.value)
    return { watch = [IsScanZoneElevationVisible] }

  local width = sw(100)
  local height = sh(100)
  local mw = 100 / width
  local mh = 100 / height
  local {x2, x3, y2, y3} = ScanZoneWatched.value
  local _x0 = (x2 + x3) * 0.5
  local _y0 = (y2 + y3) * 0.5
  local px2 = (x2 - _x0) * mw
  local py2 = (y2 - _y0) * mh
  local px3 = (x3 - _x0) * mw
  local py3 = (y3 - _y0) * mh

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    opacity = 0.3
    watch = [ScanZoneWatched, IsScanZoneElevationVisible]
    lineWidth = hdpx(4)
    color
    fillColor = 0
    size = [width, height]
    pos = [(x2 + x3) * 0.5, (y2 + y3) * 0.5]
    commands = [[ VECTOR_LINE, px2, py2, px3, py3 ]]
  }
}

local lockZoneComponent = @(color) function() {

  local res =  { watch = [IsLockZoneVisible, LockZoneWatched] }
  if (!IsLockZoneVisible.value)
    return res.__update({
      animations = [{ prop = AnimProp.opacity, from = 0.0, to = 1, duration = 0.25, play = true, loop = true, easing = InOutSine}]})

  local width = sw(100)
  local height = sh(100)
  local mw = 100 / width
  local mh = 100 / height
  local corner = 0.1
  local lineWidth = hdpx(4)
  local size = [sw(100), sh(100)]

  local {x0, x1, x2, x3, y0, y1, y2, y3} = LockZoneWatched.value
  local _x0 = (x0 + x1 + x2 + x3) * 0.25
  local _y0 = (y0 + y1 + y2 + y3) * 0.25

  local px0 = (x0 - _x0) * mw
  local py0 = (y0 - _y0) * mh
  local px1 = (x1 - _x0) * mw
  local py1 = (y1 - _y0) * mh
  local px2 = (x2 - _x0) * mw
  local py2 = (y2 - _y0) * mh
  local px3 = (x3 - _x0) * mw
  local py3 = (y3 - _y0) * mh

  local commands = [
    [ VECTOR_LINE, px0, py0, px0 + (px1 - px0) * corner, py0 + (py1 - py0) * corner ],
    [ VECTOR_LINE, px0, py0, px0 + (px3 - px0) * corner, py0 + (py3 - py0) * corner ],

    [ VECTOR_LINE, px1, py1, px1 + (px2 - px1) * corner, py1 + (py2 - py1) * corner ],
    [ VECTOR_LINE, px1, py1, px1 + (px0 - px1) * corner, py1 + (py0 - py1) * corner ],

    [ VECTOR_LINE, px2, py2, px2 + (px3 - px2) * corner, py2 + (py3 - py2) * corner ],
    [ VECTOR_LINE, px2, py2, px2 + (px1 - px2) * corner, py2 + (py1 - py2) * corner ],

    [ VECTOR_LINE, px3, py3, px3 + (px0 - px3) * corner, py3 + (py0 - py3) * corner ],
    [ VECTOR_LINE, px3, py3, px3 + (px2 - px3) * corner, py3 + (py2 - py3) * corner ]
  ]

  return res.__update({
    animations = [{ prop = AnimProp.opacity, from = 0.0, to = 1, duration = 0.25, play = true, loop = true, easing = InOutSine}]
    pos = [_x0, _y0 ]
    rendObj = ROBJ_VECTOR_CANVAS
    color
    lineWidth
    fillcolor = color
    size
    commands
  })
}

local function getForestallTargetLineCoords() {
  local p1 = {
    x = forestall.x
    y = forestall.y
  }
  local p2 = {
    x = selectedTarget.x
    y = selectedTarget.y
  }

  local resPoint1 = {
    x = 0
    y = 0
  }
  local resPoint2 = {
    x = 0
    y = 0
  }

  local dx = p1.x - p2.x
  local dy = p1.y - p2.y
  local absDx = fabs(dx)
  local absDy = fabs(dy)

  if (absDy >= absDx) {
    resPoint2.x = p2.x
    resPoint2.y = p2.y + (dy > 0 ? 0.5 : -0.5) * hdpx(50)
  }
  else {
    resPoint2.y = p2.y
    resPoint2.x = p2.x + (dx > 0 ? 0.5 : -0.5) * hdpx(50)
  }

  local vecDx = p1.x - resPoint2.x
  local vecDy = p1.y - resPoint2.y
  local vecLength = sqrt(vecDx * vecDx + vecDy * vecDy)
  local vecNorm = {
    x = vecLength > 0 ? vecDx / vecLength : 0
    y = vecLength > 0 ? vecDy / vecLength : 0
  }

  resPoint1.x = resPoint2.x + vecNorm.x * (vecLength - forestallRadius)
  resPoint1.y = resPoint2.y + vecNorm.y * (vecLength - forestallRadius)

  return [resPoint2, resPoint1]
}


local function forestallTgtLine(color){
  local w = sw(100)
  local h = sh(100)
  return styleLineForeground.__merge({

    color
    rendObj = ROBJ_VECTOR_CANVAS
    size = [w, h]
    lineWidth = hdpx(LINE_WIDTH)
    opacity = 0.8
    behavior = Behaviors.RtPropUpdate
    animations = [{ prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.5, play = selectedTargetBlinking.value, loop = true, easing = InOutSine, trigger = frameTrigger}]
    update = function() {
      local resLine = getForestallTargetLineCoords()

      return {
        commands = [
          [VECTOR_LINE, resLine[0].x * 100.0 / w, resLine[0].y * 100.0 / h, resLine[1].x * 100.0 / w, resLine[1].y * 100.0 / h]
        ]
      }
    }
  })
}

local forestallTargetLine = @(color) function() {
  return !IsForestallVisible.value ? { watch = IsForestallVisible}
  : {
    watch = IsForestallVisible
    size = [sw(100), sh(100)]
    children = forestallTgtLine(color)
  }
}


local compassComponent = @(color) function() {
  return !HasCompass.value ? { watch = [ HasCompass ]}
    : {
      watch = [ HasCompass ]
      pos = [sw(50) - 0.5 * compassSize[0], sh(0.5)]
      children = compass(compassSize, color)
    }
}


local createAzimuthMark = @(size, is_selected, is_detected, is_enemy, color)
  function() {

    local frame = null

    local frameSizeW = size[0] * 1.5
    local frameSizeH = size[1] * 1.5
    local commands = []

    if (is_selected)
      commands.append(
        [VECTOR_LINE, 0, 0, 100, 0],
        [VECTOR_LINE, 100, 0, 100, 100],
        [VECTOR_LINE, 100, 100, 0, 100],
        [VECTOR_LINE, 0, 100, 0, 0]
      )
    else if (is_detected)
      commands.append(
        [VECTOR_LINE, 100, 0, 100, 100],
        [VECTOR_LINE, 0, 100, 0, 0]
      )
    if (!is_enemy) {
      local yOffset = is_selected ? 110 : 95
      local xOffset = is_selected ? 0 : 10
      commands.append([VECTOR_LINE, xOffset, yOffset, 100.0 - xOffset, yOffset])
    }

    frame = {
      size = [frameSizeW, frameSizeH]
      pos = [(size[0] - frameSizeW) * 0.5, (size[1] - frameSizeH) * 0.5 ]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(2)
      color
      fillColor = 0
      commands = commands
    }

    return {
      size
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(3)
      color
      fillColor = 0
      commands = [
        [VECTOR_LINE, 0, 100, 50, 0],
        [VECTOR_LINE, 50, 0, 100, 100],
        [VECTOR_LINE, 100, 100, 0, 100]
      ]
      children = frame
    }
  }

local createAzimuthMarkWithOffset = @(id, size, total_width, angle, is_selected, is_detected, is_enemy, isSecondRound, color) function() {
  local offset = (isSecondRound ? total_width : 0) +
    total_width * angle / 360.0 + 0.5 * size[0]

  local animTrigger = "".concat("fadeMarker", id, (is_selected ? "_1" : "_0"))

  if (!is_selected)
    ::anim_start(animTrigger)
  local animations = [
    {
      trigger = animTrigger
      prop = AnimProp.opacity
      from = 1.0
      to = 0.0
      duration = targetLifeTime
    }
  ]
  return {
    size = SIZE_TO_CONTENT
    pos = [offset, 0]
    children = createAzimuthMark(size, is_selected, is_detected, is_enemy, color)
    animations
  }
}


local createAzimuthMarkStrike = @(total_width, height, markerWidth, color) function() {

  local markers = []
  foreach(id, azimuthMarker in azimuthMarkers) {
    if (!azimuthMarker)
      continue
    markers.append(createAzimuthMarkWithOffset(id, [markerWidth, height], total_width,
      azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.isEnemy, false, color))
    markers.append(createAzimuthMarkWithOffset(id, [markerWidth, height], total_width,
      azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.isEnemy, true, color))
  }

  return {
    watch = AzimuthMarkersTrigger
    size = [total_width * 2.0, height]
    pos = [0, height * 0.5]
    children = markers
  }
}

local createAzimuthMarkStrikeComponent = @(size, total_width, styleColor) function() {

  local markerWidth = hdpx(20)
  local offsetW =  0.5 * (size[0] - compassOneElementWidth)
    + CompassValue.value * compassOneElementWidth * 2.0 / compassStep
    - total_width

  return {
    watch = CompassValue
    size = [size[0], size[1] * 2.0]
    clipChildren = true
    children = @() {
      children = createAzimuthMarkStrike(total_width, size[1], markerWidth, styleColor)
      pos = [offsetW, 0]
    }
  }
}

local function azimuthMarkStrike(styleColor) {
  local width = compassSize[0] * 1.5
  local totalWidth = 2.0 * getCompassStrikeWidth(compassOneElementWidth, compassStep)

  return {
    pos = [sw(50) - 0.5 * width, sh(17)]
    children = [
      createAzimuthMarkStrikeComponent([width, hdpx(30)], totalWidth, styleColor)
    ]
  }
}

local mkRadarBase = @(posWatch, size, isAir, color, mode, fontScale = 1.0) function() {

  local isSquare = mode.value == RadarViewMode.B_SCOPE_SQUARE
  local azimuthRange = AzimuthRange.value
  local squareSize = [HasAzimuthScale.value ? size[0] : 0.2 * size[0], size[1]]
  local sizeCScope = [size[0], size[1] * 0.42]

  local scopeChild = null
  if (IsBScopeVisible.value) {
    if (mode.value == RadarViewMode.B_SCOPE_SQUARE) {
      if (azimuthRange > PI)
        scopeChild = B_Scope(size, color)
      else
        scopeChild = B_ScopeSquare(squareSize, color)
    }
    else if (mode.value == RadarViewMode.B_SCOPE_ROUND) {
      if (azimuthRange > PI)
        scopeChild = B_Scope(size, color)
      else
        scopeChild = B_ScopeHalf(size, color, fontScale)
    }
  }

  local cScope = null
  if (IsCScopeVisible.value && !isPlayingReplay.value && azimuthRange <= PI) {
    cScope = {
      pos = [0, isSquare ? size[0] * 0.5 + hdpx(180) : size[1] * 0.5 + hdpx(30)]
      children = C_Scope(sizeCScope, color)
    }
  }

  return {
    watch = [mode, IsBScopeVisible, IsCScopeVisible, HasAzimuthScale, posWatch, AzimuthRange, isPlayingReplay]
    pos = posWatch.value
    children = [scopeChild, cScope]
  }
}

//todo remove (invisible comp)
local function radarMfdBackground() {

  local backSize = [radarPosSize.value.w / RadarScale.value,
    radarPosSize.value.h / RadarScale.value]
  local backPos = [radarPosSize.value.x - (1.0 - RadarScale.value) * 0.5 * backSize[0],
   radarPosSize.value.y - (1.0 - RadarScale.value) * 0.5 * backSize[1]]
  return {
    watch = [radarPosSize, RadarScale]
    pos = backPos
    size = backSize
    rendObj = ROBJ_SOLID
    lineWidth = radarPosSize.value.h
    color = Color(0, 0, 0, 255)
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_LINE, 0, 50, 100, 50]
    ]
  }
}

local mkRadar = @(posWatched, radarSize = sh(28), isAir = false, radar_color_watch = Watched(Color(0,255,0,255))) function() {

  local res = { watch = [IsRadarHudVisible, radar_color_watch] }

  local radarPos = !isAir ? posWatched
    : Computed(function() {
        local isSquare = ViewMode.value == RadarViewMode.B_SCOPE_SQUARE
        local offset = isSquare && IsCScopeVisible.value ? -radarSize * 0.5
          : !isSquare && !IsCScopeVisible.value && isAir ? radarSize * 0.5
          : 0
        return [posWatched.value[0], posWatched.value[1] + offset]
      })

  if (!IsRadarHudVisible.value)
    return res

  local color = radar_color_watch.value;

  local radarHudVisibleChildren = !isAir ?
  [
    targetsOnScreenComponent(color)
    forestallComponent(color)
    forestallTargetLine(color)
    mkRadarBase(radarPos, [radarSize, radarSize], isAir, color, ViewMode)
    scanZoneAzimuthComponent(color)
    lockZoneComponent(color)
    compassComponent(color)
    azimuthMarkStrike(color)
  ] :
  [
    targetsOnScreenComponent(color)
    forestallComponent(color)
    forestallTargetLine(color)
    mkRadarBase(radarPos, [radarSize, radarSize], isAir, color, ViewMode)
    scanZoneAzimuthComponent(color)
    scanZoneElevationComponent(color)
    lockZoneComponent(color)
  ]

  return res.__update({
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = radarHudVisibleChildren
  })
}

local mkRadarForMfd = @(radarColorWatched) function() {

  local color = radarColorWatched.value;

  return {
    watch = [MfdRadarEnabled, radarColorWatched, radarPosSize]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = [
      MfdRadarEnabled.value ? radarMfdBackground : null,
      MfdRadarEnabled.value
       ? mkRadarBase(Computed(@() [radarPosSize.value.x, radarPosSize.value.y]),
          [radarPosSize.value.w, radarPosSize.value.h],
          true, color, MfdViewMode, radarPosSize.value.h / 512.0)
       : null
    ]
  }
}

return {
  mkRadar
  mkRadarForMfd
  mode = getRadarModeText
}