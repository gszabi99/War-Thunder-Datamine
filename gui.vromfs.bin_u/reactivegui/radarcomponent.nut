//local frp = require("frp")
//local {isEqual} = require("%sqstd/underscore.nut")
let {PI, floor, cos, sin, fabs, sqrt} = require("%sqstd/math.nut")
let compass = require("compass.nut")
let {HasCompass, CompassValue} = require("compassState.nut")
let {isPlayingReplay} = require("hudState.nut")
let {hudFontHgt, fontOutlineFxFactor, greenColor, fontOutlineColor,
  isColorOrWhite, isDarkColor, fadeColor} = require("style/airHudStyle.nut")

let { selectedTargetSpeedBlinking, selectedTargetBlinking, targetAspectEnabled, modeNames,
  targets, screenTargets, azimuthMarkers, forestall, selectedTarget, radarPosSize, IsRadarHudVisible,
  IsNoiseSignaVisible, MfdRadarEnabled, IsRadarVisible, RadarModeNameId,
  Azimuth, Elevation, Distance, AzimuthHalfWidth, ElevationHalfWidth, DistanceGateWidthRel, NoiseSignal,
  IsRadar2Visible, Radar2ModeNameId, Azimuth2, Elevation2, Distance2, AzimuthHalfWidth2, ElevationHalfWidth2,
  NoiseSignal2, AimAzimuth, TurretAzimuth, TargetRadarAzimuthWidth, TargetRadarDist, CueAzimuthHalfWidthRel, CueDistWidthRel, AzimuthMin, AzimuthMax,
  ElevationMin, ElevationMax, IsBScopeVisible, IsCScopeVisible, ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax,
  CueVisible, CueAzimuth, CueDist, TargetsTrigger, ScreenTargetsTrigger, ViewMode, MfdViewMode, HasAzimuthScale, HasDistanceScale, ScanPatternsMax,
  DistanceMax, DistanceMin, DistanceScalesMax, AzimuthMarkersTrigger, Irst, RadarScale, IsForestallVisible,
  ScanZoneWatched, LockZoneWatched, IsScanZoneAzimuthVisible, IsScanZoneElevationVisible,
  IsLockZoneVisible, IsAamLaunchZoneVisible, AamLaunchZoneDist, AamLaunchZoneDistMin,
  AamLaunchZoneDistMax, VelocitySearch, MfdRadarHideBkg,
  AzimuthRange, AzimuthRangeInv, ElevationRangeInv} = require("radarState.nut")

let areaBackgroundColor = Color(0,0,0,120)

let defLineWidth = hdpx(1.2)

