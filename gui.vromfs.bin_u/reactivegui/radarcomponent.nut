from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")



let { PI, floor, cos, sin, fabs, sqrt } = require("%sqstd/math.nut")
let compass = require("%rGui/compass.nut")
let { HasCompass, CompassValue } = require("%rGui/compassState.nut")
let { isPlayingReplay } = require("%rGui/hudState.nut")
let { hudFontHgt, fontOutlineFxFactor, greenColor, fontOutlineColor,
  isColorOrWhite, isDarkColor, fadeColor } = require("%rGui/style/airHudStyle.nut")

let { SelectedTargetSpeedBlinking, SelectedTargetBlinking, modeNames,
  targets, azimuthMarkers, forestall, selectedTarget, radarPosSize, IsRadarHudVisible,
  IsNoiseSignaVisible, MfdRadarEnabled, IsRadarVisible, IsRadarEmitting, RadarModeNameId,
  Azimuth, Elevation, Distance, AzimuthHalfWidth, ElevationHalfWidth, DistanceGateWidthRel, NoiseSignal,
  IsRadar2Visible, IsRadar2Emitting, Radar2ModeNameId, Azimuth2, Elevation2, Distance2, AzimuthHalfWidth2, ElevationHalfWidth2,
  NoiseSignal2, AimAzimuth, TurretAzimuth, TargetRadarAzimuthWidth, TargetRadarDist, CueAzimuthHalfWidthRel, CueDistWidthRel, AzimuthMin, AzimuthMax,
  ElevationMin, ElevationMax, IsBScopeVisible, IsCScopeVisible, ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax,
  CueVisible, CueAzimuth, CueDist, TargetsTrigger, MfdViewMode, HasAzimuthScale, HasDistanceScale, ScanPatternsMax,
  DistanceMax, DistanceMin, DistanceScalesMax, AzimuthMarkersTrigger, Irst, RadarScale, IsForestallVisible,
  ScanZoneWatched, LockZoneWatched, IsScanZoneAzimuthVisible, IsScanZoneElevationVisible,
  IsLockZoneVisible, IsAamLaunchZoneVisible, AamLaunchZoneDist, AamLaunchZoneDistMin,
  AamLaunchZoneDistMax, AamLaunchZoneDistDgftMin, AamLaunchZoneDistDgftMax, VelocitySearch, MfdRadarHideBkg,
  AzimuthRange, AzimuthRangeInv, ElevationRangeInv, MfdRadarFontScale } = require("%rGui/radarState.nut")

let areaBackgroundColor = Color(0, 0, 0, 120)
const RADAR_LINES_OPACITY = 0.42

let defLineWidth = hdpx(1.2)

let deg = loc("measureUnits/deg")