let styleText = {
  color = greenColor
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

let styleLineForeground = {
  color = greenColor
  lineWidth = hdpx(LINE_WIDTH)
}

const AIM_LINE_WIDTH = 2.0
const TURRET_LINE_WIDTH = 1.0

let compassSize = [hdpx(500), hdpx(32)]
let compassStep = 5.0
let compassOneElementWidth = compassSize[1]

let getCompassStrikeWidth = @(oneElementWidth, step) 360.0 * oneElementWidth / step

//animation trigger
let frameTrigger = {}
selectedTargetBlinking.subscribe(@(v) v ? ::anim_start(frameTrigger) : ::anim_request_stop(frameTrigger))
let speedTargetTrigger = {}
selectedTargetSpeedBlinking.subscribe(@(v) v ? ::anim_start(speedTargetTrigger) : ::anim_request_stop(speedTargetTrigger))

const targetLifeTime = 5.0

let targetsComponent = @(size, createTargetFunc, color) function() {

  let children = targets.filter(@(t) t != null)
    .map(@(_, i) createTargetFunc(i, hdpx(5) * 0, size, color))

  return {
    size
    children
    watch = TargetsTrigger //needed
  }
}

let function B_ScopeSquareBackground(size, color) {
  let scanAzimuthMinRelW = Computed(@() ScanAzimuthMin.value * AzimuthRangeInv.value)
  let scanAzimuthMaxRelW = Computed(@() ScanAzimuthMax.value * AzimuthRangeInv.value)

  let gridSecondaryCommandsW = Computed(function(){
    local scanAzimuthMinRel
    local scanAzimuthMaxRel
    if (scanAzimuthMinRelW.value <= scanAzimuthMaxRelW.value) {
      scanAzimuthMinRel = scanAzimuthMinRelW.value
      scanAzimuthMaxRel = scanAzimuthMaxRelW.value
    }
    else {
      scanAzimuthMinRel = -1.0
      scanAzimuthMaxRel =  1.0
    }

    let azimuthRangeInv = AzimuthRangeInv.value

    local gridSecondaryCommands = []

    if (HasDistanceScale.value)
      gridSecondaryCommands = [
        [VECTOR_LINE, 50 + scanAzimuthMinRel * 100, 25, 50 + scanAzimuthMaxRel * 100, 25],
        [VECTOR_LINE, 50 + scanAzimuthMinRel * 100, 50, 50 + scanAzimuthMaxRel * 100, 50],
        [VECTOR_LINE, 50 + scanAzimuthMinRel * 100, 75, 50 + scanAzimuthMaxRel * 100, 75]
      ]

    if (HasAzimuthScale.value) {
      let azimuthRelStep = PI / 12.0 * azimuthRangeInv
      let azimuthScanCenterRel = (scanAzimuthMinRel + scanAzimuthMaxRel) * 0.5
      local azimuthRel = azimuthScanCenterRel
      while (azimuthRel > scanAzimuthMinRel) {
        gridSecondaryCommands.append([
          VECTOR_LINE,
          50 + azimuthRel * 100, 0,
          50 + azimuthRel * 100, 100
        ])
        azimuthRel -= azimuthRelStep
      }
      azimuthRel = azimuthScanCenterRel
      while (azimuthRel < scanAzimuthMaxRel) {
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

  let back = {
    rendObj = ROBJ_SOLID
    size
    color = areaBackgroundColor
  }

  let frame = {
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

  let function gridMain() {
    let scanAzimuthMinRel = scanAzimuthMinRelW.value
    let scanAzimuthMaxRel = scanAzimuthMaxRelW.value
    let finalColor = isColorOrWhite(color)
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
  let gridSecondary = @() {
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

let B_ScopeSquareTargetSectorComponent = @(size, valueWatched, distWatched, halfWidthWatched, color) function() {
  let function tankRadar() {
    let azimuthRange = AzimuthRange.value ?? 1
    let val = valueWatched.value ?? 1
    let distWatchedV = distWatched.value ?? 1
    let halfWidth = halfWidthWatched.value ?? 1

    let halfAzimuthWidth = 100.0 * (azimuthRange > 0 ? halfWidth / azimuthRange : 0)
    let com = [[VECTOR_POLY, -halfAzimuthWidth, 100 * (1 - distWatchedV), halfAzimuthWidth, 100 * (1 - distWatchedV),
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

  let function aircraftRadar() {
    let azimuthRange = AzimuthRange.value
    let halfAzimuthWidth = 100.0 * (azimuthRange > 0 ? halfWidthWatched.value / azimuthRange : 0)
    let com = [
      [VECTOR_POLY, -halfAzimuthWidth, 100 * (1 - distWatched.value),
                     halfAzimuthWidth, 100 * (1 - distWatched.value),
                     halfAzimuthWidth, 100,
                    -halfAzimuthWidth, 100]]
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

  let showRadar = distWatched && halfWidthWatched && halfWidthWatched.value > 0
  let isTank =  AzimuthRange.value > PI

  return {
    watch = [valueWatched, distWatched, halfWidthWatched, AzimuthRange]
    children = !showRadar ? null
      : isTank ? tankRadar
      : aircraftRadar
    pos = [valueWatched.value * size[0], 0]
  }
}

let B_ScopeSquareAzimuthComponent = @(size, valueWatched, distWatched, halfWidthWatched, tanksOnly, color) function() {
  let function part1(){
    let azimuthRange = AzimuthRange.value
    let halfAzimuthWidth = 100.0 * (azimuthRange > 0 ? halfWidthWatched.value / azimuthRange : 0)

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
  let commandsW = distWatched
    ? Computed(@() [[VECTOR_LINE_DASHED, 0, 100.0 * (1.0 - distWatched.value), 0, 100.0, hdpx(10), hdpx(5)]])
    : Watched([[VECTOR_LINE, 0, 0, 0, 100.0]])

  let function part2(){
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      size
      watch = commandsW
      color = isColorOrWhite(color)
      lineWidth = hdpx(LINE_WIDTH)
      commands = commandsW.value
    }
  }

  let showPart1 = (!distWatched || !halfWidthWatched) ? null : distWatched.value == 1.0 && halfWidthWatched.value > 0
  let isTank = AzimuthRange.value > PI
  let show = !tanksOnly || isTank
  return {
    watch = [distWatched, halfWidthWatched, valueWatched, AzimuthRange]
    pos = [valueWatched.value * size[0], 0]
    children = !show ? null
      : showPart1 ? part1
      : part2
  }
}

let B_ScopeSquareLaunchRangeComponent = @(size, aamLaunchZoneDist, aamLaunchZoneDistMin, aamLaunchZoneDistMax, color) function() {

  let commands = [
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

let distanceGateWidthRelMin = 0.05
let angularGateWidthMultSquare = 4.0

let distanceGateWidthMult = 1.0
let iffDistRelMult = 0.5

let createTargetOnRadarSquare = @(index, radius, size, color) function() {


  let res = { watch = [HasAzimuthScale, HasDistanceScale, IsRadar2Visible, AzimuthHalfWidth2, AzimuthHalfWidth, DistanceGateWidthRel] }
  let target = targets[index]

  if (target == null)
    return res

  let opacity = (1.0 - target.ageRel) * target.signalRel

  let angleRel = HasAzimuthScale.value ? target.azimuthRel : 0.5
  let angularWidthRel = HasAzimuthScale.value ? target.azimuthWidthRel : 1.0
  let angleLeft = angleRel - 0.5 * angularWidthRel
  let angleRight = angleRel + 0.5 * angularWidthRel

  let distanceRel = HasDistanceScale.value ? target.distanceRel : 0.9
  let radialWidthRel = target.distanceWidthRel

  local selectionFrame = null

  let frameCommands = []

  let azimuthHalfWidth = IsRadar2Visible.value ? AzimuthHalfWidth2.value : AzimuthHalfWidth.value
  let angularGateHalfWidthRel = angularGateWidthMultSquare * azimuthHalfWidth / AzimuthRange.value
  let angleGateLeftRel = angleRel - angularGateHalfWidthRel
  let angleGateRightRel = angleRel + angularGateHalfWidthRel

  let distanceGateHalfWidthRel = 0.5 * max(DistanceGateWidthRel.value, distanceGateWidthRelMin) * distanceGateWidthMult
  let distanceInner = distanceRel - distanceGateHalfWidthRel
  let distanceOuter = distanceRel + distanceGateHalfWidthRel

  if (target.isDetected) {
    frameCommands.append(
      [ VECTOR_LINE,
        100 * angleGateLeftRel,
        100 * (1.0 - distanceInner),
        100 * angleGateLeftRel,
        100 * (1.0 - distanceOuter)
      ],
      [ VECTOR_LINE,
        100 * angleGateRightRel,
        100 * (1.0 - distanceInner),
        100 * angleGateRightRel,
        100 * (1.0 - distanceOuter)
      ]
    )
  }
  if (!target.isEnemy) {
    let iffMarkDistanceRel = distanceRel + (0.5 + iffDistRelMult) * radialWidthRel
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
    lineWidth = target.isSelected ? hdpx(2) : 100 * radialWidthRel
    fillColor = color
    color = isColorOrWhite(color)
    opacity = opacity
    commands = target.isSelected ?
      [
        [ VECTOR_ELLIPSE,
          100 * angleRel,
          100 * (1 - distanceRel),
          2,
          2 ],
        [ VECTOR_LINE,
          100 * angleRel,
          100 * (1 - distanceRel),
          100 * (angleRel - target.losHorSpeed * 0.0002),
          100 * (1 - (distanceRel + target.losSpeed * 0.0002)) ]
      ] :
      [
        [ VECTOR_LINE,
          100 * angleLeft,
          100 * (1 - distanceRel),
          100 * angleRight,
          100 * (1 - distanceRel) ]
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


let function arrowIcon(size, color) {
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


let function groundNoiseIcon(size, color) {
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


let function noiseSignalComponent(signalWatched, size, isIconOnLeftSide, color) {

  let indicator = @() {

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

  let icon = groundNoiseIcon([size[1], size[1]], color)

  let children = isIconOnLeftSide
    ? [icon, indicator]
    : [indicator, icon]

  return {
    flow = FLOW_HORIZONTAL
    gap = size[1] * 0.2
    children
  }
}


let function noiseSignal(size, pos1, pos2, color) {
  let showSignal = Computed(@() IsNoiseSignaVisible.value && !MfdRadarEnabled.value)
  let showSignal1 = Computed(@() showSignal.value && IsRadarVisible.value && NoiseSignal.value > 0.5)
  let showSignal2 = Computed(@() showSignal.value && IsRadar2Visible.value && NoiseSignal2.value > 0.5)
  let noize1 = noiseSignalComponent(NoiseSignal, size, true, color)
  let noize2 = noiseSignalComponent(NoiseSignal2, size, true, color)
  let signal1 = @() {watch = showSignal1, size, pos=pos1, children =  showSignal1.value ? noize1 : null}
  let signal2 = @() {watch = showSignal2, size, pos=pos2, children =  showSignal2.value ? noize2 : null}

  return {
    children = [signal1, signal2]
  }
}


let radToDeg = 180.0 / 3.14159

let function getRadarModeText(radarModeNameWatch, isRadarVisibleWatch) {
  let texts = []
  if (radarModeNameWatch.value >= 0)
    texts.append(::loc(modeNames[radarModeNameWatch.value]))
  else if (isRadarVisibleWatch.value)
    texts.append(Irst.value ? ::loc("hud/irst") : ::loc("hud/radarEmitting"))
 return "".join(texts)
}


let makeRadarModeText = @(textConfig, color) function() {
  return styleText.__merge({
    watch = [RadarModeNameId, IsRadarVisible]
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    text = getRadarModeText(RadarModeNameId, IsRadarVisible)
    color
    fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
    fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
  }).__merge(textConfig)
}

let makeRadar2ModeText = @(textConfig, color) function() {
  return styleText.__merge({
    watch = [Radar2ModeNameId, IsRadar2Visible]
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    text = getRadarModeText(Radar2ModeNameId, IsRadar2Visible)
    color
    fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
    fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
  }).__merge(textConfig)
}

let offsetScaleFactor = 1.3

let B_ScopeSquareMarkers = @(size, color) function() {

  let res = { watch = [HasAzimuthScale, ScanAzimuthMax, ScanAzimuthMin, HasDistanceScale,
                         IsRadarVisible, IsRadar2Visible] }

  let isCollapsed = !IsRadarVisible.value && !IsRadar2Visible.value
  if (isCollapsed)
    return res

  return res.__update({
    size = [offsetScaleFactor * size[0], offsetScaleFactor * size[1]]
    children = [
      !HasAzimuthScale.value || ScanAzimuthMax.value <= ScanAzimuthMin.value
      ? null
      : @() styleText.__merge({
        watch = [ScanAzimuthMin, ScanAzimuthMax,
          ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
        rendObj = ROBJ_TEXT
        pos = [0, - hdpx(20)]
        color
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
        text = "".concat(floor((ScanAzimuthMax.value - ScanAzimuthMin.value) * radToDeg + 0.5),
                ::loc("measureUnits/deg"),
                "x",
                floor((ScanElevationMax.value - ScanElevationMin.value) * radToDeg + 0.5),
                ::loc("measureUnits/deg"),
                (ScanPatternsMax.value > 1 ? "*" : " "))
      }),
      !HasDistanceScale.value ? null
      : @() styleText.__merge({
        watch = [VelocitySearch, DistanceMax, DistanceScalesMax ]
        rendObj = ROBJ_TEXT
        color
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
        pos = [max(size[0] * 0.75, hdpx(70)), -hdpx(20)]
        text = "".concat(VelocitySearch.value
                ? ::cross_call.measureTypes.SPEED.getMeasureUnitsText(DistanceMax.value, true, false, false)
                : ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMax.value * 1000.0, true, false, false),
                (DistanceScalesMax.value > 1 ? "*" : " "))
      }),
      !HasDistanceScale.value || isCollapsed ? null
      : @() styleText.__merge({
        watch = [VelocitySearch, DistanceMin ]
        rendObj = ROBJ_TEXT
        color
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
        pos = [max(size[0] * 0.75, hdpx(70)), size[1] + hdpx(6)]
        text = VelocitySearch.value
          ? ::cross_call.measureTypes.SPEED.getMeasureUnitsText(DistanceMin.value, true, false, false)
          : ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMin.value * 1000.0, true, false, false)
      }),
      isCollapsed ? null
      : @() styleText.__merge({
        watch = [AzimuthMin]
        rendObj = ROBJ_TEXT
        color = isColorOrWhite(color)
        fontFxFactor = fontOutlineFxFactor
        fontFxColor = Color(0, 0, 0, 120)
        pos = [hdpx(4), hdpx(4)]
        text = "".concat(floor(AzimuthMin.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      }),
      isCollapsed ? null
      : @() styleText.__merge({
        halign = ALIGN_RIGHT
        watch = [AzimuthMax]
        size = [size[0], SIZE_TO_CONTENT]
        rendObj = ROBJ_TEXT
        color = isColorOrWhite(color)
        fontFxFactor = fontOutlineFxFactor
        fontFxColor = Color(0, 0, 0, 120)
        pos = [-hdpx(4), hdpx(4)]
        text = "".concat(floor(AzimuthMax.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      }),
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

let B_ScopeSquareCue = @(size, color) function() {
  let function cue() {
    let halfAzimuthWidth = 100.0 * CueAzimuthHalfWidthRel.value
    let halfDistGateWidth = 100.0 * 0.5 * CueDistWidthRel.value
    return {
      watch = [CueAzimuthHalfWidthRel, CueDistWidthRel]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = 2
      color
      size
      commands = [
        [VECTOR_LINE, -halfAzimuthWidth, -halfDistGateWidth, -halfAzimuthWidth, halfDistGateWidth],
        [VECTOR_LINE,  halfAzimuthWidth, -halfDistGateWidth,  halfAzimuthWidth, halfDistGateWidth]
      ]
    }
  }
  return {
    watch = [
      CueVisible,
      CueAzimuth, TargetRadarAzimuthWidth, AzimuthRange, CueAzimuthHalfWidthRel,
      CueDist, TargetRadarDist, CueDistWidthRel
    ]
    pos = [
      (CueAzimuth.value * (TargetRadarAzimuthWidth.value / AzimuthRange.value - CueAzimuthHalfWidthRel.value) + 0.5) * size[0],
      (1.0 - (0.5 * CueDistWidthRel.value + CueDist.value * TargetRadarDist.value * (1.0 - CueDistWidthRel.value))) * size[1]
    ]
    children = CueVisible.value ? cue : null
  }
}

let function B_ScopeSquare(size, color, hide_back) {
  let bkg = hide_back ? null : B_ScopeSquareBackground(size, color)
  let scopeTgtSectorComp = hide_back ? null : B_ScopeSquareTargetSectorComponent(size, TurretAzimuth, TargetRadarDist, TargetRadarAzimuthWidth, color)
  let scopeSquareAzimuthComp1 = B_ScopeSquareAzimuthComponent(size, TurretAzimuth, null, null, true, color)
  let groundReflComp = @() {

    size
    rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
    isSquare = true
    xFragments = 20
    yFragments = 10
    color = isColorOrWhite(color)
  }
  let scopeSquareAzimuthComp2 = B_ScopeSquareAzimuthComponent(size, Azimuth, Distance, AzimuthHalfWidth, false, color)
  let scopeSquareAzimuthComp3 = B_ScopeSquareAzimuthComponent(size, Azimuth2, Distance2, AzimuthHalfWidth2, false, color)
  let scopeSqLaunchRangeComp = B_ScopeSquareLaunchRangeComponent(size, AamLaunchZoneDist,
                                                        AamLaunchZoneDistMin, AamLaunchZoneDistMax, color)
  let tgts = targetsComponent(size, createTargetOnRadarSquare, color)
  let markers = B_ScopeSquareMarkers(size, color)
  let cue = B_ScopeSquareCue(size, color)
  return function() {
    let children = [ bkg, scopeTgtSectorComp, scopeSquareAzimuthComp1, groundReflComp ]
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
        markers,
        cue
      ]
    }
  }
}

let function B_ScopeBackground(size, color) {

  let circle = {
    rendObj = ROBJ_VECTOR_CANVAS
    size
    color
    fillColor = areaBackgroundColor
    lineWidth = hdpx(LINE_WIDTH)
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
  }

  let function gridSecondary() {
    let commands = HasDistanceScale.value ?
    [
      [VECTOR_ELLIPSE, 50, 50, 12.5, 12.5],
      [VECTOR_ELLIPSE, 50, 50, 25.0, 25.0],
      [VECTOR_ELLIPSE, 50, 50, 37.5, 37.5]
    ] :
    [
      [VECTOR_ELLIPSE, 50, 50, 45.0, 45.0]
    ]

    const angleGrad = 30.0
    let angle = PI * angleGrad / 180.0
    let dashCount = 360.0 / angleGrad
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

let function B_ScopeAzimuthComponent(size, valueWatched, distWatched, halfWidthWatched, color, lineWidth = hdpx(LINE_WIDTH)) {
  let showPart1 = (!distWatched || !halfWidthWatched) ? Watched(false) : Computed(@() distWatched.value == 1.0 && (halfWidthWatched.value ?? 0) > 0) //wtf this condition mean?

  let function part1() {
    let sectorCommands = [VECTOR_POLY, 50, 50]
    let step = PI * 0.05
    let angleCenter = AzimuthMin.value + AzimuthRange.value * valueWatched.value - PI * 0.5
    let angleFinish = angleCenter + halfWidthWatched.value
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

  let function part2() {
    let angle = AzimuthMin.value + AzimuthRange.value * valueWatched.value - PI * 0.5
    let distV = distWatched?.value
    let commands = distV!=null ? [VECTOR_LINE_DASHED] : [VECTOR_LINE]
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

let rad2deg = 180.0 / PI

let function B_ScopeHalfLaunchRangeComponent(size, azimuthMin, azimuthMax, aamLaunchZoneDistMin, aamLaunchZoneDistMax, color) {
  return function(){
    let scanAngleStart = azimuthMin.value - PI * 0.5
    let scanAngleFinish = azimuthMax.value - PI * 0.5
    let scanAngleStartDeg = scanAngleStart * rad2deg
    let scanAngleFinishDeg = scanAngleFinish * rad2deg

    let commands = [
      [VECTOR_SECTOR, 50, 50, aamLaunchZoneDistMin.value * 50, aamLaunchZoneDistMin.value * 50, scanAngleStartDeg, scanAngleFinishDeg],
      [VECTOR_SECTOR, 50, 50, aamLaunchZoneDistMax.value * 50, aamLaunchZoneDistMax.value * 50, scanAngleStartDeg, scanAngleFinishDeg]
    ]

    let children = {
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
  let show = (distWatched==null || halfWidthWatched==null) ? Watched(false) : Computed(@() halfWidthWatched.value > 0)
  halfWidthWatched = halfWidthWatched ?? Watched(0.0)
  distWatched = distWatched ?? Watched(1.0)

  let function children() {
    let sectorCommands = [VECTOR_POLY, 50, 50]
    let step = PI * 0.05
    let angleCenter = AzimuthMin.value + AzimuthRange.value *
      (valueWatched?.value ?? 0.5) - PI * 0.5
    let angleFinish = angleCenter + halfWidthWatched.value
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

let angularGateBeamWidthMin = 2.0 * 0.0174

let angularGateWidthMultMinPolar = 4.0
let angularGateWidthMultMaxPolar = 6.0
let angularGateWidthMultMinDistanceRelPolar = 0.06
let angularGateWidthMultMaxDistanceRelPolar = 0.33

let function calcAngularGateWidthPolar(distance_rel, azimuth_half_width) {
  if (azimuth_half_width > 0.17)
    return 2.0
  let blend = min((distance_rel - angularGateWidthMultMinDistanceRelPolar) / (angularGateWidthMultMaxDistanceRelPolar - angularGateWidthMultMinDistanceRelPolar), 1.0)
  return angularGateWidthMultMinPolar * blend + angularGateWidthMultMaxPolar * (1.0 - blend)
}

let createTargetOnRadarPolar = @(index, radius, size, color) function() {

  let res = { watch = [HasAzimuthScale, AzimuthMin, AzimuthRange, HasDistanceScale] }

  let target = targets[index]

  if (target == null)
    return res

  let angle = HasAzimuthScale.value ? AzimuthMin.value + AzimuthRange.value * target.azimuthRel - PI * 0.5 : -PI * 0.5
  let angularWidth = AzimuthRange.value * target.azimuthWidthRel
  let angleLeftDeg = (angle - 0.5 * angularWidth) * 180.0 / PI
  let angleRightDeg = (angle + 0.5 * angularWidth) * 180.0 / PI

  let distanceRel = HasDistanceScale.value ? target.distanceRel : 0.9
  let radialWidthRel = HasAzimuthScale.value ? target.distanceWidthRel : 1.0

  local selectionFrame = null

  let azimuthHalfWidth = IsRadar2Visible.value ? AzimuthHalfWidth2.value : AzimuthHalfWidth.value
  let angularGateWidthMult = calcAngularGateWidthPolar(distanceRel, azimuthHalfWidth)
  let angularGateWidth = angularGateWidthMult * 2.0 * max(azimuthHalfWidth, angularGateBeamWidthMin)
  local angleGateLeft  = angle - 0.5 * angularGateWidth
  local angleGateRight = angle + 0.5 * angularGateWidth
  if (AzimuthMax.value - AzimuthMin.value < PI) {
    angleGateLeft  = max(angleGateLeft, AzimuthMin.value - PI * 0.5)
    angleGateRight = min(angleGateRight, AzimuthMax.value - PI * 0.5)
  }
  let distanceGateHalfWidthRel = 0.5 * max(DistanceGateWidthRel.value, distanceGateWidthRelMin) * distanceGateWidthMult
  let radiusInner = distanceRel - distanceGateHalfWidthRel
  let radiusOuter = distanceRel + distanceGateHalfWidthRel
  let frameCommands = []
  if (target.isDetected) {
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

  local sina = sin(angle)
  local cosa = cos(angle)

  if (!target.isEnemy) {
    let iffMarkDistanceRel = distanceRel + (0.5 + iffDistRelMult) * radialWidthRel
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
    lineWidth = target.isSelected ? hdpx(2) : 100 * radialWidthRel
    color = isColorOrWhite(color)
    fillColor = 0
    opacity = (1.0 - targets[index].ageRel)
    commands = target.isSelected ?
      [
        [ VECTOR_ELLIPSE,
          50 + 50 * cosa * distanceRel,
          50 + 50 * sina * distanceRel,
          2,
          2 ],
        [ VECTOR_LINE,
          50 + 50 * cosa * distanceRel,
          50 + 50 * sina * distanceRel,
          50 + 50 * (cosa * distanceRel + (cosa * target.losSpeed + sina * target.losHorSpeed) * 0.0002),
          50 + 50 * (sina * distanceRel + (sina * target.losSpeed + cosa * target.losHorSpeed) * 0.0002)]
      ] :
      [
        [ VECTOR_SECTOR,
          50, 50,
          50 * distanceRel,
          50 * distanceRel,
          angleLeftDeg, angleRightDeg ]
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

let B_ScopeCircleMarkers = @(size, color) function() {

  let res = { watch = [IsRadarVisible, IsRadar2Visible, HasDistanceScale,
                         HasAzimuthScale, ScanAzimuthMax, ScanAzimuthMin, ScanElevationMax, ScanElevationMin, ScanPatternsMax] }
  let isCollapsed = !IsRadarVisible.value && !IsRadar2Visible.value

  if (isCollapsed)
    return res

  return res.__update({
    size = [offsetScaleFactor * size[0], offsetScaleFactor * size[1]]
    children = [
      !HasAzimuthScale.value || ScanAzimuthMax.value <= ScanAzimuthMin.value
        ? null
        : @() styleText.__merge({
          watch = [ HasAzimuthScale, ScanAzimuthMin, ScanAzimuthMax,
                    ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
          rendObj = ROBJ_TEXT
          pos = [-size[0] * 0.30, size[1] * 0.5 + hdpx(5)]
          hplace = ALIGN_LEFT
          fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
          fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
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
          rendObj = ROBJ_TEXT
          pos = [size[0] + hdpx(4), size[1] * 0.5 + hdpx(5)]
          watch = [VelocitySearch, DistanceMax, DistanceScalesMax ]
          fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
          fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
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
          rendObj = ROBJ_TEXT
          pos = [size[0] * 0.5 - hdpx(4), -hdpx(18)]
          fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
          fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
          text = "".concat("0", ::loc("measureUnits/deg"))
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [size[0] + hdpx(4), size[1] * 0.5 - hdpx(15)]
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
        text = "".concat("90", ::loc("measureUnits/deg"))
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [size[0] * 0.5 - hdpx(18), size[1] + hdpx(4)]
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
        text = "".concat("180", ::loc("measureUnits/deg"))
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [-size[0] * 0.15, size[1] * 0.5 - hdpx(15)]
        hplace = ALIGN_LEFT
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
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

let B_ScopeCue = @(size, color) function() {
  let function cue() {
    let cueAzimuth = CueAzimuth.value * max(TargetRadarAzimuthWidth.value - CueAzimuthHalfWidthRel.value * AzimuthRange.value, 0.0)
    let distRel = 0.5 * CueDistWidthRel.value + CueDist.value * TargetRadarDist.value * (1.0 - CueDistWidthRel.value)
    let halfDistGateWidthRel = 0.5 * CueDistWidthRel.value
    let radiusMin = (distRel - halfDistGateWidthRel) * 50.0
    let radiusMax = (distRel + halfDistGateWidthRel) * 50.0
    let turretAzimuth = AzimuthMin.value + AzimuthRange.value * TurretAzimuth.value
    let cueAzimuthMin = turretAzimuth + cueAzimuth - CueAzimuthHalfWidthRel.value * AzimuthRange.value
    let cueAzimuthMax = turretAzimuth + cueAzimuth + CueAzimuthHalfWidthRel.value * AzimuthRange.value
    return {
      watch = [
        CueAzimuth, TurretAzimuth, AzimuthMin, AzimuthRange, TargetRadarAzimuthWidth,
        CueAzimuthHalfWidthRel, CueDist, CueDistWidthRel
      ]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = 2
      color
      size
      commands = [
        [
          VECTOR_LINE,
          radiusMin * sin(cueAzimuthMin), 50 - radiusMin * cos(cueAzimuthMin),
          radiusMax * sin(cueAzimuthMin), 50 - radiusMax * cos(cueAzimuthMin)
        ],
        [
          VECTOR_LINE,
          radiusMin * sin(cueAzimuthMax), 50 - radiusMin * cos(cueAzimuthMax),
          radiusMax * sin(cueAzimuthMax), 50 - radiusMax * cos(cueAzimuthMax)
        ]
      ]
    }
  }
  return {
    watch = [ CueVisible ]
    pos = [size[0] * 0.5, 0.0]
    children = CueVisible.value ? cue : null
  }
}

let function B_Scope(size, color) {
  let bkg = B_ScopeBackground(size, color)
  let azComp1 = B_ScopeAzimuthComponent(size, AimAzimuth, null, null, color, AIM_LINE_WIDTH)
  let azComp2 = B_ScopeAzimuthComponent(size, TurretAzimuth, null, null, color, TURRET_LINE_WIDTH)
  let sectorComp = B_ScopeSectorComponent(size, TurretAzimuth, TargetRadarDist, TargetRadarAzimuthWidth, color)
  let azComp3 = B_ScopeAzimuthComponent(size, Azimuth, Distance, AzimuthHalfWidth, color)
  let azComp4 = B_ScopeAzimuthComponent(size, Azimuth2, Distance2, AzimuthHalfWidth2, color)
  let tgts = targetsComponent(size, createTargetOnRadarPolar, color)
  let sizeBScope = [size[0] + hdpx(2), size[1] + hdpx(2)]
  let markers = B_ScopeCircleMarkers(size, color)
  let cue = B_ScopeCue(size, color)

  return function() {
    let children = [ bkg, azComp1, azComp2, sectorComp ]
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
          markers,
          cue
      ]
    }
  }
}

let function B_ScopeHalfBackground(size, color) {
  let angleLimStartS = Computed(@() AzimuthMin.value - PI * 0.5)
  let angleLimFinishS = Computed(@() AzimuthMax.value - PI * 0.5)

  let function circle() {
    let angleLimStart = angleLimStartS.value
    let angleLimFinish = angleLimFinishS.value
    let angleLimStartDeg = angleLimStart * rad2deg
    let angleLimFinishDeg = angleLimFinish * rad2deg
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      size = size
      watch = [angleLimStartS, angleLimFinishS]
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

  let scanAngleStartS = Computed(@() ScanAzimuthMin.value - PI * 0.5)
  let scanAngleFinishS = Computed(@() ScanAzimuthMax.value - PI * 0.5)

  const angleGrad = 15.0
  let angle = PI * angleGrad / 180.0
  let dashCount = 360.0 / angleGrad
  let defSecGrid = []
  let gridSecondaryCom = Computed(function(){
    local scanAngleStart
    local scanAngleFinish
    if (scanAngleFinishS.value > scanAngleStartS.value) {
      scanAngleStart = scanAngleStartS.value
      scanAngleFinish = scanAngleFinishS.value
    } else {
      scanAngleStart = angleLimStartS.value
      scanAngleFinish = angleLimFinishS.value
    }
    let scanAngleStartDeg = scanAngleStart * rad2deg
    let scanAngleFinishDeg = scanAngleFinish * rad2deg

    let res = HasDistanceScale.value
    ? [
        [VECTOR_SECTOR, 50, 50, 12.5, 12.5, scanAngleStartDeg, scanAngleFinishDeg],
        [VECTOR_SECTOR, 50, 50, 25.0, 25.0, scanAngleStartDeg, scanAngleFinishDeg],
        [VECTOR_SECTOR, 50, 50, 37.5, 37.5, scanAngleStartDeg, scanAngleFinishDeg],
      ]
    : defSecGrid

    for(local i = 0; i < dashCount; ++i) {
      let currAngle = i * angle
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

  let gridSecondary = @() {
    watch = gridSecondaryCom
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = defLineWidth
    color = isColorOrWhite(color)
    fillColor = 0
    size
    commands = gridSecondaryCom.value
  }

  let function gridMain(){
    let scanAngleStart = scanAngleStartS.value
    let scanAngleFinish = scanAngleFinishS.value

    return {
      watch = [scanAngleStartS, scanAngleFinishS, angleLimStartS, angleLimFinishS]
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

let B_ScopeHalfCircleMarkers = @(size, color, fontScale) function() {

  let res = { watch = [IsRadarVisible, IsRadar2Visible, HasDistanceScale,
                         HasAzimuthScale, ScanAzimuthMax, ScanAzimuthMin] }

  let hiddenText = !IsRadarVisible.value && !IsRadar2Visible.value

  if (hiddenText)
    return res

  let scanRangeX = size[0] * 0.47
  let scanRangeY = size[1] * 0.51
  let scanYaw = size[0] * 0.58
  let scanPitch = size[0] * 0.51
  return res.__update({
    size = [offsetScaleFactor * size[0], offsetScaleFactor * size[1]]
    children = [
      {
        size = [0, SIZE_TO_CONTENT]
        children = !HasAzimuthScale.value || ScanAzimuthMax.value <= ScanAzimuthMin.value ? null
          : @() styleText.__merge({
            watch = [ ScanAzimuthMin, ScanAzimuthMax,
                      ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
            rendObj = ROBJ_TEXT
            size = SIZE_TO_CONTENT
            color
            fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
            fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
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
        : @() styleText.__merge({
          watch = [ VelocitySearch, DistanceMax, DistanceScalesMax ]
          rendObj = ROBJ_TEXT
          size = SIZE_TO_CONTENT
          color
          fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
          fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
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

let B_ScopeHalfCue = @(size, color) function() {
  let function cue() {
    let cueAzimuth = CueAzimuth.value * max(TargetRadarAzimuthWidth.value - CueAzimuthHalfWidthRel.value * AzimuthRange.value, 0.0)
    let distRel = 0.5 * CueDistWidthRel.value + CueDist.value * TargetRadarDist.value * (1.0 - CueDistWidthRel.value)
    let halfDistGateWidthRel = 0.5 * CueDistWidthRel.value
    let radiusMin = (distRel - halfDistGateWidthRel) * 50.0
    let radiusMax = (distRel + halfDistGateWidthRel) * 50.0
    let cueAzimuthMin = cueAzimuth - CueAzimuthHalfWidthRel.value * AzimuthRange.value
    let cueAzimuthMax = cueAzimuth + CueAzimuthHalfWidthRel.value * AzimuthRange.value
    return {
      watch = [
        CueAzimuth, AzimuthRange, TargetRadarAzimuthWidth,
        CueAzimuthHalfWidthRel, CueDist, CueDistWidthRel
      ]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = 2
      color
      size
      commands = [
        [
          VECTOR_LINE,
          radiusMin * sin(cueAzimuthMin), 50 - radiusMin * cos(cueAzimuthMin),
          radiusMax * sin(cueAzimuthMin), 50 - radiusMax * cos(cueAzimuthMin)
        ],
        [
          VECTOR_LINE,
          radiusMin * sin(cueAzimuthMax), 50 - radiusMin * cos(cueAzimuthMax),
          radiusMax * sin(cueAzimuthMax), 50 - radiusMax * cos(cueAzimuthMax)
        ]
      ]
    }
  }
  return {
    watch = [ CueVisible ]
    pos = [size[0] * 0.5, 0.0]
    children = CueVisible.value ? cue : null
  }
}

let function B_ScopeHalf(size, color, fontScale) {
  let bkg = B_ScopeHalfBackground(size, color)
  let sector = B_ScopeSectorComponent(size, null, TargetRadarDist, TargetRadarAzimuthWidth, color)
  let reflections = @(){

    size
    color = isColorOrWhite(color)
    rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
    isSquare = false
    xFragments = 16
    yFragments = 8
  }

  let sizeBScopeHalf = [size[0] + hdpx(2), 0.5 * size[1]]
  let markers = B_ScopeHalfCircleMarkers(size, color, fontScale)
  let cue = B_ScopeHalfCue(size, color)
  let az1 = B_ScopeAzimuthComponent(size, Azimuth, Distance, AzimuthHalfWidth, color)
  let az2 = B_ScopeAzimuthComponent(size, Azimuth2, Distance2, AzimuthHalfWidth2, color)
  let aamLaunch = B_ScopeHalfLaunchRangeComponent(size, AzimuthMin, AzimuthMax,
                                                      AamLaunchZoneDistMin, AamLaunchZoneDistMax, color)
  let tgts = targetsComponent(size, createTargetOnRadarPolar, color)
  return function() {
    let children = [ bkg, sector, reflections ]
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
        markers,
        cue
      ]
    }
  }
}

let function C_ScopeSquareBackground(size, color) {

  let back = {
    rendObj = ROBJ_SOLID
    size
    color = areaBackgroundColor
  }

  let frame = {
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

  let offsetW = Computed(@() 100 * (0.5 - (0.0 - ElevationMin.value) * ElevationRangeInv.value))
  let function crosshair() {
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
    let azimuthRangeInv   = AzimuthRangeInv.value
    let elevationRangeInv = ElevationRangeInv.value

    let scanAzimuthMinRel = ScanAzimuthMin.value * azimuthRangeInv
    let scanAzimuthMaxRel = ScanAzimuthMax.value * azimuthRangeInv
    let scanElevationMinRel = (ScanElevationMin.value - ElevationHalfWidth.value) * elevationRangeInv
    let scanElevationMaxRel = (ScanElevationMax.value + ElevationHalfWidth.value) * elevationRangeInv
    let finalColor = isColorOrWhite(color)
    let offset = offsetW.value
    let gridMain = {
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

    let gridSecondaryCommands = []

    let azimuthRelStep = PI / 12.0 * azimuthRangeInv
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

    let elevationRelStep = PI / 12.0 * elevationRangeInv
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

    let gridSecondary ={
      rendObj = ROBJ_VECTOR_CANVAS
      size
      color
      lineWidth = defLineWidth
      opacity = 0.42
      commands = gridSecondaryCommands
    }

    let children = [back, frame, crosshair, gridMain, gridSecondary]
    return styleLineForeground.__merge({
      watch = [ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax, ElevationHalfWidth,
               AzimuthRangeInv, ElevationRangeInv]
      size = SIZE_TO_CONTENT
      children
    })
  }
}

let function C_ScopeSquareAzimuthComponent(size, azimuthWatched, elevatonWatched, halfAzimuthWidthWatched, halfElevationWidthWatched, color) {
  return function() {
    let azimuthRange = AzimuthRange.value
    let halfAzimuthWidth   = 100.0 * (azimuthRange > 0 ? halfAzimuthWidthWatched.value / azimuthRange : 0)
    let halfElevationWidth = 100.0 * (azimuthRange > 0 ? halfElevationWidthWatched.value * ElevationRangeInv.value : 0)

    let children = @() {

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

let angularGateWidthMult = 4

let createTargetOnRadarCScopeSquare = @(index, radius, size, color) function() {

  let res = {
    watch = [
      CueVisible, CueDist, CueDistWidthRel,
      HasDistanceScale,
      HasAzimuthScale, AzimuthHalfWidth, AzimuthRange,
      ElevationHalfWidth, ElevationRangeInv
    ]
  }

  let target = targets[index]

  if (target == null)
    return res

  local inSelectedTargetRangeGate = false
  if (HasDistanceScale.value) {
    if (!CueVisible.value) {
      if (!target.isDetected) {
        foreach(secondTargetId, secondTarget in targets) {
          if (secondTarget != null &&
              secondTargetId != index && secondTarget.isDetected &&
              fabs(target.distanceRel - secondTarget.distanceRel) < 0.05) {
            inSelectedTargetRangeGate = true
            break
          }
        }
      }
    }
    else
      inSelectedTargetRangeGate = fabs(target.distanceRel - CueDist.value * TargetRadarDist.value) < 0.5 * CueDistWidthRel.value
  }
  else
    inSelectedTargetRangeGate = true

  local opacity = (1.0 - target.ageRel) * target.signalRel
  if (!inSelectedTargetRangeGate)
    opacity = 0

  let azimuthRel = HasAzimuthScale.value ? target.azimuthRel : 0.0
  let azimuthWidthRel = target.azimuthWidthRel
  let azimuthLeft = azimuthRel - azimuthWidthRel * 0.5

  let elevationRel = target.elevationRel
  let elevationWidthRel = target.elevationWidthRel
  let elevationLowerRel = elevationRel - elevationWidthRel * 0.5

  let frameCommands = []
  let azimuthGateWidthRel = angularGateWidthMult * 2.0 * max(AzimuthHalfWidth.value, angularGateBeamWidthMin) / AzimuthRange.value
  let azimuthGateLeftRel = azimuthRel - 0.5 * azimuthGateWidthRel
  let azimuthGateRightRel = azimuthRel + 0.5 * azimuthGateWidthRel
  let elevationGateWidthRel = angularGateWidthMult * 2.0 * max(ElevationHalfWidth.value, angularGateBeamWidthMin) * ElevationRangeInv.value
  let elevationGateLowerRel = elevationRel - 0.5 * elevationGateWidthRel
  let elevationGateUpperRel = elevationRel + 0.5 * elevationGateWidthRel

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

  let selectionFrame = {
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

let C_ScopeSquareMarkers = @(size, color) function() {

  let res = { watch = [ IsBScopeVisible, HasAzimuthScale, ScanAzimuthMax, ScanAzimuthMin, HasDistanceScale ] }

  return res.__update({
    size = [offsetScaleFactor * size[0], offsetScaleFactor * size[1]]
    children = [
      IsBScopeVisible.value || !HasAzimuthScale.value || ScanAzimuthMax.value <= ScanAzimuthMin.value
      ? null
      : @() styleText.__merge({
        watch = [ScanAzimuthMin, ScanAzimuthMax,
          ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
        rendObj = ROBJ_TEXT
        pos = [0, - hdpx(20)]
        color
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
        text = "".concat(floor((ScanAzimuthMax.value - ScanAzimuthMin.value) * radToDeg + 0.5),
                ::loc("measureUnits/deg"),
                "x",
                floor((ScanElevationMax.value - ScanElevationMin.value) * radToDeg + 0.5),
                ::loc("measureUnits/deg"),
                (ScanPatternsMax.value > 1 ? "*" : " "))
      }),
      IsBScopeVisible.value || !HasDistanceScale.value ? null
      : @() styleText.__merge({
        watch = [VelocitySearch, DistanceMax, DistanceScalesMax ]
        rendObj = ROBJ_TEXT
        color
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
        pos = [size[0] * 0.75, -hdpx(20)]
        text = "".concat(VelocitySearch.value
                ? ::cross_call.measureTypes.SPEED.getMeasureUnitsText(DistanceMax.value, true, false, false)
                : ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMax.value * 1000.0, true, false, false),
                (DistanceScalesMax.value > 1 ? "*" : " "))
      }),
      @() styleText.__merge({
        watch = ElevationMax
        rendObj = ROBJ_TEXT
        color
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
        pos = [size[0] + hdpx(4), hdpx(4)]
        text = "".concat(floor(ElevationMax.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      }),
      @() styleText.__merge({
        watch = [ ElevationMin, ElevationRangeInv ]
        color
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
        rendObj = ROBJ_TEXT
        pos = [size[0] + hdpx(4), (1.0 - (0.0 - ElevationMin.value) * ElevationRangeInv.value) * size[1] - hdpx(4)]
        text = "".concat("0", ::loc("measureUnits/deg"))
      }),
      @() styleText.__merge({
        watch = ElevationMin
        rendObj = ROBJ_TEXT
        color
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
        pos = [size[0] + hdpx(4), size[1] - hdpx(20)]
        text = "".concat(floor(ElevationMin.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      }),
      @() styleText.__merge({
        watch = AzimuthMin
        rendObj = ROBJ_TEXT
        pos = [hdpx(4), hdpx(4)]
        color = isColorOrWhite(color)
        fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
        fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
        text = "".concat(floor(AzimuthMin.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      }),
      {
        size = [size[0], SIZE_TO_CONTENT]
        children = @() styleText.__merge({
          watch = AzimuthMax
          rendObj = ROBJ_TEXT
          pos = [-hdpx(4), hdpx(4)]
          color = isColorOrWhite(color)
          hplace = ALIGN_RIGHT
          fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
          fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
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

let C_ScopeCue = @(size, color) function() {
  let function cue() {
    let azimuthHalfWidth = 100 * CueAzimuthHalfWidthRel.value
    return {
      watch = [ AzimuthRange, AzimuthHalfWidth ]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = 2
      color
      size
      commands = [
        [VECTOR_LINE, 50 - azimuthHalfWidth, 0, 50 - azimuthHalfWidth, 100],
        [VECTOR_LINE, 50 + azimuthHalfWidth, 0, 50 + azimuthHalfWidth, 100]
      ]
    }
  }
  return {
    watch = [ CueVisible, CueAzimuth, TargetRadarAzimuthWidth, AzimuthRange, CueAzimuthHalfWidthRel ]
    pos = [
      CueAzimuth.value * max(TargetRadarAzimuthWidth.value/ AzimuthRange.value - CueAzimuthHalfWidthRel.value, 0.0) * size[0],
      size[1] * 0.0
    ]
    children = CueVisible.value ? cue : null
  }
}

let function C_Scope(size, color) {
  let bkg = C_ScopeSquareBackground(size, color)
  let azim1 = C_ScopeSquareAzimuthComponent(size, Azimuth, Elevation, AzimuthHalfWidth, ElevationHalfWidth, color)
  let azim2 = C_ScopeSquareAzimuthComponent(size, Azimuth2, Elevation2, AzimuthHalfWidth2, ElevationHalfWidth2, color)
  let tgts = targetsComponent(size, createTargetOnRadarCScopeSquare, color)
  let markers = C_ScopeSquareMarkers(size, color)
  let cue = C_ScopeCue(size, color)

  return function() {
    let children = [bkg]
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
        cue
      ]
    }
  }
}

let mkRadarTgtsDist = @(dist, _id, width, color) styleText.__merge({
  rendObj = ROBJ_TEXT
  color
  size = [width * 4, SIZE_TO_CONTENT]
  pos = [width + hdpx(5), 0]
  fontSize = hudFontHgt
  fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
  fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
  text = (dist != null && dist > 0.0) ? ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(dist) : ""
})

let mkRadarTgtsSpd = @(id, width, color) styleText.__merge({
  rendObj = ROBJ_TEXT
  color
  size = [width * 4, SIZE_TO_CONTENT]
  pos = [width + hdpx(5), hdpx(35) * sh(100) / 1080]
  fontSize = hudFontHgt
  fontFxFactor = isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
  fontFxColor = isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
  animations = [{ prop = AnimProp.opacity, from = 0.42, to = 1, duration = 0.5,
    play = selectedTargetBlinking.value, loop = true, easing = InOutSine, trigger = speedTargetTrigger
  }]
  behavior = Behaviors.RtPropUpdate
  function update() {
    let spd = screenTargets?[id]?.radSpeed
    return {
      text = (spd != null && spd > -3000.0)
        ?  ::cross_call.measureTypes.CLIMBSPEED.getMeasureUnitsText(spd) : ""
    }
  }
})

let createTargetOnScreen = @(id, width, color) function() {

  let dist = screenTargets?[id]?.dist

  let function updateTgtVelocityVector() {

    let target = screenTargets?[id]
    if (targetAspectEnabled.value && target != null && target.losSpeed > -3000.0) {
      let targetSpeed = sqrt(target.losHorSpeed * target.losHorSpeed + target.losSpeed * target.losSpeed)
      let targetSpeedInv = 1.0 / max(targetSpeed, 1.0)
      let innerRadius = 10
      let outerRadius = 50
      let speedToOuterRadius = 0.1
      return {
        commands = [
          [ VECTOR_ELLIPSE, 50, 50, innerRadius, innerRadius],
          [ VECTOR_LINE,
            50 - target.losHorSpeed * targetSpeedInv * innerRadius,
            50 - target.losSpeed  * targetSpeedInv * innerRadius,
            50 - target.losHorSpeed * targetSpeedInv * min(innerRadius + targetSpeed * speedToOuterRadius, outerRadius),
            50 - target.losSpeed  * targetSpeedInv * min(innerRadius + targetSpeed * speedToOuterRadius, outerRadius)
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
      let tgt = screenTargets?[id]
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
        fillColor = 0
        size = [width, width]
        commands = screenTargets?[id]?.isTracked ?
          [
            [VECTOR_RECTANGLE, 0, 0, 100, 100]
          ] :
          (screenTargets?[id]?.isDetected ?
            [
              [VECTOR_LINE, 0, 0, 40, 0],
              [VECTOR_LINE, 0, 0, 0, 40],
              [VECTOR_LINE, 100, 0, 60, 0],
              [VECTOR_LINE, 100, 0, 100, 40],
              [VECTOR_LINE, 100, 100, 60, 100],
              [VECTOR_LINE, 100, 100, 100, 60],
              [VECTOR_LINE, 0, 100, 40, 100],
              [VECTOR_LINE, 0, 100, 0, 60]
            ] :
            [
              [VECTOR_LINE, 0, 0, 10, 0],
              [VECTOR_LINE, 0, 0, 0, 10],
              [VECTOR_LINE, 100, 0, 90, 0],
              [VECTOR_LINE, 100, 0, 100, 10],
              [VECTOR_LINE, 100, 100, 90, 100],
              [VECTOR_LINE, 100, 100, 100, 90],
              [VECTOR_LINE, 0, 100, 10, 100],
              [VECTOR_LINE, 0, 100, 0, 90]
            ]
          )
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


let forestallRadius = hdpx(15)
let targetOnScreenWidth = hdpx(50)

let targetsOnScreenComponent = @(color) function() {
  let res = { watch = [ ScreenTargetsTrigger, HasAzimuthScale ] }
  if (!HasAzimuthScale.value)
    return res
  else if (!screenTargets)
    return res

  let targetsRes = []
  foreach (id, target in screenTargets) {
    if (!target)
      continue
    targetsRes.append(createTargetOnScreen(id, targetOnScreenWidth, color))
  }

  return res.__update({
    size = [sw(100), sh(50)]
    children = targetsRes
  })
}

let forestallVisible = @(color) function() {
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

let forestallComponent = @(color) function() {
  return {
    size = [sw(100), sh(100)]
    children = IsForestallVisible.value ? forestallVisible(color) : null
    watch = IsForestallVisible
  }
}

let scanZoneAzimuthComponent = @(color) function() {


  if (!IsScanZoneAzimuthVisible.value)
    return { watch = IsScanZoneAzimuthVisible}

  let width = sw(100)
  let height = sh(100)

  let {x0,y0,x1,y1} = ScanZoneWatched.value
  let _x0 = (x0 + x1) * 0.5
  let _y0 = (y0 + y1) * 0.5
  let mw = 100 / width
  let mh = 100 / height
  let px0 = (x0 - _x0) * mw
  let py0 = (y0 - _y0) * mh
  let px1 = (x1 - _x0) * mw
  let py1 = (y1 - _y0) * mh

  let commands = [
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

let scanZoneElevationComponent = @(color) function() {

  if (!IsScanZoneElevationVisible.value)
    return { watch = [IsScanZoneElevationVisible] }

  let width = sw(100)
  let height = sh(100)
  let mw = 100 / width
  let mh = 100 / height
  let {x2, x3, y2, y3} = ScanZoneWatched.value
  let _x0 = (x2 + x3) * 0.5
  let _y0 = (y2 + y3) * 0.5
  let px2 = (x2 - _x0) * mw
  let py2 = (y2 - _y0) * mh
  let px3 = (x3 - _x0) * mw
  let py3 = (y3 - _y0) * mh

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

let lockZoneComponent = @(color) function() {

  let res =  { watch = [IsLockZoneVisible, LockZoneWatched] }
  if (!IsLockZoneVisible.value)
    return res.__update({
      animations = [{ prop = AnimProp.opacity, from = 0.0, to = 1, duration = 0.25, play = true, loop = true, easing = InOutSine}]})

  let width = sw(100)
  let height = sh(100)
  let mw = 100 / width
  let mh = 100 / height
  let corner = 0.1
  let lineWidth = hdpx(4)
  let size = [sw(100), sh(100)]

  let {x0, x1, x2, x3, y0, y1, y2, y3} = LockZoneWatched.value
  let _x0 = (x0 + x1 + x2 + x3) * 0.25
  let _y0 = (y0 + y1 + y2 + y3) * 0.25

  let px0 = (x0 - _x0) * mw
  let py0 = (y0 - _y0) * mh
  let px1 = (x1 - _x0) * mw
  let py1 = (y1 - _y0) * mh
  let px2 = (x2 - _x0) * mw
  let py2 = (y2 - _y0) * mh
  let px3 = (x3 - _x0) * mw
  let py3 = (y3 - _y0) * mh

  let commands = [
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

let function getForestallTargetLineCoords() {
  let p1 = {
    x = forestall.x
    y = forestall.y
  }
  let p2 = {
    x = selectedTarget.x
    y = selectedTarget.y
  }

  let resPoint1 = {
    x = 0
    y = 0
  }
  let resPoint2 = {
    x = 0
    y = 0
  }

  let dx = p1.x - p2.x
  let dy = p1.y - p2.y
  let absDx = fabs(dx)
  let absDy = fabs(dy)

  if (absDy >= absDx) {
    resPoint2.x = p2.x
    resPoint2.y = p2.y + (dy > 0 ? 0.5 : -0.5) * hdpx(50)
  }
  else {
    resPoint2.y = p2.y
    resPoint2.x = p2.x + (dx > 0 ? 0.5 : -0.5) * hdpx(50)
  }

  let vecDx = p1.x - resPoint2.x
  let vecDy = p1.y - resPoint2.y
  let vecLength = sqrt(vecDx * vecDx + vecDy * vecDy)
  let vecNorm = {
    x = vecLength > 0 ? vecDx / vecLength : 0
    y = vecLength > 0 ? vecDy / vecLength : 0
  }

  resPoint1.x = resPoint2.x + vecNorm.x * (vecLength - forestallRadius)
  resPoint1.y = resPoint2.y + vecNorm.y * (vecLength - forestallRadius)

  return [resPoint2, resPoint1]
}


let function forestallTgtLine(color){
  let w = sw(100)
  let h = sh(100)
  return styleLineForeground.__merge({

    color
    rendObj = ROBJ_VECTOR_CANVAS
    size = [w, h]
    lineWidth = hdpx(LINE_WIDTH)
    opacity = 0.8
    behavior = Behaviors.RtPropUpdate
    animations = [{ prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.5, play = selectedTargetBlinking.value, loop = true, easing = InOutSine, trigger = frameTrigger}]
    update = function() {
      let resLine = getForestallTargetLineCoords()

      return {
        commands = [
          [VECTOR_LINE, resLine[0].x * 100.0 / w, resLine[0].y * 100.0 / h, resLine[1].x * 100.0 / w, resLine[1].y * 100.0 / h]
        ]
      }
    }
  })
}

let forestallTargetLine = @(color) function() {
  return !IsForestallVisible.value ? { watch = IsForestallVisible}
  : {
    watch = IsForestallVisible
    size = [sw(100), sh(100)]
    children = forestallTgtLine(color)
  }
}


let compassComponent = @(color) function() {
  return !HasCompass.value ? { watch = [ HasCompass ]}
    : {
      watch = [ HasCompass ]
      pos = [sw(50) - 0.5 * compassSize[0], sh(0.5)]
      children = compass(compassSize, color)
    }
}


let createAzimuthMark = @(size, is_selected, is_detected, is_enemy, color)
  function() {

    local frame = null

    let frameSizeW = size[0] * 1.5
    let frameSizeH = size[1] * 1.5
    let commands = []

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
      let yOffset = is_selected ? 110 : 95
      let xOffset = is_selected ? 0 : 10
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

let createAzimuthMarkWithOffset = @(id, size, total_width, angle, is_selected, is_detected, is_enemy, isSecondRound, color) function() {
  let offset = (isSecondRound ? total_width : 0) +
    total_width * angle / 360.0 + 0.5 * size[0]

  let animTrigger = "".concat("fadeMarker", id, (is_selected ? "_1" : "_0"))

  if (!is_selected)
    ::anim_start(animTrigger)
  let animations = [
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


let createAzimuthMarkStrike = @(total_width, height, markerWidth, color) function() {

  let markers = []
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

let createAzimuthMarkStrikeComponent = @(size, total_width, styleColor) function() {

  let markerWidth = hdpx(20)
  let offsetW =  0.5 * (size[0] - compassOneElementWidth)
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

let function azimuthMarkStrike(styleColor) {
  let width = compassSize[0] * 1.5
  let totalWidth = 2.0 * getCompassStrikeWidth(compassOneElementWidth, compassStep)

  return {
    pos = [sw(50) - 0.5 * width, sh(17)]
    children = [
      createAzimuthMarkStrikeComponent([width, hdpx(30)], totalWidth, styleColor)
    ]
  }
}

let mkRadarBase = @(posWatch, size, _isAir, color, mode, fontScale = 1.0, hide_back = false) function() {

  let isSquare = mode.value == RadarViewMode.B_SCOPE_SQUARE
  let azimuthRange = AzimuthRange.value
  let squareSize = [HasAzimuthScale.value ? size[0] : 0.2 * size[0], size[1]]
  let sizeCScope = [size[0], size[1] * 0.42]

  local scopeChild = null
  if (IsBScopeVisible.value) {
    if (mode.value == RadarViewMode.B_SCOPE_SQUARE) {
      if (azimuthRange > PI)
        scopeChild = B_Scope(size, color)
      else
        scopeChild = B_ScopeSquare(squareSize, color, hide_back)
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
let function radarMfdBackground() {

  let backSize = [radarPosSize.value.w / RadarScale.value,
    radarPosSize.value.h / RadarScale.value]
  let backPos = [radarPosSize.value.x - (1.0 - RadarScale.value) * 0.5 * backSize[0],
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

let mkRadar = @(posWatched, radarSize = sh(28), isAir = false, radar_color_watch = Watched(Color(0,255,0,255))) function() {

  let res = { watch = [IsRadarHudVisible, radar_color_watch] }

  let radarPos = !isAir ? posWatched
    : Computed(function() {
        let isSquare = ViewMode.value == RadarViewMode.B_SCOPE_SQUARE
        let offset = isSquare && IsCScopeVisible.value ? -radarSize * 0.5
          : !isSquare && !IsCScopeVisible.value && isAir ? radarSize * 0.5
          : 0
        return [posWatched.value[0], posWatched.value[1] + offset]
      })

  if (!IsRadarHudVisible.value)
    return res

  let color = fadeColor(radar_color_watch.value, 255);

  let radarHudVisibleChildren = !isAir ?
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

let mkRadarForMfd = @(radarColorWatched) function() {

  let color = radarColorWatched.value;

  return {
    watch = [MfdRadarEnabled, radarColorWatched, radarPosSize, MfdRadarHideBkg]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = [
      MfdRadarEnabled.value ? radarMfdBackground : null,
      MfdRadarEnabled.value
       ? mkRadarBase(Computed(@() [radarPosSize.value.x, radarPosSize.value.y]),
          [radarPosSize.value.w, radarPosSize.value.h],
          true, color, MfdViewMode, radarPosSize.value.h / 512.0, MfdRadarHideBkg.value)
       : null
    ]
  }
}

return {
  mkRadar
  mkRadarForMfd
  mode = getRadarModeText
}