let styleText = {
  color = greenColor
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

let maxMeasuresCompWidth = @()
  calc_comp_size(styleText.__merge({
    rendObj = ROBJ_TEXT
    text = $"360{deg}x360{deg}*"
  }))[0]

let getMaxLabelSize = @()
  calc_comp_size(styleText.__merge({
    rendObj = ROBJ_TEXT
    text = $"180{deg}"
  }))

let maxLabelWidth = getMaxLabelSize()[0]
let maxLabelHeight = getMaxLabelSize()[1]

let styleLineForeground = {
  color = greenColor
  lineWidth = hdpx(LINE_WIDTH)
}

const AIM_LINE_WIDTH = 2.0
const TURRET_LINE_WIDTH = 1.0

let elevMaxInv = 1.0 / 1.2
let elevMaxScreenRelSize = 0.25

let compassSize = [hdpx(500), hdpx(32)]
let compassStep = 5.0
let compassOneElementWidth = compassSize[1]

let getCompassStrikeWidth = @(oneElementWidth, step) 360.0 * oneElementWidth / step


let frameTrigger = {}
SelectedTargetBlinking.subscribe(@(v) v ? anim_start(frameTrigger) : anim_request_stop(frameTrigger))
let speedTargetTrigger = {}
SelectedTargetSpeedBlinking.subscribe(@(v) v ? anim_start(speedTargetTrigger) : anim_request_stop(speedTargetTrigger))

let targetsComponent = @(size, createTargetFunc, color) function() {
  return {
    size
    children = targets.map(function(t, i) {
      if (t == null)
        throw null
      return createTargetFunc(i, hdpx(5) * 0, size, color)
    })
    watch = TargetsTrigger
  }
}


function B_ScopeSquareBackground(size, color) {
  let scanAzimuthMinRelW = Computed(@() ScanAzimuthMin.get() * AzimuthRangeInv.get())
  let scanAzimuthMaxRelW = Computed(@() ScanAzimuthMax.get() * AzimuthRangeInv.get())
  let distMinRelW = Computed(@() DistanceMin.get() / max(DistanceMax.get(), 1.0))

  let gridSecondaryCommandsW = Computed(function() {
    local scanAzimuthMinRel
    local scanAzimuthMaxRel
    if (scanAzimuthMinRelW.get() <= scanAzimuthMaxRelW.get()) {
      scanAzimuthMinRel = scanAzimuthMinRelW.get()
      scanAzimuthMaxRel = scanAzimuthMaxRelW.get()
    }
    else {
      scanAzimuthMinRel = -1.0
      scanAzimuthMaxRel =  1.0
    }

    let azimuthRangeInv = AzimuthRangeInv.get()

    local gridSecondaryCommands = []

    let distanceMinY = 100 * (1.0 - distMinRelW.get())
    if (HasDistanceScale.get()) {
      local range = 25
      while (range < distanceMinY + 1.0) {
        gridSecondaryCommands.append([VECTOR_LINE, 50 + scanAzimuthMinRel * 100, range, 50 + scanAzimuthMaxRel * 100, range])
        range = range + 25
      }
      gridSecondaryCommands.append([VECTOR_LINE, 50 + scanAzimuthMinRel * 100, distanceMinY, 50 + scanAzimuthMaxRel * 100, distanceMinY])
    }

    if (HasAzimuthScale.get()) {
      let azimuthRelStep = PI / 12.0 * azimuthRangeInv
      let azimuthScanCenterRel = (scanAzimuthMinRel + scanAzimuthMaxRel) * 0.5
      local azimuthRel = azimuthScanCenterRel
      while (azimuthRel > scanAzimuthMinRel) {
        gridSecondaryCommands.append([
          VECTOR_LINE,
          50 + azimuthRel * 100, 0,
          50 + azimuthRel * 100, distanceMinY
        ])
        azimuthRel -= azimuthRelStep
      }
      azimuthRel = azimuthScanCenterRel
      while (azimuthRel < scanAzimuthMaxRel) {
        gridSecondaryCommands.append([
          VECTOR_LINE,
          50 + azimuthRel * 100, 0,
          50 + azimuthRel * 100, distanceMinY
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

  function gridMain() {
    let scanAzimuthMinRel = scanAzimuthMinRelW.get()
    let scanAzimuthMaxRel = scanAzimuthMaxRelW.get()
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
    commands = gridSecondaryCommandsW.get()
  }
  return {
    size = SIZE_TO_CONTENT
    children = [ back, frame, gridMain, gridSecondary ]
  }
}

function B_ScopeSquareTargetSectorComponent(size, valueWatched, distWatched, halfWidthWatched, color) {
  function tankRadar() {
    let azimuthRange = AzimuthRange.get() ?? 1
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
      opacity = RADAR_LINES_OPACITY
      size
      commands = com
    }
  }

  function aircraftRadar() {
    let azimuthRange = AzimuthRange.get()
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

  return function() {
    let showRadar = distWatched && halfWidthWatched && halfWidthWatched.value > 0
    let isTank =  AzimuthRange.get() > PI + 0.035

    return {
      watch = [valueWatched, distWatched, halfWidthWatched, AzimuthRange]
      children = !showRadar ? null
        : isTank ? tankRadar
        : aircraftRadar
      pos = [(isTank ? valueWatched.value : 0.5) * size[0], 0]
    }
  }
}

function B_ScopeSquareAzimuthComponent(size, valueWatched, distWatched, halfWidthWatched, tanksOnly, color) {
  function part1() {
    let azimuthRange = AzimuthRange.get()
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

  function part2() {
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      size
      watch = commandsW
      color = isColorOrWhite(color)
      lineWidth = hdpx(LINE_WIDTH)
      commands = commandsW.value
    }
  }

  let showPart1 = Computed(@() (!distWatched || !halfWidthWatched) ? null : distWatched.value == 1.0 && halfWidthWatched.value > 0)
  let showS = Computed(@() !tanksOnly || AzimuthRange.get() > PI + 0.035)

  return function() {
    return {
      watch = [valueWatched, showS, showPart1]
      pos = [valueWatched.value * size[0], 0]
      children = !showS.get()
        ? null
        : showPart1.get()
          ? part1
          : part2
    }
  }
}

function B_ScopeSquareElevationComp(size, elev_rel, elev_min, elev_max, elev_scan_min, elev_scan_max, color) {
  return function() {
    let elevMaxScreenSize = 100 * elevMaxScreenRelSize
    let elevationMin = -elev_min.value * elevMaxInv * elevMaxScreenSize + 50
    let elevationMax = -elev_max.value * elevMaxInv * elevMaxScreenSize + 50
    let elevationZero = 50
    let elevation = elevationMin * (1.0 - elev_rel.value) + elevationMax * elev_rel.value

    let markLen = 5
    let markLenShort = 3

    let commands = [
      [VECTOR_LINE, 0, elevationMin,  markLen,      elevationMin],
      [VECTOR_LINE, 0, elevationZero, markLenShort, elevationZero],
      [VECTOR_LINE, 0, elevationMax,  markLen,      elevationMax],
      [VECTOR_LINE, 0, elevation,     markLenShort, elevation]
    ]

    if (elev_scan_max.value > elev_scan_min.value) {
      let elevationScanMin = -elev_scan_min.value * elevMaxInv * elevMaxScreenSize + 50
      let elevationScanMax = -elev_scan_max.value * elevMaxInv * elevMaxScreenSize + 50

      commands.append([VECTOR_LINE, 0,       elevationScanMin,  markLen, elevationScanMin])
      commands.append([VECTOR_LINE, 0,       elevationScanMax,  markLen, elevationScanMax])
      commands.append([VECTOR_LINE, markLen, elevationScanMin,  markLen, elevationScanMax])
    }

    return {
      watch = [elev_rel, elev_min, elev_max, elev_scan_min, elev_scan_max]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(4)
      color = isColorOrWhite(color)
      fillColor = 0
      size
      opacity = RADAR_LINES_OPACITY
      commands
    }
  }
}

function B_ScopeSquareLaunchRangeComponent(size, aamLaunchZoneDist, aamLaunchZoneDistMin, aamLaunchZoneDistMax, color,
  aamLaunchZoneDistDgftMin, aamLaunchZoneDistDgftMax) {
  return function() {
    let commands = [
      [VECTOR_LINE, 80, (1.0 - aamLaunchZoneDist.value) * 100,    100, (1.0 - aamLaunchZoneDist.value)    * 100],
      [VECTOR_LINE, 90, (1.0 - aamLaunchZoneDistMin.value) * 100, 100, (1.0 - aamLaunchZoneDistMin.value) * 100],
      [VECTOR_LINE, 90, (1.0 - aamLaunchZoneDistMax.value) * 100, 100, (1.0 - aamLaunchZoneDistMax.value) * 100],
      (aamLaunchZoneDistDgftMax.value > 0.0 ? [VECTOR_LINE, 92, (1.0 - aamLaunchZoneDistDgftMax.value) * 100, 98, (1.0 - aamLaunchZoneDistDgftMax.value) * 100] : []),
      (aamLaunchZoneDistDgftMin.value > 0.0 ? [VECTOR_LINE, 92, (1.0 - aamLaunchZoneDistDgftMin.value) * 100, 98, (1.0 - aamLaunchZoneDistDgftMin.value) * 100] : []),
      (aamLaunchZoneDistDgftMin.value > 0.0 && aamLaunchZoneDistDgftMax.value > 0.0 ? [VECTOR_LINE, 92, (1.0 - aamLaunchZoneDistDgftMax.value) * 100, 92, (1.0 - aamLaunchZoneDistDgftMin.value) * 100] : [])
    ]

    return {
      watch = [aamLaunchZoneDist, aamLaunchZoneDistMin, aamLaunchZoneDistMax, aamLaunchZoneDistDgftMin, aamLaunchZoneDistDgftMax]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(4)
      color = isColorOrWhite(color)
      fillColor = 0
      size
      opacity = RADAR_LINES_OPACITY
      commands
    }
  }
}

let distanceGateWidthRelMin = 0.05
let angularGateWidthMultSquare = 4.0

let distanceGateWidthMult = 1.0
let iffDistRelMult = 0.5

function createTargetOnRadarSquare(index, radius, size, color) {
  let watches = freeze([HasAzimuthScale, HasDistanceScale, IsRadar2Visible, AzimuthHalfWidth2, AzimuthHalfWidth, DistanceGateWidthRel, VelocitySearch])

  return function() {
    let res = { watch = watches }
    let target = targets[index]

    if (target == null)
      return res

    let opacity = (1.0 - target.ageRel) * target.signalRel

    local angleRel = 0.5
    local angularWidthRel = 1.0
    if (HasAzimuthScale.get()) {
      angleRel = target.azimuthRel
      angularWidthRel = target.azimuthWidthRel
    }
    let angleLeft = angleRel - 0.5 * angularWidthRel
    let angleRight = angleRel + 0.5 * angularWidthRel

    local distanceRel = 0.9
    local radialWidthRel = 0.05
    if (HasDistanceScale.get() && target.distanceRel >= 0.0) {
      distanceRel = target.distanceRel
      radialWidthRel = target.distanceWidthRel
    }

    local selectionFrame = null

    let frameCommands = []

    let azimuthHalfWidth = IsRadar2Visible.get() ? AzimuthHalfWidth2.get() : AzimuthHalfWidth.get()
    let angularGateHalfWidthRel = angularGateWidthMultSquare * azimuthHalfWidth / AzimuthRange.get()
    let angleGateLeftRel = angleRel - angularGateHalfWidthRel
    let angleGateRightRel = angleRel + angularGateHalfWidthRel

    let distanceGateHalfWidthRel = 0.5 * max(DistanceGateWidthRel.get(), distanceGateWidthRelMin) * distanceGateWidthMult
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
      let iffMarkDistanceRel = VelocitySearch.get() ? 0.9 : distanceRel + (0.5 + iffDistRelMult) * radialWidthRel
      frameCommands.append(
        [ VECTOR_LINE,
          100 * angleLeft,
          100 * (1 - iffMarkDistanceRel),
          100 * angleRight,
          100 * (1 - iffMarkDistanceRel)
        ]
      )
    }

    selectionFrame = target.isSelected ? {
        rendObj = ROBJ_VECTOR_CANVAS
        size
        lineWidth = hdpx(3)
        color = isColorOrWhite(color)
        fillColor = 0
        pos = [radius, radius]
        commands = frameCommands
        animations = [{ prop = AnimProp.opacity, from = 0.0, to = 1, duration = 0.5, play = SelectedTargetBlinking.get(), loop = true, easing = InOutSine, trigger = frameTrigger }]
      } : {
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
      fillColor = color
      color = isColorOrWhite(color)
      opacity
      transform = {
        pivot = [0.5, 0.5]
        translate = [
          -radius,
          -radius
        ]
      }
      children = selectionFrame
    }).__update(
      target.isSelected && HasAzimuthScale.get() ?
      {
        lineWidth = hdpx(2)
        commands = target.losSpeed < 3000.0 ?
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
            [ VECTOR_ELLIPSE,
              100 * angleRel,
              100 * (1 - distanceRel),
              2,
              2 ]
          ]
      } :
      {
        lineWidth = 100 * radialWidthRel
        commands = [
          [ VECTOR_LINE,
            100 * angleLeft,
            100 * (1 - distanceRel),
            100 * angleRight,
            100 * (1 - distanceRel) ]
        ]
      }
    )
  }
}


function arrowIcon(size, color) {
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = defLineWidth
    color
    fillColor = color
    size
    commands = [
      [VECTOR_POLY, 50, 0,  0, 50,  35, 50,  35, 100,
        65, 100,  65, 50,  100, 50]
    ]
  }
}


function groundNoiseIcon(size, color) {
  return {
    size
    children = [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size
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


function noiseSignalComponent(signalWatched, size, isIconOnLeftSide, color) {

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

let showSignal = Computed(@() IsNoiseSignaVisible.get() && !MfdRadarEnabled.get())
let showSignal1 = Computed(@() showSignal.get() && IsRadarVisible.get() && NoiseSignal.get() > 0.5)
let showSignal2 = Computed(@() showSignal.get() && IsRadar2Visible.get() && NoiseSignal2.get() > 0.5)

function mkNoiseSignalComp1(size, color, ovr = {}) {
  let noize = noiseSignalComponent(NoiseSignal, size, true, color)
  return @() {
    watch = showSignal1
    size = [2 * size[0] + size[1] * 0.2, SIZE_TO_CONTENT]
    children =  showSignal1.get() ? noize : null
  }.__merge(ovr)
}

function mkNoiseSignalComp2(size, color, ovr = {}) {
  let noize = noiseSignalComponent(NoiseSignal2, size, true, color)
  return @() {
    watch = showSignal2
    size = [2 * size[0] + size[1] * 0.2, SIZE_TO_CONTENT]
    children =  showSignal2.get() ? noize : null
  }.__merge(ovr)
}

let noiseSignal = @(size, pos1, pos2, color) {
  children = [
    mkNoiseSignalComp1(size, color, { size, pos = pos1 }),
    mkNoiseSignalComp2(size, color, { size, pos = pos2 })]
}

let noiseSignalSplited = @(size, color) {
  signal1 = mkNoiseSignalComp1(size, color)
  signal2 = mkNoiseSignalComp2(size, color)
}

let radToDeg = 180.0 / 3.14159

function getRadarModeText(radarModeNameWatch, isRadarVisibleWatch) {
  let texts = []
  if (radarModeNameWatch.value in modeNames)
    texts.append(loc(modeNames[radarModeNameWatch.value]))
  else if (isRadarVisibleWatch.value)
    texts.append(Irst.get() ? loc("hud/irst") : loc("hud/radarEmitting"))
  return "".join(texts)
}


function calcFontFxFactor(color) {
  return isDarkColor(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor
}

function calcFontFxColor(color) {
  return isDarkColor(color) ? Color(255, 255, 255, 120) : Color(0, 0, 0, 120)
}

function makeRadarModeText(textConfig, color, font_size = hudFontHgt) {
  let fontFxFactor = calcFontFxFactor(color)
  let fontFxColor = calcFontFxColor(color)
  let watch = freeze([RadarModeNameId, IsRadarVisible])

  return function() {
    return styleText.__merge({
      watch
      rendObj = ROBJ_TEXT
      text = getRadarModeText(RadarModeNameId, IsRadarVisible)
      color
      fontFxFactor
      fontFxColor
      fontSize = font_size
    }).__merge(textConfig)
  }
}

function makeRadar2ModeText(textConfig, color, font_size = hudFontHgt) {
  let fontFxFactor = calcFontFxFactor(color)
  let fontFxColor = calcFontFxColor(color)
  let watch = [Radar2ModeNameId, IsRadar2Visible]

  return function() {
    return styleText.__merge({
      watch
      rendObj = ROBJ_TEXT
      text = getRadarModeText(Radar2ModeNameId, IsRadar2Visible)
      color
      fontFxFactor
      fontFxColor
      fontSize = font_size
    }).__merge(textConfig)
  }
}

let offsetScaleFactor = 1.3

function B_ScopeSquareMarkers(size, color, font_size) {
  let fontFxFactor = calcFontFxFactor(color)
  let fontFxColor = calcFontFxColor(color)

  function azimuthScanBlock() {
    return styleText.__merge({
      watch = [ ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
      rendObj = ROBJ_TEXT
      color
      fontFxFactor
      fontFxColor
      fontSize = font_size
      text = "".concat(floor((ScanAzimuthMax.get() - ScanAzimuthMin.get()) * radToDeg + 0.5), deg, "x",
              floor((ScanElevationMax.get() - ScanElevationMin.get()) * radToDeg + 0.5), deg,
              (ScanPatternsMax.get() > 1 ? "*" : " "))
    })
  }

  function distanceMaxBlock() {
    return styleText.__merge({
      watch = [VelocitySearch, DistanceMax, DistanceScalesMax]
      halign = ALIGN_RIGHT
      size = [size[0], SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXT
      color
      fontFxFactor
      fontFxColor
      fontSize = font_size
      text = "".concat(VelocitySearch.get()
              ? cross_call.measureTypes.SPEED.getMeasureUnitsText(DistanceMax.get(), true, false, false)
              : cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMax.get() * 1000.0, true, false, false),
              (DistanceScalesMax.get() > 1 ? "*" : ""))
    })
  }

  function distanceMinBlock() {
    return styleText.__merge({
      watch = [VelocitySearch, DistanceMin]
      halign = ALIGN_RIGHT
      rendObj = ROBJ_TEXT
      color
      fontFxFactor
      fontFxColor
      fontSize = font_size
      size = [size[0], SIZE_TO_CONTENT]
      text = VelocitySearch.get()
        ? cross_call.measureTypes.SPEED.getMeasureUnitsText(DistanceMin.get(), true, false, false)
        : cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMin.get() * 1000.0, true, false, false)
    })
  }

  function elevationMinBlock() {
    return styleText.__merge({
      halign = ALIGN_RIGHT
      hplace = ALIGN_RIGHT
      watch = ElevationMin
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color
      fontFxFactor
      fontFxColor
      fontSize = font_size
      pos = [0, (-ElevationMin.get() * elevMaxInv * elevMaxScreenRelSize + 0.5) * size[1]]
      text = "".concat(floor((ElevationMin.get()) * radToDeg + 0.5), deg)
    })
  }

  function elevationMaxBlock() {
    return styleText.__merge({
      halign = ALIGN_RIGHT
      hplace = ALIGN_RIGHT
      watch = ElevationMax
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color
      fontFxFactor
      fontFxColor
      fontSize = font_size
      pos = [0, (-ElevationMax.get() * elevMaxInv * elevMaxScreenRelSize + 0.5) * size[1]]
      text = "".concat(floor((ElevationMax.get()) * radToDeg + 0.5), deg)
    })
  }

  function azimuthMinBlock() {
    return styleText.__merge({
      watch = AzimuthMin
      rendObj = ROBJ_TEXT
      color = isColorOrWhite(color)
      fontFxFactor = fontOutlineFxFactor
      fontFxColor = Color(0, 0, 0, 120)
      size
      padding = hdpx(4)
      fontSize = font_size
      text = "".concat(floor(AzimuthMin.get() * radToDeg + 0.5), deg)
    })
  }

  function azimuthMaxBlock() {
    return styleText.__merge({
      halign = ALIGN_RIGHT
      watch = AzimuthMax
      rendObj = ROBJ_TEXT
      color = isColorOrWhite(color)
      fontFxFactor = fontOutlineFxFactor
      fontFxColor = Color(0, 0, 0, 120)
      size
      fontSize = font_size
      padding = hdpx(4)
      text = "".concat(floor(AzimuthMax.get() * radToDeg + 0.5), deg)
    })
  }

  function azimuthRangeBlock() {
    return styleText.__merge({
      halign = ALIGN_RIGHT
      vplace = ALIGN_BOTTOM
      watch = [AzimuthMin, AzimuthMax]
      rendObj = ROBJ_TEXT
      color = isColorOrWhite(color)
      fontFxFactor = fontOutlineFxFactor
      fontFxColor = Color(0, 0, 0, 120)
      fontSize = font_size
      margin = static [hdpx(4), 0, 0, 0]
      text = "".concat(floor((AzimuthMax.get() - AzimuthMin.get()) * radToDeg + 0.5), deg)
    })
  }

  let markers = {}

  markers.azimuthScanBlock <- @() {
    watch = [ HasAzimuthScale, ScanAzimuthMax, ScanAzimuthMin ]
    children = !HasAzimuthScale.get() || ScanAzimuthMax.get() <= ScanAzimuthMin.get() ? null
      : azimuthScanBlock
  }

  markers.azimuthMinBlock <- @() {
    watch = [ HasAzimuthScale ]
    children = !HasAzimuthScale.get() ? null : azimuthMinBlock
  }

  markers.azimuthMaxBlock <- @() {
    watch = [ HasAzimuthScale ]
    children = !HasAzimuthScale.get() ? null : azimuthMaxBlock
  }

  markers.azimuthRangeBlock <- @() {
    watch = [ HasAzimuthScale ]
    children = !HasAzimuthScale.get() ? null : azimuthRangeBlock
  }

  markers.distanceMinBlock <- @() {
    watch = [ HasDistanceScale ]
    children = !HasDistanceScale.get() ? null : distanceMinBlock
  }

  markers.distanceMaxBlock <- @() {
    watch = [ HasDistanceScale ]
    children = !HasDistanceScale.get() ? null : distanceMaxBlock
  }

  markers.elevationMinBlock <- @() {
    watch = [ HasAzimuthScale ]
    children = !HasAzimuthScale.get() ? null
      : elevationMinBlock
  }

  markers.elevationMaxBlock <- @() {
    watch = [ HasAzimuthScale ]
    children = !HasAzimuthScale.get() ? null
      : elevationMaxBlock
  }

  markers.radarModeText <- makeRadarModeText({ pos = [size[0] * (0.5 - 0.15), hdpx(5)] margin = hdpx(font_size * 0.05) }, color, font_size)

  markers.radar2ModeText <- makeRadar2ModeText({ pos = [size[0] * (0.5 - 0.15), hdpx(5)] }, color, font_size)

  let noiseSignalSize = max(size[0] * 0.06, hdpx(20))
  markers.noiseSignal <- noiseSignalSplited(
    [noiseSignalSize, noiseSignalSize],
    color)

  return markers
}

function B_ScopeSquareCue(size, color) {
  function cue() {
    let halfAzimuthWidth = 100.0 * CueAzimuthHalfWidthRel.get()
    let halfDistGateWidth = 100.0 * 0.5 * CueDistWidthRel.get()
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

  let watch = [
    CueVisible,
    CueAzimuth, TargetRadarAzimuthWidth, AzimuthRange, CueAzimuthHalfWidthRel,
    CueDist, TargetRadarDist, CueDistWidthRel
  ]

  return function() {
    return {
      watch
      pos = [
        (CueAzimuth.get() * (TargetRadarAzimuthWidth.get() / AzimuthRange.get() - CueAzimuthHalfWidthRel.get()) + 0.5) * size[0],
        (1.0 - (0.5 * CueDistWidthRel.get() + CueDist.get() * TargetRadarDist.get() * (1.0 - CueDistWidthRel.get()))) * size[1]
      ]
      children = CueVisible.get() ? cue : null
    }
  }
}

function mkRadarPartPlaceComp(extraParams = {}) {
  return {
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    gap = hdpx(5)
  }.__update(extraParams)
}

function B_ScopeSquare(size, color, hide_back, fontScale) {
  let bkg = hide_back ? null : B_ScopeSquareBackground(size, color)
  let scopeTgtSectorComp = hide_back ? null : B_ScopeSquareTargetSectorComponent(size, TurretAzimuth, TargetRadarDist, TargetRadarAzimuthWidth, color)
  let scopeSquareAzimuthComp0 = B_ScopeSquareAzimuthComponent(size, TurretAzimuth, null, null, true, color)
  let groundReflComp = @() {
    size
    rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
    isSquare = true
    xFragments = 20
    yFragments = 10
    color = isColorOrWhite(color)
  }
  let scopeSquareAzimuthComp1 = B_ScopeSquareAzimuthComponent(size, Azimuth, Distance, AzimuthHalfWidth, false, color)
  let scopeSquareElevationComp1 = B_ScopeSquareElevationComp(size, Elevation, ElevationMin, ElevationMax, ScanElevationMin, ScanElevationMax, color)
  let scopeSquareAzimuthComp2 = B_ScopeSquareAzimuthComponent(size, Azimuth2, Distance2, AzimuthHalfWidth2, false, color)
  let scopeSquareElevationComp2 = B_ScopeSquareElevationComp(size, Elevation2, ElevationMin, ElevationMax, ScanElevationMin, ScanElevationMax, color)
  let scopeSqLaunchRangeComp = B_ScopeSquareLaunchRangeComponent(size, AamLaunchZoneDist, AamLaunchZoneDistMin, AamLaunchZoneDistMax, color,
   AamLaunchZoneDistDgftMin, AamLaunchZoneDistDgftMax)
  let tgts = targetsComponent(size, createTargetOnRadarSquare, color)
  let markers = B_ScopeSquareMarkers(size, color, fontScale)
  let cue = B_ScopeSquareCue(size, color)

  let leftPlace = {
    size = [maxLabelWidth, size[1]]
    halign = ALIGN_RIGHT
    children = [markers.azimuthRangeBlock, markers.elevationMaxBlock, markers.elevationMinBlock]
  }

  let leftContainer = {
    flow = FLOW_VERTICAL
    valign = ALIGN_BOTTOM
    children = [leftPlace,  styleText.__merge({
      rendObj = ROBJ_TEXT })]
  }

  let radarModePlace = {
    size = SIZE_TO_CONTENT
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    children = [markers.noiseSignal.signal1, markers.radarModeText]
  }

  let radar2ModePlace = {
    size = SIZE_TO_CONTENT
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    children = [markers.noiseSignal.signal2, markers.radar2ModeText]
  }

  let radarModesPlace = @() {
    watch = IsRadar2Visible
    size = [size[0], SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = hdpx(30)
    margin = static [0, 0, hdpx(5), 0]
    children = [radarModePlace, IsRadar2Visible.get() ? radar2ModePlace : null]
  }

  let markersPlace = {
    size = [size[0], SIZE_TO_CONTENT]
    children = [markers.azimuthScanBlock, markers.distanceMaxBlock]
  }

  let topPlace = {
    flow = FLOW_VERTICAL
    size = [size[0], SIZE_TO_CONTENT]
    children = [radarModesPlace, markersPlace]
  }

  let bottomPlace = {
    flow = FLOW_HORIZONTAL
    size = [size[0], SIZE_TO_CONTENT]
    children = markers.distanceMinBlock
  }

  function radar() {

    let children = [ bkg, scopeTgtSectorComp, scopeSquareAzimuthComp0, groundReflComp ]
    if (IsRadarVisible.get()) {
      if (IsRadarEmitting.get())
        children.append(scopeSquareAzimuthComp1)
      children.append(scopeSquareElevationComp1)
    }
    if (IsRadar2Visible.get()) {
      if (IsRadar2Emitting.get())
        children.append(scopeSquareAzimuthComp2)
      children.append(scopeSquareElevationComp2)
    }
    if (IsAamLaunchZoneVisible.get() && HasDistanceScale.get())
      children.append(scopeSqLaunchRangeComp)
    children.append(tgts)
    children.append(cue)
    return {
      watch = [ IsRadarVisible, IsRadarEmitting, IsRadar2Visible, IsRadar2Emitting, IsAamLaunchZoneVisible,
        HasDistanceScale ]
      size = SIZE_TO_CONTENT
      clipChildren = true
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children
    }
  }

  let centralPlace = {
    size
    children = [radar, markers.azimuthMinBlock, markers.azimuthMaxBlock]
  }

  let middlePlace = {
    flow = FLOW_VERTICAL
    gap = hdpx(3)
    children = [topPlace, centralPlace, bottomPlace]
  }

  return mkRadarPartPlaceComp({
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    children = [leftContainer, middlePlace]
  })
}

function B_ScopeBackground(size, color) {

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

  function gridSecondary() {
    let commands = HasDistanceScale.get() ?
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
    for (local i = 0; i < dashCount; ++i) {
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
      commands
    }
  }

  return {
    children = [
      circle
      gridSecondary
    ]
  }
}

function B_ScopeAzimuthComponent(size, valueWatched, distWatched, halfWidthWatched, color, lineWidth = hdpx(LINE_WIDTH)) {
  let showPart1 = (!distWatched || !halfWidthWatched)
                  ? Watched(false)
                  : Computed(@() distWatched.value == 1.0 && (halfWidthWatched.value ?? 0) > 0) 

  function part1() {
    let angleCenter = AzimuthMin.get() + AzimuthRange.get() * valueWatched.value - PI * 0.5
    let angleStart = angleCenter - halfWidthWatched.value
    let angleFinish = angleCenter + halfWidthWatched.value
    let sectorCommands = [VECTOR_SECTOR, 50, 50, 50, 50, angleStart * radToDeg, angleFinish * radToDeg]

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

  function part2() {
    let angle = AzimuthMin.get() + AzimuthRange.get() * valueWatched.value - PI * 0.5
    let distV = distWatched?.value
    let commands = distV != null ? [VECTOR_LINE_DASHED] : [VECTOR_LINE]
    commands.append(
      50, 50,
      50.0 + 50.0 * (distV ?? 1.0) * cos(angle),
      50.0 + 50.0 * (distV ?? 1.0) * sin(angle)
    )
    if (distV != null)
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
    children = showPart1.get() ? part1 : part2
  }
}

let B_ScopeElevationComp = @(size, elev_rel, elev_min, elev_max, elev_scan_min, elev_scan_max, azimuth_min, color) function() {

  let elevMaxScreenSize = 50 * elevMaxScreenRelSize
  let elevationMin = elev_min.value * elevMaxInv * elevMaxScreenSize + 25
  let elevationMax = elev_max.value * elevMaxInv * elevMaxScreenSize + 25
  let elevationZero = 25
  let elevation = elevationMin * (1.0 - elev_rel.value) + elevationMax * elev_rel.value

  let cosa = cos(azimuth_min.value)
  let sina = sin(azimuth_min.value)

  let markLen = 3
  let markLenShort = 2

  let commands = [
    [VECTOR_LINE, 50.0 + elevationMin  * sina, 50.0 - elevationMin  * cosa, 50.0 + elevationMin  * sina - markLen * cosa, 50.0 - elevationMin  * cosa - markLen * sina],
    [VECTOR_LINE, 50.0 + elevationZero * sina, 50.0 - elevationZero * cosa, 50.0 + elevationZero * sina - markLenShort * cosa, 50.0 - elevationZero * cosa - markLenShort * sina],
    [VECTOR_LINE, 50.0 + elevationMax  * sina, 50.0 - elevationMax  * cosa, 50.0 + elevationMax  * sina - markLen * cosa, 50.0 - elevationMax  * cosa - markLen * sina],
    [VECTOR_LINE, 50.0 + elevation  * sina, 50.0 - elevation  * cosa, 50.0 + elevation  * sina - markLenShort * cosa, 50.0 - elevation  * cosa - markLenShort * sina]
  ]

  if (elev_scan_max.value > elev_scan_min.value) {
    let elevationScanMin = elev_scan_min.value * elevMaxInv * elevMaxScreenSize + 25
    let elevationScanMax = elev_scan_max.value * elevMaxInv * elevMaxScreenSize + 25
    commands.append([VECTOR_LINE, 50.0 + elevationScanMin  * sina, 50.0 - elevationScanMin  * cosa, 50.0 + elevationScanMin  * sina - markLen * cosa, 50.0 - elevationScanMin  * cosa - markLen * sina])
    commands.append([VECTOR_LINE, 50.0 + elevationScanMax  * sina, 50.0 - elevationScanMax  * cosa, 50.0 + elevationScanMax  * sina - markLen * cosa, 50.0 - elevationScanMax  * cosa - markLen * sina])
  }

  return {
    watch = [elev_rel, elev_min, elev_max, elev_scan_min, elev_scan_max, azimuth_min]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(4)
    color = isColorOrWhite(color)
    fillColor = 0
    size
    opacity = RADAR_LINES_OPACITY
    commands
  }
}

let rad2deg = 180.0 / PI

function B_ScopeHalfLaunchRangeComponent(size, azimuthMin, azimuthMax, aamLaunchZoneDistMin, aamLaunchZoneDistMax, aamLaunchZoneDistDgftMax, color) {
  let watch = [azimuthMin, azimuthMax, aamLaunchZoneDistMin, aamLaunchZoneDistMax, aamLaunchZoneDistDgftMax]

  return function() {
    let scanAngleStart = azimuthMin.value - PI * 0.5
    let scanAngleFinish = azimuthMax.value - PI * 0.5
    let scanAngleStartDeg = scanAngleStart * rad2deg
    let scanAngleFinishDeg = scanAngleFinish * rad2deg

    let commands = [
      [VECTOR_SECTOR, 50, 50, aamLaunchZoneDistMin.value * 50, aamLaunchZoneDistMin.value * 50, scanAngleStartDeg, scanAngleFinishDeg],
      [VECTOR_SECTOR, 50, 50, aamLaunchZoneDistMax.value * 50, aamLaunchZoneDistMax.value * 50, scanAngleStartDeg, scanAngleFinishDeg],
      (aamLaunchZoneDistDgftMax.value > 0.0 ? [VECTOR_SECTOR, 50, 50, aamLaunchZoneDistDgftMax.value * 50, aamLaunchZoneDistDgftMax.value * 50, scanAngleStartDeg, scanAngleFinishDeg] : [])
    ]

    let children = {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(4)
      color = isColorOrWhite(color)
      fillColor = 0
      size
      opacity = RADAR_LINES_OPACITY
      commands
    }

    return styleLineForeground.__merge({
      children
      watch
    })
  }
}


local B_ScopeSectorComponent = @(size, valueWatched, distWatched, halfWidthWatched, color) function() {
  let show = (distWatched == null || halfWidthWatched == null) ? Watched(false) : Computed(@() halfWidthWatched.value > 0)
  halfWidthWatched = halfWidthWatched ?? Watched(0.0)
  distWatched = distWatched ?? Watched(1.0)

  function children() {
    let angleCenter = AzimuthMin.get() + AzimuthRange.get() *
      (valueWatched?.value ?? 0.5) - PI * 0.5
    let angleStart = angleCenter - halfWidthWatched.value
    let angleFinish = angleCenter + halfWidthWatched.value
    let sectorCommands = [VECTOR_SECTOR, 50, 50, 50 * distWatched.value, 50 * distWatched.value, angleStart * radToDeg, angleFinish * radToDeg]

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

function calcAngularGateWidthPolar(distance_rel, azimuth_half_width) {
  if (azimuth_half_width > 0.17)
    return 2.0
  let blend = min((distance_rel - angularGateWidthMultMinDistanceRelPolar) / (angularGateWidthMultMaxDistanceRelPolar - angularGateWidthMultMinDistanceRelPolar), 1.0)
  return angularGateWidthMultMinPolar * blend + angularGateWidthMultMaxPolar * (1.0 - blend)
}

let createTargetOnRadarPolar = @(index, radius, size, color) function() {

  let res = { watch = [HasAzimuthScale, AzimuthMin, AzimuthRange, HasDistanceScale, VelocitySearch] }

  let target = targets[index]

  if (target == null)
    return res

  local angle = -PI * 0.5
  local angularWidth = AzimuthRange.get()
  if (HasAzimuthScale.get()) {
    angle = AzimuthMin.get() + AzimuthRange.get() * target.azimuthRel - PI * 0.5
    angularWidth = AzimuthRange.get() * target.azimuthWidthRel
  }
  let angleLeftDeg = (angle - 0.5 * angularWidth) * 180.0 / PI
  let angleRightDeg = (angle + 0.5 * angularWidth) * 180.0 / PI

  local distanceRel = 0.9
  local radialWidthRel = 0.05
  if (HasDistanceScale.get() && target.distanceRel >= 0.0) {
    distanceRel = target.distanceRel
    radialWidthRel = target.distanceWidthRel
  }

  let azimuthHalfWidth = IsRadar2Visible.get() ? AzimuthHalfWidth2.get() : AzimuthHalfWidth.get()
  let angularGateWidthMult = calcAngularGateWidthPolar(distanceRel, azimuthHalfWidth)
  let angularGateWidth = angularGateWidthMult * 2.0 * max(azimuthHalfWidth, angularGateBeamWidthMin)
  local angleGateLeft  = angle - 0.5 * angularGateWidth
  local angleGateRight = angle + 0.5 * angularGateWidth
  if (AzimuthMax.get() - AzimuthMin.get() < PI) {
    angleGateLeft  = max(angleGateLeft, AzimuthMin.get() - PI * 0.5)
    angleGateRight = min(angleGateRight, AzimuthMax.get() - PI * 0.5)
  }
  let distanceGateHalfWidthRel = 0.5 * max(DistanceGateWidthRel.get(), distanceGateWidthRelMin) * distanceGateWidthMult
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
    let iffMarkDistanceRel = VelocitySearch.get() ? 0.9 : distanceRel + (0.5 + iffDistRelMult) * radialWidthRel
    frameCommands.append(
      [ VECTOR_SECTOR, 50, 50, 50 * iffMarkDistanceRel, 50 * iffMarkDistanceRel, angleLeftDeg, angleRightDeg ]
    )
  }

  let targetSelectedAnim = [
    { prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.5, play = SelectedTargetBlinking.get(), loop = true, easing = InOutSine, trigger = frameTrigger }
  ]

  let selectionFrame = {
    rendObj = ROBJ_VECTOR_CANVAS
    size
    lineWidth = hdpx(3)
    color = isColorOrWhite(color)
    fillColor = 0
    pos = [radius, radius]
    commands = frameCommands
    animations = target.isSelected ? targetSelectedAnim : null
  }

  return res.__update({
    rendObj = ROBJ_VECTOR_CANVAS
    size
    lineWidth = hdpx(2)
    color = isColorOrWhite(color)
    fillColor = 0
    opacity = (1.0 - targets[index].ageRel) * target.signalRel
    transform = {
      pivot = [0.5, 0.5]
      translate = [
        -radius,
        -radius
      ]
    }
    children = selectionFrame
  }).__update(
    target.isSelected && HasAzimuthScale.get() ?
    {
      lineWidth = hdpx(2)
      commands = target.losSpeed < 3000.0 ?
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
            50 + 50 * (sina * distanceRel + (sina * target.losSpeed - cosa * target.losHorSpeed) * 0.0002) ]
        ] :
        [
          [ VECTOR_ELLIPSE,
            50 + 50 * cosa * distanceRel,
            50 + 50 * sina * distanceRel,
            2,
            2 ]
        ]
    } :
    {
      lineWidth = 100 * radialWidthRel
      commands = [
        [ VECTOR_SECTOR,
          50, 50,
          50 * distanceRel,
          50 * distanceRel,
          angleLeftDeg, angleRightDeg ]
      ]
    }
  )
}

function B_ScopeCircleMarkers(size, color) {
  let fontFxFactor = calcFontFxFactor(color)
  let fontFxColor = calcFontFxColor(color)
  let markers = {}
  markers.deg0 <- styleText.__merge({
    rendObj = ROBJ_TEXT
    fontFxFactor
    fontFxColor
    text = $"0{deg}"
  })

  markers.deg90 <- styleText.__merge({
    rendObj = ROBJ_TEXT
    fontFxFactor
    fontFxColor
    text = $"90{deg}"
  })

  markers.deg180 <- styleText.__merge({
    rendObj = ROBJ_TEXT
    hplace = ALIGN_CENTER
    fontFxFactor
    fontFxColor
    text = $"180{deg}"
  })

  markers.deg270 <- styleText.__merge({
    rendObj = ROBJ_TEXT
    fontFxFactor
    fontFxColor
    text = $"270{deg}"
  })
  markers.radar1 <- makeRadarModeText({ size = FLEX_H halign = ALIGN_RIGHT margin = hdpx(3) }, color)
  markers.radar2 <- makeRadar2ModeText({ size = FLEX_H margin = hdpx(3) }, color)

  let hideMeasures = Computed(@() !HasAzimuthScale.get() || ScanAzimuthMax.get() <= ScanAzimuthMin.get())
  let measuresComp = @() styleText.__merge({
      watch = [ ScanAzimuthMin, ScanAzimuthMax,
                ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
      rendObj = ROBJ_TEXT
      fontFxFactor
      fontFxColor
      text = "".concat(floor((ScanAzimuthMax.get() - ScanAzimuthMin.get()) * radToDeg + 0.5), deg,
        "x", floor((ScanElevationMax.get() - ScanElevationMin.get()) * radToDeg + 0.5), deg,
        (ScanPatternsMax.get() > 1 ? "*" : ""))
  })
  let velocityComp = @() styleText.__merge({
      rendObj = ROBJ_TEXT
      watch = [VelocitySearch, DistanceMax, DistanceScalesMax ]
      fontFxFactor
      fontFxColor
      text = "".concat(VelocitySearch.get()
                ? cross_call.measureTypes.SPEED.getMeasureUnitsText(DistanceMax.get(), true, false, false)
                : cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMax.get() * 1000.0, true, false, false),
                (DistanceScalesMax.get() > 1 ? "*" : " "))
  })

  markers.measuresComp <- @() {
    watch = hideMeasures
    size = [maxMeasuresCompWidth(), SIZE_TO_CONTENT]
    halign = ALIGN_RIGHT
    children =  hideMeasures.get() ? null : measuresComp
  }

  markers.velocityComp <- @() {
    watch = HasDistanceScale
    children = !HasDistanceScale.get() ? null : velocityComp
  }

  markers.noiseSignal <- noiseSignal(
    [size[0] * 0.06, size[0] * 0.06],
    [size[0] * (0.5 - 0.30), -hdpx(25)],
    [size[0] * (0.5 + 0.20), -hdpx(25)],
    color)

  return markers
}

function B_ScopeCue(size, color) {
  function cue() {
    let cueAzimuth = CueAzimuth.get() * max(TargetRadarAzimuthWidth.get() - CueAzimuthHalfWidthRel.get() * AzimuthRange.get(), 0.0)
    let distRel = 0.5 * CueDistWidthRel.get() + CueDist.get() * TargetRadarDist.get() * (1.0 - CueDistWidthRel.get())
    let halfDistGateWidthRel = 0.5 * CueDistWidthRel.get()
    let radiusMin = (distRel - halfDistGateWidthRel) * 50.0
    let radiusMax = (distRel + halfDistGateWidthRel) * 50.0
    let turretAzimuth = AzimuthMin.get() + AzimuthRange.get() * TurretAzimuth.get()
    let cueAzimuthMin = turretAzimuth + cueAzimuth - CueAzimuthHalfWidthRel.get() * AzimuthRange.get()
    let cueAzimuthMax = turretAzimuth + cueAzimuth + CueAzimuthHalfWidthRel.get() * AzimuthRange.get()
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

  return function() {
    return {
      watch = CueVisible
      pos = [size[0] * 0.5, 0.0]
      children = CueVisible.get() ? cue : null
    }
  }
}

function B_Scope(size, color) {
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

  let leftPlace = mkRadarPartPlaceComp({
    halign = ALIGN_RIGHT
    children = [markers.deg270, markers.measuresComp]
  })

  let rightPlace = mkRadarPartPlaceComp({
    halign = ALIGN_LEFT
    children = [markers.deg90, markers.velocityComp]
  })

  let topPlace = mkRadarPartPlaceComp({
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    size = [flex(), maxLabelHeight]
    children = [markers.radar1, markers.deg0, markers.radar2]
  })

  return function() {
    let children = [ bkg, azComp1, azComp2, sectorComp ]
    if (IsRadarVisible.get() && IsRadarEmitting.get())
      children.append(azComp3)
    if (IsRadar2Visible.get() && IsRadar2Emitting.get())
      children.append(azComp4)
    children.append(tgts)
    children.append(cue)
    children.append(markers.noiseSignal)

    let radar = {
      size = sizeBScope
      clipChildren = true
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children
    }

    let centerPlace = mkRadarPartPlaceComp({
      children = [topPlace, radar, markers.deg180]
    })

    let outerPlace = mkRadarPartPlaceComp({
      flow = FLOW_HORIZONTAL
      children = [leftPlace, centerPlace, rightPlace]
    })

    return {
      watch = [IsRadarVisible, IsRadarEmitting, IsRadar2Visible, IsRadar2Emitting]
      children =  outerPlace
    }
  }
}

function B_ScopeHalfBackground(size, color) {
  let angleLimStartS = Computed(@() AzimuthMin.get() - PI * 0.5)
  let angleLimFinishS = Computed(@() AzimuthMax.get() - PI * 0.5)
  let distMinRelW = Computed(@() DistanceMin.get() / max(DistanceMax.get(), 1.0))

  function circle() {
    let angleLimStart = angleLimStartS.get()
    let angleLimFinish = angleLimFinishS.get()
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

  let scanAngleStartS = Computed(@() ScanAzimuthMin.get() - PI * 0.5)
  let scanAngleFinishS = Computed(@() ScanAzimuthMax.get() - PI * 0.5)

  const angleGrad = 15.0
  let angle = PI * angleGrad / 180.0
  let dashCount = 360.0 / angleGrad
  let defSecGrid = []
  let gridSecondaryCom = Computed(function() {
    local scanAngleStart
    local scanAngleFinish
    if (scanAngleFinishS.get() > scanAngleStartS.get()) {
      scanAngleStart = scanAngleStartS.get()
      scanAngleFinish = scanAngleFinishS.get()
    }
    else {
      scanAngleStart = angleLimStartS.get()
      scanAngleFinish = angleLimFinishS.get()
    }
    let scanAngleStartDeg = scanAngleStart * rad2deg
    let scanAngleFinishDeg = scanAngleFinish * rad2deg

    let distanceMinR = 50.0 * distMinRelW.get()
    local res = null
    if (HasDistanceScale.get()) {
      res = []
      local range = 12.5
      while (range < 37.5 + 1.0) {
        if (range > distanceMinR)
          res.append([VECTOR_SECTOR, 50, 50, range, range, scanAngleStartDeg, scanAngleFinishDeg])
        range = range + 12.5
      }
      res.append([VECTOR_SECTOR, 50, 50, distanceMinR, distanceMinR, scanAngleStartDeg, scanAngleFinishDeg])
    }
    else
      res = defSecGrid

    for (local i = 0; i < dashCount; ++i) {
      let currAngle = i * angle
      if (currAngle < scanAngleStart + 2 * PI || currAngle > scanAngleFinish + 2 * PI)
        continue

      res.append([
        VECTOR_LINE,
        50 + cos(currAngle) * distanceMinR,
        50 + sin(currAngle) * distanceMinR,
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
    commands = gridSecondaryCom.get()
  }

  function gridMain() {
    let scanAngleStart = scanAngleStartS.get()
    let scanAngleFinish = scanAngleFinishS.get()

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

let B_ScopeHalfCircleTopMarkers = @(size, color) function() {
  let isVisible = IsRadarVisible.get() || IsRadar2Visible.get()
  return {
    watch = [IsRadarVisible, IsRadar2Visible]
    size = static [SIZE_TO_CONTENT, hdpx(25)]
    children = !isVisible ? null : [
      makeRadarModeText({ pos = [size[0] * (0.5 - 0.15), hdpx(5)] }, color)
      makeRadar2ModeText({ pos = [size[0] * (0.5 + 0.05), hdpx(5)] }, color)
      noiseSignal(
        [size[0] * 0.06, size[1] * 0.06],
        [size[0] * (0.5 - 0.30), 0],
        [size[0] * (0.5 + 0.20), 0],
        color)
    ]
  }
}

let B_ScopeHalfCircleMarkers = @(size, color, font_size) function() {
  let res = { watch = [IsRadarVisible, IsRadar2Visible, HasDistanceScale,
                         HasAzimuthScale, ScanAzimuthMax, ScanAzimuthMin] }

  let hiddenText = !IsRadarVisible.get() && !IsRadar2Visible.get()

  if (hiddenText)
    return res

  let scanRangeX = size[0] * 0.51
  let scanRangeY = size[1] * 0.55
  let scanYaw = size[0] * 0.67
  let scanPitch = size[0] * 0.51
  return res.__update({
    size = [offsetScaleFactor * size[0], offsetScaleFactor * size[1]]
    children = [
      {
        size = static [0, SIZE_TO_CONTENT]
        children = !HasAzimuthScale.get() || ScanAzimuthMax.get() <= ScanAzimuthMin.get() ? null
          : @() styleText.__merge({
            watch = [ ScanAzimuthMin, ScanAzimuthMax,
                      ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
            rendObj = ROBJ_TEXT
            size = SIZE_TO_CONTENT
            color
            fontFxFactor = calcFontFxFactor(color)
            fontFxColor = calcFontFxColor(color)
            fontSize = font_size
            pos = [scanRangeX, scanRangeY]
            hplace = ALIGN_CENTER
            text = "".concat(floor((ScanAzimuthMax.get() - ScanAzimuthMin.get()) * radToDeg + 0.5), deg, "x",
                            floor((ScanElevationMax.get() - ScanElevationMin.get()) * radToDeg + 0.5), deg,
                            (ScanPatternsMax.get() > 1 ? "*" : " "))
          })
      }
      !HasDistanceScale.get() ? null
        : @() styleText.__merge({
          watch = [ VelocitySearch, DistanceMax, DistanceScalesMax ]
          rendObj = ROBJ_TEXT
          size = SIZE_TO_CONTENT
          color
          fontFxFactor = calcFontFxFactor(color)
          fontFxColor = calcFontFxColor(color)
          fontSize = font_size
          pos = [scanYaw, scanPitch]
          text =  "".concat(VelocitySearch.get()
                    ? cross_call.measureTypes.SPEED.getMeasureUnitsText(
                      DistanceMax.get(), true, false, false)
                    : cross_call.measureTypes.DISTANCE.getMeasureUnitsText(
                      DistanceMax.get() * 1000.0, true, false, false),
                    (DistanceScalesMax.get() > 1
                      ? "*"
                      : " "))
      })
      !HasAzimuthScale.get() ? null
      : @() styleText.__merge({
        halign = ALIGN_RIGHT
        valign = ALIGN_TOP
        watch = [ElevationMin, AzimuthMin]
        size = [size[0], size[1]]
        rendObj = ROBJ_TEXT
        color
        fontFxFactor = calcFontFxFactor(color)
        fontFxColor = calcFontFxColor(color)
        pos = [
          (0.5 + (0.25 + 0.5 * ElevationMin.get() * elevMaxInv * elevMaxScreenRelSize) * sin(AzimuthMin.get()) - 0.03 * cos(AzimuthMin.get()) - 1.0) * size[0],
          (0.5 - (0.25 + 0.5 * ElevationMin.get() * elevMaxInv * elevMaxScreenRelSize) * cos(AzimuthMin.get()) - 0.03 * sin(AzimuthMin.get()) - 0.0) * size[1]
        ]
        text = "".concat(floor((ElevationMin.get()) * radToDeg + 0.5), deg)
      })
      !HasAzimuthScale.get() ? null
      : @() styleText.__merge({
        halign = ALIGN_RIGHT
        valign = ALIGN_TOP
        watch = [ElevationMax, AzimuthMin]
        size = [size[0], size[1]]
        rendObj = ROBJ_TEXT
        color
        fontFxFactor = calcFontFxFactor(color)
        fontFxColor = calcFontFxColor(color)
        pos = [
          (0.5 + (0.25 + 0.5 * ElevationMax.get() * elevMaxInv * elevMaxScreenRelSize) * sin(AzimuthMin.get()) - 0.03 * cos(AzimuthMin.get()) - 1.0) * size[0],
          (0.5 - (0.25 + 0.5 * ElevationMax.get() * elevMaxInv * elevMaxScreenRelSize) * cos(AzimuthMin.get()) - 0.03 * sin(AzimuthMin.get()) - 0.0) * size[1]
        ]
        text = "".concat(floor((ElevationMax.get()) * radToDeg + 0.5), deg)
      })
    ]
  })
}

let B_ScopeHalfCue = @(size, color) function() {
  function cue() {
    let cueAzimuth = CueAzimuth.get() * max(TargetRadarAzimuthWidth.get() - CueAzimuthHalfWidthRel.get() * AzimuthRange.get(), 0.0)
    let distRel = 0.5 * CueDistWidthRel.get() + CueDist.get() * TargetRadarDist.get() * (1.0 - CueDistWidthRel.get())
    let halfDistGateWidthRel = 0.5 * CueDistWidthRel.get()
    let radiusMin = (distRel - halfDistGateWidthRel) * 50.0
    let radiusMax = (distRel + halfDistGateWidthRel) * 50.0
    let cueAzimuthMin = cueAzimuth - CueAzimuthHalfWidthRel.get() * AzimuthRange.get()
    let cueAzimuthMax = cueAzimuth + CueAzimuthHalfWidthRel.get() * AzimuthRange.get()
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
    children = CueVisible.get() ? cue : null
  }
}

function B_ScopeHalf(size, color, fontScale) {
  let bkg = B_ScopeHalfBackground(size, color)
  let sector = B_ScopeSectorComponent(size, null, TargetRadarDist, TargetRadarAzimuthWidth, color)
  let reflections = @() {

    size
    color = isColorOrWhite(color)
    rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
    isSquare = false
    xFragments = 16
    yFragments = 8
  }

  let sizeBScopeHalf = [size[0] + hdpx(2), 0.5 * size[1]]
  let topMarkers = B_ScopeHalfCircleTopMarkers(size, color)
  let markers = B_ScopeHalfCircleMarkers(size, color, fontScale)
  let cue = B_ScopeHalfCue(size, color)
  let az1 = B_ScopeAzimuthComponent(size, Azimuth, Distance, AzimuthHalfWidth, color)
  let el1 = B_ScopeElevationComp(size, Elevation, ElevationMin, ElevationMax, ScanElevationMin, ScanElevationMax, AzimuthMin, color)
  let az2 = B_ScopeAzimuthComponent(size, Azimuth2, Distance2, AzimuthHalfWidth2, color)
  let el2 = B_ScopeElevationComp(size, Elevation2, ElevationMin, ElevationMax, ScanElevationMin, ScanElevationMax, AzimuthMin, color)
  let aamLaunch = B_ScopeHalfLaunchRangeComponent(size, AzimuthMin, AzimuthMax,
                                                      AamLaunchZoneDistMin, AamLaunchZoneDistMax, AamLaunchZoneDistDgftMax, color)
  let tgts = targetsComponent(size, createTargetOnRadarPolar, color)
  return function() {
    let children = [ bkg, sector, reflections ]
    if (IsRadarVisible.get()) {
      if (IsRadarEmitting.get())
        children.append(az1)
      children.append(el1)
    }
    if (IsRadar2Visible.get()) {
      if (IsRadar2Emitting.get())
        children.append(az2)
      children.append(el2)
    }
    if (IsAamLaunchZoneVisible.get() && HasDistanceScale.get())
      children.append(aamLaunch)
    children.append(tgts)
    return {
      watch = [IsRadarVisible, IsRadarEmitting, IsRadar2Visible, IsRadar2Emitting, HasDistanceScale, IsAamLaunchZoneVisible]
      pos = [maxLabelWidth, 0]
      flow = FLOW_VERTICAL
      children = [
        topMarkers,
        {
          children = [
            {
              size = sizeBScopeHalf
              halign = ALIGN_CENTER
              clipChildren = true
              children
            },
            markers,
            cue
          ]
        }
      ]
    }
  }
}

function C_ScopeSquareBackground(size, color) {

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

  let offsetRelW = Computed(@() 0.5 + ElevationMin.get() * ElevationRangeInv.get())
  function crosshair() {
    return {
      watch = offsetRelW
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(3)
      color = isColorOrWhite(color)
      size
      opacity = 0.62
      commands = [
        [VECTOR_LINE, 50, 0, 50, 100],
        [VECTOR_LINE, 0, 50 + 100.0 * offsetRelW.get(), 100, 50 + 100.0 * offsetRelW.get()],
      ]
    }
  }

  return function() {
    let scanAzimuthMinRelW = Computed(@() ScanAzimuthMin.get() * AzimuthRangeInv.get())
    let scanAzimuthMaxRelW = Computed(@() ScanAzimuthMax.get() * AzimuthRangeInv.get())
    local scanAzimuthMinRel = null
    local scanAzimuthMaxRel = null
    if (scanAzimuthMinRelW.get() <= scanAzimuthMaxRelW.get()) {
      scanAzimuthMinRel = scanAzimuthMinRelW.get()
      scanAzimuthMaxRel = scanAzimuthMaxRelW.get()
    } else {
      scanAzimuthMinRel = -0.5
      scanAzimuthMaxRel =  0.5
    }

    let scanElevationMinRelW = Computed(@() (ScanElevationMin.get() - ElevationHalfWidth.get()) * ElevationRangeInv.get())
    let scanElevationMaxRelW = Computed(@() (ScanElevationMax.get() + ElevationHalfWidth.get()) * ElevationRangeInv.get())
    local scanElevationMinRel = null
    local scanElevationMaxRel = null
    if (scanElevationMinRelW.get() <= scanElevationMaxRelW.get()) {
      scanElevationMinRel = scanElevationMinRelW.get()
      scanElevationMaxRel = scanElevationMaxRelW.get()
    } else {
      scanElevationMinRel = -0.5 + offsetRelW.get()
      scanElevationMaxRel =  0.5 + offsetRelW.get()
    }

    let offset = 100.0 * offsetRelW.get()
    let finalColor = isColorOrWhite(color)
    let gridMain = {
      rendObj = ROBJ_VECTOR_CANVAS
      size
      color = finalColor
      fillColor = 0
      lineWidth = hdpx(2 * LINE_WIDTH)
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

    let azimuthRelStep = PI / 12.0 * AzimuthRangeInv.get()
    local azimuthRel = 0.0
    while (azimuthRel > scanAzimuthMinRel) {
      gridSecondaryCommands.append([
        VECTOR_LINE,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMaxRel * 100) + offset,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMinRel * 100) + offset
      ])
      azimuthRel -= azimuthRelStep
    }
    azimuthRel = 0.0
    while (azimuthRel < scanAzimuthMaxRel) {
      gridSecondaryCommands.append([
        VECTOR_LINE,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMaxRel * 100) + offset,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMinRel * 100) + offset
      ])
      azimuthRel += azimuthRelStep
    }

    let elevationRelStep = PI / 12.0 * ElevationRangeInv.get()
    local elevationRel = 0.0
    while (elevationRel > scanElevationMinRel) {
      gridSecondaryCommands.append([
        VECTOR_LINE,
        50 + scanAzimuthMinRel * 100, 100 - (50 + elevationRel * 100) + offset,
        50 + scanAzimuthMaxRel * 100, 100 - (50 + elevationRel * 100) + offset
      ])
      elevationRel -= elevationRelStep
    }
    elevationRel = 0.0
    while (elevationRel < scanElevationMaxRel) {
      gridSecondaryCommands.append([
        VECTOR_LINE,
        50 + scanAzimuthMinRel * 100, 100 - (50 + elevationRel * 100) + offset,
        50 + scanAzimuthMaxRel * 100, 100 - (50 + elevationRel * 100) + offset
      ])
      elevationRel += elevationRelStep
    }

    let gridSecondary = {
      rendObj = ROBJ_VECTOR_CANVAS
      size
      color
      lineWidth = defLineWidth
      opacity = RADAR_LINES_OPACITY
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

function C_ScopeSquareAzimuthComponent(size, azimuthWatched, elevatonWatched, halfAzimuthWidthWatched, halfElevationWidthWatched, color) {
  return function() {
    let azimuthRange = AzimuthRange.get()
    let halfAzimuthWidth   = 100.0 * (azimuthRange > 0 ? halfAzimuthWidthWatched.value / azimuthRange : 0)
    let halfElevationWidth = 100.0 * (azimuthRange > 0 ? halfElevationWidthWatched.value * ElevationRangeInv.get() : 0)

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
  if (HasDistanceScale.get()) {
    if (!CueVisible.get()) {
      if (!target.isDetected) {
        foreach (secondTargetId, secondTarget in targets) {
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
      inSelectedTargetRangeGate = fabs(target.distanceRel - CueDist.get() * TargetRadarDist.get()) < 0.5 * CueDistWidthRel.get()
  }
  else
    inSelectedTargetRangeGate = true

  local opacity = (1.0 - target.ageRel) * target.signalRel
  if (!inSelectedTargetRangeGate)
    opacity = 0

  let azimuthRel = HasAzimuthScale.get() ? target.azimuthRel : 0.0
  let azimuthWidthRel = target.azimuthWidthRel
  let azimuthLeft = azimuthRel - azimuthWidthRel * 0.5

  let elevationRel = target.elevationRel
  let elevationWidthRel = target.elevationWidthRel
  let elevationLowerRel = elevationRel - elevationWidthRel * 0.5

  let frameCommands = []
  let azimuthGateWidthRel = angularGateWidthMult * 2.0 * max(AzimuthHalfWidth.get(), angularGateBeamWidthMin) / AzimuthRange.get()
  let azimuthGateLeftRel = azimuthRel - 0.5 * azimuthGateWidthRel
  let azimuthGateRightRel = azimuthRel + 0.5 * azimuthGateWidthRel
  let elevationGateWidthRel = angularGateWidthMult * 2.0 * max(ElevationHalfWidth.get(), angularGateBeamWidthMin) * ElevationRangeInv.get()
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
        play = SelectedTargetBlinking.get(), loop = true, easing = InOutSine,
        trigger = frameTrigger
      }]
      key = SelectedTargetBlinking
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
      IsBScopeVisible.get() || !HasAzimuthScale.get() || ScanAzimuthMax.get() <= ScanAzimuthMin.get()
      ? null
      : @() styleText.__merge({
        watch = [ScanAzimuthMin, ScanAzimuthMax,
          ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
        rendObj = ROBJ_TEXT
        pos = [0, -hdpx(20)]
        color
        fontFxFactor = calcFontFxFactor(color)
        fontFxColor = calcFontFxColor(color)
        text = "".concat(floor((ScanAzimuthMax.get() - ScanAzimuthMin.get()) * radToDeg + 0.5), deg, "x",
                floor((ScanElevationMax.get() - ScanElevationMin.get()) * radToDeg + 0.5), deg,
                (ScanPatternsMax.get() > 1 ? "*" : " "))
      }),
      IsBScopeVisible.get() || !HasDistanceScale.get() ? null
      : @() styleText.__merge({
        watch = [VelocitySearch, DistanceMax, DistanceScalesMax ]
        rendObj = ROBJ_TEXT
        color
        fontFxFactor = calcFontFxFactor(color)
        fontFxColor = calcFontFxColor(color)
        pos = [size[0] * 0.75, -hdpx(20)]
        text = "".concat(VelocitySearch.get()
                ? cross_call.measureTypes.SPEED.getMeasureUnitsText(DistanceMax.get(), true, false, false)
                : cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMax.get() * 1000.0, true, false, false),
                (DistanceScalesMax.get() > 1 ? "*" : " "))
      }),
      @() styleText.__merge({
        watch = ElevationMax
        rendObj = ROBJ_TEXT
        color
        fontFxFactor = calcFontFxFactor(color)
        fontFxColor = calcFontFxColor(color)
        pos = [size[0] + hdpx(4), hdpx(4)]
        text = "".concat(floor(ElevationMax.get() * radToDeg + 0.5), deg)
      }),
      @() styleText.__merge({
        watch = [ ElevationMin, ElevationRangeInv ]
        color
        fontFxFactor = calcFontFxFactor(color)
        fontFxColor = calcFontFxColor(color)
        rendObj = ROBJ_TEXT
        pos = [size[0] + hdpx(4), (1.0 - (0.0 - ElevationMin.get()) * ElevationRangeInv.get()) * size[1] - hdpx(4)]
        text = "".concat("0", deg)
      }),
      @() styleText.__merge({
        watch = ElevationMin
        rendObj = ROBJ_TEXT
        color
        fontFxFactor = calcFontFxFactor(color)
        fontFxColor = calcFontFxColor(color)
        pos = [size[0] + hdpx(4), size[1] - hdpx(20)]
        text = "".concat(floor(ElevationMin.get() * radToDeg + 0.5), deg)
      }),
      @() styleText.__merge({
        watch = AzimuthMin
        rendObj = ROBJ_TEXT
        pos = [hdpx(4), hdpx(4)]
        color = isColorOrWhite(color)
        fontFxFactor = calcFontFxFactor(color)
        fontFxColor = calcFontFxColor(color)
        text = "".concat(floor(AzimuthMin.get() * radToDeg + 0.5), deg)
      }),
      {
        size = [size[0], SIZE_TO_CONTENT]
        children = @() styleText.__merge({
          watch = AzimuthMax
          rendObj = ROBJ_TEXT
          pos = [-hdpx(4), hdpx(4)]
          color = isColorOrWhite(color)
          hplace = ALIGN_RIGHT
          fontFxFactor = calcFontFxFactor(color)
          fontFxColor = calcFontFxColor(color)
          text = "".concat(floor(AzimuthMax.get() * radToDeg + 0.5), deg)
        })
      },
      IsBScopeVisible.get() ? null
      : makeRadarModeText({ pos = [size[0] * 0.5, -hdpx(20)] }, color),
      IsBScopeVisible.get() ? null
      : makeRadar2ModeText({ pos = [size[0] * 0.5, -hdpx(50)] }, color)
    ]
  })
}

function C_ScopeCue(size, color) {
  function cue() {
    let azimuthHalfWidth = 100 * CueAzimuthHalfWidthRel.get()
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

  return function() {
    return {
      watch = [ CueVisible, CueAzimuth, TargetRadarAzimuthWidth, AzimuthRange, CueAzimuthHalfWidthRel ]
      pos = [
        CueAzimuth.get() * max(TargetRadarAzimuthWidth.get() / AzimuthRange.get() - CueAzimuthHalfWidthRel.get(), 0.0) * size[0],
        size[1] * 0.0
      ]
      children = CueVisible.get() ? cue : null
    }
  }
}

function C_Scope(size, color) {
  let bkg = C_ScopeSquareBackground(size, color)
  let azim1 = C_ScopeSquareAzimuthComponent(size, Azimuth, Elevation, AzimuthHalfWidth, ElevationHalfWidth, color)
  let azim2 = C_ScopeSquareAzimuthComponent(size, Azimuth2, Elevation2, AzimuthHalfWidth2, ElevationHalfWidth2, color)
  let tgts = targetsComponent(size, createTargetOnRadarCScopeSquare, color)
  let markers = C_ScopeSquareMarkers(size, color)
  let cue = C_ScopeCue(size, color)

  return function() {
    let children = [bkg]
    if (IsRadarVisible.get() && IsRadarEmitting.get())
      children.append(azim1)
    if (IsRadar2Visible.get() && IsRadar2Emitting.get())
      children.append(azim2)
    children.append(tgts)

    return {
      watch = [IsRadarVisible, IsRadarEmitting, IsRadar2Visible, IsRadar2Emitting]
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

let forestallRadius = hdpx(15)

let forestallVisible = @(color) function() {
  return styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    color
    size = [2 * forestallRadius, 2 * forestallRadius]
    lineWidth = hdpx(2 * LINE_WIDTH)
    animations = [{ prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.5, play = SelectedTargetBlinking.get(), loop = true, easing = InOutSine, trigger = frameTrigger }]
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
    size = static [sw(100), sh(100)]
    children = IsForestallVisible.get() ? forestallVisible(color) : null
    watch = IsForestallVisible
  }
}

function scanZoneAzimuthComponent(color) {
  let width = sw(100)
  let height = sh(100)
  let mw = 100 / width
  let mh = 100 / height
  let lineWidth = hdpx(4)
  return function() {
    if (!IsScanZoneAzimuthVisible.get())
      return { watch = IsScanZoneAzimuthVisible }

    let { x0, y0, x1, y1 } = ScanZoneWatched.get()
    let _x0 = (x0 + x1) * 0.5
    let _y0 = (y0 + y1) * 0.5
    let px0 = (x0 - _x0) * mw
    let py0 = (y0 - _y0) * mh
    let px1 = (x1 - _x0) * mw
    let py1 = (y1 - _y0) * mh

    return {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth
      watch = [ScanZoneWatched, IsScanZoneAzimuthVisible]
      opacity = 0.3
      fillColor = 0
      size = [width, height]
      color
      pos = [_x0, _y0]
      commands = [[ VECTOR_LINE, px0, py0, px1, py1 ]]
    }
  }
}

function scanZoneElevationComponent(color) {
  let width = sw(100)
  let height = sh(100)
  let mw = 100 / width
  let mh = 100 / height
  let size = [width, height]
  let lineWidth = hdpx(4)
  let watch = [ScanZoneWatched, IsScanZoneElevationVisible]
  return function() {
    if (!IsScanZoneElevationVisible.get())
      return { watch = [IsScanZoneElevationVisible] }

    let { x2, x3, y2, y3 } = ScanZoneWatched.get()
    let _x0 = (x2 + x3) * 0.5
    let _y0 = (y2 + y3) * 0.5
    let px2 = (x2 - _x0) * mw
    let py2 = (y2 - _y0) * mh
    let px3 = (x3 - _x0) * mw
    let py3 = (y3 - _y0) * mh

    return {
      rendObj = ROBJ_VECTOR_CANVAS
      opacity = 0.3
      watch
      lineWidth
      color
      fillColor = 0
      size
      pos = [_x0, _y0]
      commands = [[ VECTOR_LINE, px2, py2, px3, py3 ]]
    }
  }
}

function lockZoneComponentCommon(IsCustomLockZoneVisible, color, animations) {
  return function() {
    let res =  { watch = [IsCustomLockZoneVisible, LockZoneWatched] }
    if (!IsCustomLockZoneVisible.value)
      return res.__update({ animations = animations })

    let width = sw(100)
    let height = sh(100)
    let mw = 100 / width
    let mh = 100 / height
    let corner = IsRadarEmitting.get() ? 0.1 : 0.02
    let lineWidth = hdpx(4)
    let size = static [sw(100), sh(100)]

    let { x0, x1, x2, x3, y0, y1, y2, y3 } = LockZoneWatched.get()
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
      animations = animations
      pos = [_x0, _y0 ]
      rendObj = ROBJ_VECTOR_CANVAS
      color
      lineWidth
      fillcolor = color
      size
      commands
    })
  }
}

function lockZoneComponent(color) {
  let animations = [{ prop = AnimProp.opacity, from = 0.0, to = 1, duration = 0.25, play = true, loop = true, easing = InOutSine }]
  let IsActiveLockZoneVisibile = Computed(@() IsLockZoneVisible.get() && IsRadarEmitting.get())
  return lockZoneComponentCommon(IsActiveLockZoneVisibile, color, animations)
}

function standbyLockZoneComponent(color) {
  let IsStandbyLockZoneVisibile = Computed(@() IsLockZoneVisible.get() && !IsRadarEmitting.get())
  return lockZoneComponentCommon(IsStandbyLockZoneVisibile, color, null)
}

function getForestallTargetLineCoords() {
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


function forestallTgtLine(color) {
  let w = sw(100)
  let h = sh(100)

  return styleLineForeground.__merge({
    color
    rendObj = ROBJ_VECTOR_CANVAS
    size = [w, h]
    lineWidth = hdpx(LINE_WIDTH)
    opacity = 0.8
    behavior = Behaviors.RtPropUpdate
    animations = [{ prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.5, play = SelectedTargetBlinking.get(), loop = true, easing = InOutSine, trigger = frameTrigger }]
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
  return !IsForestallVisible.get() ? { watch = IsForestallVisible }
  : {
    watch = IsForestallVisible
    size = static [sw(100), sh(100)]
    children = forestallTgtLine(color)
  }
}


function compassComponent(color) {
  let compassInstance = compass(compassSize, color)
  return function() {
    return {
      watch = HasCompass
      pos = [sw(50) - 0.5 * compassSize[0], sh(0.5)]
      children = HasCompass.get() ? compassInstance : null
    }
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
      commands
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

let createAzimuthMarkWithOffset = @(size, total_width, angle, is_selected, is_detected, age_rel, is_enemy, isSecondRound, color) function() {
  let offset = (isSecondRound ? total_width : 0) +
    total_width * angle / 360.0 + 0.5 * size[0]
  return {
    size = SIZE_TO_CONTENT
    pos = [offset, 0]
    children = createAzimuthMark(size, is_selected, is_detected, is_enemy, color)
    opacity = 1.0 - age_rel
  }
}

let createAzimuthMarkStrike = @(total_width, height, markerWidth, color) function() {

  let markers = []
  foreach (_id, azimuthMarker in azimuthMarkers) {
    if (!azimuthMarker)
      continue
    else if (azimuthMarker.ageRel > 1.0)
      continue
    markers.append(createAzimuthMarkWithOffset([markerWidth, height], total_width,
      azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.ageRel, azimuthMarker.isEnemy, false, color))
    markers.append(createAzimuthMarkWithOffset([markerWidth, height], total_width,
      azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.ageRel, azimuthMarker.isEnemy, true, color))
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
    + CompassValue.get() * compassOneElementWidth * 2.0 / compassStep
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

function azimuthMarkStrike(styleColor) {
  let width = compassSize[0] * 1.5
  let totalWidth = 2.0 * getCompassStrikeWidth(compassOneElementWidth, compassStep)

  return {
    pos = [sw(50) - 0.5 * width, sh(17)]
    children = [
      createAzimuthMarkStrikeComponent([width, hdpx(30)], totalWidth, styleColor)
    ]
  }
}

let mkRadarBase = @(posWatch, size, _isAir, color, mode, font_size = hudFontHgt, hide_back = false, need_shift = true) function() {

  let isSquare = mode.value == RadarViewMode.B_SCOPE_SQUARE
  let azimuthRange = AzimuthRange.get()
  let squareSize = [HasAzimuthScale.get() ? size[0] : 0.2 * size[0], size[1]]
  let sizeCScope = [size[0], size[1] * 0.42]

  local scopeChild = null
  if (IsBScopeVisible.get()) {
    if (mode.value == RadarViewMode.B_SCOPE_SQUARE) {
      if (azimuthRange > PI + 0.035)
        scopeChild = B_Scope(size, color)
      else
        scopeChild = B_ScopeSquare(squareSize, color, hide_back, font_size)
    }
    else if (mode.value == RadarViewMode.B_SCOPE_ROUND) {
      if (azimuthRange > PI + 0.035)
        scopeChild = B_Scope(size, color)
      else
        scopeChild = B_ScopeHalf(size, color, font_size)
    }
  }

  local cScope = null
  if (IsCScopeVisible.get() && !isPlayingReplay.get() && azimuthRange <= PI) {
    let pos = [maxLabelWidth + hdpx(4), isSquare
      ? (need_shift ? (size[0] * 0.5 +  hdpx(180) + 2 * maxLabelHeight) : size[0] * 0.25 + 2 * maxLabelHeight)
      : (need_shift ? (size[1] * 0.5 + hdpx(30) + 2 * maxLabelHeight) : size[1] * 0.25 + 2 * maxLabelHeight)]
    cScope = {
      pos
      children = C_Scope(sizeCScope, color)
    }
  }

  return {
    watch = [mode, IsBScopeVisible, IsCScopeVisible, HasAzimuthScale, posWatch, AzimuthRange, isPlayingReplay]
    pos = posWatch.value
    children = [scopeChild, cScope]
  }
}


function radarMfdBackground() {

  let backSize = [radarPosSize.get().w / RadarScale.get(),
    radarPosSize.get().h / RadarScale.get()]
  let backPos = [radarPosSize.get().x - (1.0 - RadarScale.get()) * 0.5 * backSize[0],
   radarPosSize.get().y - (1.0 - RadarScale.get()) * 0.5 * backSize[1]]
  return {
    watch = [radarPosSize, RadarScale]
    pos = backPos
    size = backSize
    rendObj = ROBJ_SOLID
    lineWidth = radarPosSize.get().h
    color = Color(0, 0, 0, 255)
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_LINE, 0, 50, 100, 50]
    ]
  }
}

function mkRadar(isAir = false, radar_color_watch = Watched(Color(0, 255, 0, 255))) {
  return function() {
    let res = { watch = [IsRadarHudVisible, radar_color_watch] }

    if (!IsRadarHudVisible.get())
      return res

    let color = fadeColor(radar_color_watch.value, 255);

    let radarHudVisibleChildren = !isAir ?
    [
      forestallComponent(color)
      forestallTargetLine(color)
      scanZoneAzimuthComponent(color)
      lockZoneComponent(color)
      standbyLockZoneComponent(color)
      compassComponent(color)
      azimuthMarkStrike(color)
    ] :
    [
      scanZoneAzimuthComponent(color)
      scanZoneElevationComponent(color)
      lockZoneComponent(color)
      standbyLockZoneComponent(color)
    ]

    return res.__update({
      halign = ALIGN_LEFT
      valign = ALIGN_TOP
      size = static [sw(100), sh(100)]
      children = radarHudVisibleChildren
    })
  }
}

let radarPosSizeX = Computed(@() radarPosSize.get().x - 1.0 * maxLabelWidth)
let radarPosSizeY = Computed(@() radarPosSize.get().y - 2.0 * maxLabelHeight)
let radarPosSizeW = Computed(@() radarPosSize.get().w)
let radarPosSizeH = Computed(@() radarPosSize.get().h)
let radarPos = Computed(@() [radarPosSizeX.get(), radarPosSizeY.get()])

let mkRadarForMfd = @(radarColorWatched) function() {
  let color = radarColorWatched.value
  return {
    watch = [MfdRadarEnabled, radarColorWatched, MfdRadarHideBkg, radarPosSizeW, radarPosSizeH, MfdRadarFontScale]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = static [sw(100), sh(100)]
    children = [
      MfdRadarEnabled.get() ? radarMfdBackground : null,
      MfdRadarEnabled.get()
       ? mkRadarBase(radarPos,
          [radarPosSizeW.get(), radarPosSizeH.get()],
          true, color, MfdViewMode, (MfdRadarFontScale.get() > 0 ? MfdRadarFontScale.get() : radarPosSizeH.get() / 512.0) * 30, MfdRadarHideBkg.get(), false)
       : null
    ]
  }
}

return {
  mkRadar
  mkRadarForMfd
  mode = getRadarModeText
  maxLabelWidth
  maxLabelHeight
  maxMeasuresCompWidth
}