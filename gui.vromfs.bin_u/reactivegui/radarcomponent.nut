//local frp = require("frp")
//local {isEqual} = require("std/underscore.nut")
local {round, PI, floor, cos, sin, fabs, sqrt} = require("std/math.nut")
local interopGen = require("interopGen.nut")
local compass = require("compass.nut")
local {CompassValue} = require("compassState.nut")
local {isPlayingReplay} = require("hudState.nut")
local {hudFontHgt, fontOutlineFxFactor, greenColor, greenColorGrid, fontOutlineColor, targetSectorColor} = require("style/airHudStyle.nut")

local areaBackgroundColor = Color(0,0,0,120)
local getFontSize = @(is_mfd) is_mfd ? 2*hudFontHgt : hudFontHgt

local defLineWidth = max(1.2, hdpx(1.2))

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
  fillColor = greenColor
  lineWidth = max(LINE_WIDTH, hdpx(LINE_WIDTH))
}

local function updateRadarComponentColor(radar_color) {
  styleLineForeground.__update({
    color = radar_color
    fillColor = radar_color
  })
  styleText.__update({
    color = radar_color
  })
  greenColorGrid = radar_color //!!!it a very bad idea to override params come from outside. In different places they has different value after it
  greenColor = radar_color
}

const AIM_LINE_WIDTH = 2.0
const TURRET_LINE_WIDTH = 1.0

local compassWidth = hdpx(500)
local compassHeight = hdpx(40)
local compassStep = 5.0
local compassOneElementWidth = compassHeight

local getCompassStrikeWidth = @(oneElementWidth, step) 360.0 * oneElementWidth / step

local modeNames = [ "hud/standby", "hud/search", "hud/acquisition", "hud/ACM", "hud/track", "hud/air_search", "hud/ground_search" ]

local radarState = {
  targetAspectEnabled = false
  currentTime = 0.0
  selectedTargetBlinking = false
  selectedTargetSpeedBlinking = false
}

local targets = []
local screenTargets = {}
local azimuthMarkers = {}
local forestall = {
  x = 0.0
  y = 0.0
}
local selectedTarget = {
  x = 0.0
  y = 0.0
}

local radarPosSize = Watched({
  x = 0.0
  y = 0.0
  w = 0.0
  h = 0.0
})

local IsRadarHudVisible = Watched(false)
local IsNoiseSignaVisible = Watched(false)
local MfdRadarEnabled = Watched(false)
local MfdIlsEnabled = Watched(false)
local MfdRadarColor = Watched(Color(10, 202, 10, 250))

local Speed = Watched(0.0)

  //radar 1
local IsRadarVisible = Watched(false)
local RadarModeNameId = Watched(-1)
local Azimuth = Watched(0.0)
local Elevation = Watched(0.0)
local Distance = Watched(0.0)
local AzimuthHalfWidth = Watched(0.0)
local ElevationHalfWidth = Watched(0.0)
local DistanceGateWidthRel = Watched(0.0)
local NoiseSignal = Watched(0)

  //radar 2
local IsRadar2Visible = Watched(false)
local Radar2ModeNameId = Watched(-1)
local Azimuth2 = Watched(0.0)
local Elevation2 = Watched(0.0)
local Distance2 = Watched(0.0)
local AzimuthHalfWidth2 = Watched(0.0)
local ElevationHalfWidth2 = Watched(0.0)
local NoiseSignal2 = Watched(0)

local AimAzimuth = Watched(0.0)
local TurretAzimuth = Watched(0.0)
local TargetRadarAzimuthWidth = Watched(0.0)
local TargetRadarDist = Watched(0.0)
local AzimuthMin = Watched(0)
local AzimuthMax = Watched(0)
local ElevationMin = Watched(0)
local ElevationMax = Watched(0)

local IsCScopeVisible = Watched(false)
local ScanAzimuthMin = Watched(0)
local ScanAzimuthMax = Watched(0)
local ScanElevationMin = Watched(0)
local ScanElevationMax = Watched(0)

local TargetsTrigger = Watched(0)
local ScreenTargetsTrigger = Watched(0)
local ViewMode = Watched(0)
local MfdViewMode = Watched(0)
local HasAzimuthScale = Watched(0)
local HasDistanceScale = Watched(0)
local ScanPatternsMax = Watched(0)
local DistanceMax = Watched(0)
local DistanceScalesMax = Watched(0)
local AzimuthMarkersTrigger = Watched(0)
local Irst = Watched(false)
local RadarScale = Watched(1.0)

local MfdIlsHeight = Watched(0)

local IsForestallVisible = Watched(false)

local UseLockZoneRotated = Watched(false)
local FoV = Watched(0)
local ScanZoneWatched = Watched({x0=0,x1=0,x2=0,x3=0,y0=0,y1=0,y2=0,y3=0})
local LockZoneWatched = Watched({x0=0, y0=0, x1=0, y1=0, x2=0, y2=0, x3=0, y3=0})
local IsScanZoneAzimuthVisible = Watched(false)
local IsScanZoneElevationVisible = Watched(false)
local IsLockZoneVisible = Watched(false)
local LockDistMin = Watched(0)
local LockDistMax = Watched(0)

local IsAamLaunchZoneVisible = Watched(false)
local AamLaunchZoneDist    = Watched(0.0)
local AamLaunchZoneDistMin = Watched(0.0)
local AamLaunchZoneDistMax = Watched(0.0)

local IndicationForCollapsedRadar = Watched(false)

local AzimuthRange = Computed(@() ::max(0.0, AzimuthMax.value - AzimuthMin.value))
local AzimuthRangeInv = Computed(@() AzimuthRange.value != 0 ? 1.0 / AzimuthRange.value : 1.0)
local ElevationRange = Computed(@() ::max(0.0, ElevationMax.value - ElevationMin.value))
local ElevationRangeInv = Computed(@() ElevationRange.value != 0 ? 1.0 / ElevationRange.value : 1.0)
local getBlinkOpacity = @() round(radarState.currentTime * 3) % 2 == 0 ? 1.0 : 0.2

radarState.__update({
    IsRadarHudVisible, IsNoiseSignaVisible, MfdRadarEnabled, MfdIlsEnabled, MfdRadarColor,

    Speed,

    //radar 1
    IsRadarVisible, RadarModeNameId, Azimuth, Elevation, Distance, AzimuthHalfWidth, ElevationHalfWidth, DistanceGateWidthRel, NoiseSignal,

    //radar 2
    IsRadar2Visible, Radar2ModeNameId, Azimuth2, Elevation2, Distance2, AzimuthHalfWidth2, ElevationHalfWidth2, NoiseSignal2,

    AimAzimuth, TurretAzimuth, TargetRadarAzimuthWidth, TargetRadarDist, AzimuthMin, AzimuthMax, ElevationMin, ElevationMax,

    IsCScopeVisible, ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax,

    targets, TargetsTrigger, screenTargets, ScreenTargetsTrigger, ViewMode, MfdViewMode, HasAzimuthScale, HasDistanceScale, ScanPatternsMax,
    DistanceMax, DistanceScalesMax, azimuthMarkers, AzimuthMarkersTrigger, Irst, RadarScale, MfdIlsHeight,

    IsForestallVisible, forestall, selectedTarget,

    UseLockZoneRotated, FoV, ScanZoneWatched, LockZoneWatched, IsScanZoneAzimuthVisible, IsScanZoneElevationVisible, IsLockZoneVisible,
    LockDistMin, LockDistMax, radarPosSize,

    IsAamLaunchZoneVisible, AamLaunchZoneDist, AamLaunchZoneDistMin, AamLaunchZoneDistMax,

    IndicationForCollapsedRadar
  }
)

::interop.updateCurrentTime <- function(curr_time) {
  radarState.currentTime = curr_time
}


::interop.updateBlinking <- function(isTargetBlink, isSpeedBlink) {
  radarState.selectedTargetBlinking = isTargetBlink
  radarState.selectedTargetSpeedBlinking = isSpeedBlink
}


::interop.clearTargets <- function() {
  local needUpdate = false
  for(local i = 0; i < targets.len(); ++i) {
    if (targets[i] != null) {
      targets[i] = null
      needUpdate = true
    }
  }

  if (needUpdate)
    TargetsTrigger.trigger()
}


::interop.updateTarget <- function (index, azimuth_rel, azimuth_width_rel, elevation_rel, elevation_width_rel, distance_rel, distance_width_rel, age_rel, is_selected, is_detected, is_enemy, signal_rel) {
  if (index >= targets.len())
    targets.resize(index + 1)

  local cvt = @(val, vmin, vmax, omin, omax) omin + ((omax - omin) * (val - vmin)) / (vmax - vmin)

  local signalRel = signal_rel < 0.05
    ? 0.0
    : cvt(signal_rel, 0.05, 1.0, 0.3, 1.0)

  targets[index] = {
    azimuthRel = azimuth_rel
    azimuthWidthRel = max(azimuth_width_rel, 0.02)
    elevationRel = elevation_rel
    elevationWidthRel = max(elevation_width_rel, 0.02)
    distanceRel = distance_rel
    distanceWidthRel = max(distance_width_rel, 0.05)
    ageRel = age_rel
    isSelected = is_selected
    isDetected = is_detected
    isEnemy = is_enemy
    signalRel = signalRel
  }

  TargetsTrigger.trigger()
}

local ilsHdpx = @(px) MfdIlsEnabled.value ? (px * MfdIlsHeight.value / 1024) : hdpx(px)
local radarHdpx = @(px) MfdRadarEnabled.value ? (px * radarPosSize.value.h / 1024) : hdpx(px)
local radarSh = @(h) MfdIlsEnabled.value ? (h * MfdIlsHeight.value / 100) : sh(h)
local radarSw = @(w) MfdIlsEnabled.value ? (w * MfdIlsHeight.value / 100) : sw(w)

const targetLifeTime = 5.0

::interop.updateScreenTarget <- function(id, x, y, dist, speed) {
  if (!screenTargets)
    screenTargets = {}

  radarState.targetAspectEnabled = false
  if (!screenTargets?[id]) {
    screenTargets[id] <- {
      x = x
      y = y
      azimuthRate = 0.0
      elevationRate = 0.0
      dist = dist
      speed = speed
      isUpdated = true
    }
  }
  else {
    screenTargets[id].x = x
    screenTargets[id].y = y
    screenTargets[id].azimuthRate = 0.0
    screenTargets[id].elevationRate = 0.0
    screenTargets[id].dist = dist
    screenTargets[id].speed = speed
    screenTargets[id].isUpdated = true
  }

  ScreenTargetsTrigger.trigger()
}

::interop.updateScreenTarget2 <- function(id, x, y, azimuth_rate, elevation_rate, dist, speed) {
  if (!screenTargets)
    screenTargets = {}

  radarState.targetAspectEnabled = true
  if (!screenTargets?[id]) {
    screenTargets[id] <- {
      x = x
      y = y
      azimuthRate = azimuth_rate
      elevationRate = elevation_rate
      dist = dist
      speed = speed
      isUpdated = true
    }
  }
  else {
    screenTargets[id].x = x
    screenTargets[id].y = y
    screenTargets[id].azimuthRate = azimuth_rate
    screenTargets[id].elevationRate = elevation_rate
    screenTargets[id].dist = dist
    screenTargets[id].speed = speed
    screenTargets[id].isUpdated = true
  }

  ScreenTargetsTrigger.trigger()
}

::interop.updateAzimuthMarker <- function(id, target_time, age, azimuth_world_deg, is_selected, is_detected, is_enemy) {
  if (!azimuthMarkers)
    azimuthMarkers = {}

  if (!azimuthMarkers?[id]) {
    azimuthMarkers[id] <- {
      azimuthWorldDeg = azimuth_world_deg
      targetTime = target_time
      age = age
      isSelected = is_selected
      isDetected = is_detected
      isEnemy = is_enemy
      isUpdated = true
    }
  }
  else if (target_time > azimuthMarkers[id].targetTime) {
    azimuthMarkers[id].azimuthWorldDeg = azimuth_world_deg
    azimuthMarkers[id].isSelected = is_selected
    azimuthMarkers[id].targetTime = target_time
    azimuthMarkers[id].age = age
    azimuthMarkers[id].isDetected = is_detected
    azimuthMarkers[id].isEnemy = is_enemy
    azimuthMarkers[id].isUpdated = true
  }
  else
    return

  AzimuthMarkersTrigger.trigger()
}


::interop.resetTargetsFlags <- function() {
  foreach(id, target in screenTargets)
    if (target)
      target.isUpdated = false

  foreach(id, marker in azimuthMarkers)
    if (marker)
      marker.isUpdated = false
}


::interop.clearUnusedTargets <- function() {
  local needUpdate = false
  foreach(id, target in screenTargets)
    if (target && !target.isUpdated) {
      screenTargets[id] = null
      needUpdate = true
    }
  if (needUpdate)
    ScreenTargetsTrigger.trigger()

  needUpdate = false
  foreach(id, marker in azimuthMarkers)
    if (marker && !marker.isUpdated && radarState.currentTime > marker.targetTime + targetLifeTime) {
      azimuthMarkers[id] = null
      needUpdate = true
    }
  if(needUpdate)
    AzimuthMarkersTrigger.trigger()
}


::interop.updateForestall <- function(x, y) {
  forestall.x = x
  forestall.y = y
}


::interop.updateSelectedTarget <- function(x, y) {
  selectedTarget.x = x
  selectedTarget.y = y
}

::interop.updateScanZone <- function(x0, y0, x1, y1, x2, y2, x3, y3) {
  ScanZoneWatched({x0, y0, x1, y1, x2, y2, x3, y3})
}

::interop.updateLockZone <- function(x0, y0, x1, y1, x2, y2, x3, y3) {
  LockZoneWatched({x0, x1, x2, x3, y0, y1, y2, y3})
}

::interop.updateLockZoneRotated <- function(x0, y0, x1, y1, x2, y2, x3, y3) {}

::interop.updateRadarPosSize <- function(x, y, w, h) {
  radarPosSize({x, y, w, h})
}

interopGen({
  stateTable = radarState
  prefix = "radar"
  postfix = "Update"
})

local targetsComponent = function(radarWidth, radarHeight, createTargetFunc, is_mfd) {
  local getTargets = function() {
    local targetsRes = []
    for(local i = 0; i < targets.len(); ++i) {
      if (!targets[i])
        continue
      targetsRes.append(createTargetFunc(i, hdpx(5) * 0, radarWidth, radarHeight, is_mfd))
    }
    return targetsRes
  }

  return @() {
    size = [radarWidth, radarHeight]
    children = getTargets()
    watch = TargetsTrigger
  }
}

local function B_ScopeSquareBackground(width, height, is_mfd) {
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
    size = [width, height]
    color = areaBackgroundColor
  }

  local frame = styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    gridSecondaryCommands = [
      [VECTOR_LINE, 0, 0, 0, 100],
      [VECTOR_LINE, 0, 100, 100, 100],
      [VECTOR_LINE, 100, 100, 100, 0],
      [VECTOR_LINE, 100, 0, 0, 0]
    ]
  })

  local function gridMain(){
    local scanAzimuthMinRel = scanAzimuthMinRelW.value
    local scanAzimuthMaxRel = scanAzimuthMaxRelW.value
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      watch = scanAzimuthMaxRelW
      color = is_mfd ? MfdRadarColor.value : greenColorGrid
      lineWidth = max(LINE_WIDTH, hdpx(LINE_WIDTH))
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
  local gridSecondary = @(){
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = defLineWidth
    color = is_mfd ? MfdRadarColor.value : greenColorGrid
    fillColor = Color(0, 0, 0, 0)
    size = [width, height]
    opacity = 0.42
    watch = gridSecondaryCommandsW
    commands = gridSecondaryCommandsW.value
  }
  return styleLineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = [ back, frame, gridMain, gridSecondary ]
  })
}

local function B_ScopeSquareTargetSectorComponent(width, valueWatched, distWatched, halfWidthWatched, height, fillColor = greenColorGrid, is_mfd = false) {
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
      color = is_mfd ? MfdRadarColor.value : greenColor
      fillColor = is_mfd ? MfdRadarColor.value : fillColor
      opacity = 0.42
      size = [width, height]
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
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = defLineWidth
      color = is_mfd ? MfdRadarColor.value : greenColor
      fillColor = is_mfd ? MfdRadarColor.value : fillColor
      watch = [AzimuthRange, halfWidthWatched, distWatched]
      opacity = 0.42
      size = [width, height]
      commands = com
    }
  }

  local showRadar = !distWatched || !halfWidthWatched ? Watched(false) : Computed(@() halfWidthWatched.value > 0)
  local isTank = Computed(@() AzimuthRange.value > PI)

  return @() styleLineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = !showRadar.value ? null :
      isTank.value ? tankRadar : aircraftRadar

    watch = [valueWatched, isTank, showRadar]
    transform = {
      translate = [valueWatched.value * width, 0]
    }
  })
}

local B_ScopeSquareAzimuthComponent = function(width, height, valueWatched, distWatched, halfWidthWatched, tanksOnly, is_mfd) {
  local function part1(){
    local azimuthRange = AzimuthRange.value
    local halfAzimuthWidth = 100.0 * (azimuthRange > 0 ? halfWidthWatched.value / azimuthRange : 0)

    return {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = defLineWidth
      color = greenColor
      watch = [AzimuthRange, halfWidthWatched]
      fillColor = is_mfd ? MfdRadarColor.value : greenColorGrid
      opacity = 0.6
      size = [width, height]
      commands = [
        [VECTOR_POLY, -halfAzimuthWidth, 0, halfAzimuthWidth, 0, halfAzimuthWidth, 100, -halfAzimuthWidth, 100]
      ]
    }
  }
  local commandsW = distWatched
    ? Computed(@() [[VECTOR_LINE_DASHED, 0, 100.0 * (1.0 - distWatched.value), 0, 100.0, hdpx(10), hdpx(5)]])
    : Watched([[VECTOR_LINE, 0, 0, 0, 100.0]])

  local function part2(){
    return styleLineForeground.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      watch = commandsW
      commands = commandsW.value
    })
  }

  local showPart1 = (!distWatched || !halfWidthWatched) ? null : Computed(@()distWatched.value == 1.0 && halfWidthWatched.value > 0)
  local isTank = Computed(@() AzimuthRange.value > PI)
  local show = Computed(@() !tanksOnly || isTank.value)
  local translate = Computed(@() show.value ? [valueWatched.value * width, 0] : null)
  return @() styleLineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = !show.value ? null : showPart1?.value ? part1 : part2
    watch = [show, translate, showPart1]
    transform = {
      translate = translate.value
    }
  })
}

local function B_ScopeSquareLaunchRangeComponent(width, height, aamLaunchZoneDist, aamLaunchZoneDistMin, aamLaunchZoneDistMax) {

  return function() {
    local commands = [
      [VECTOR_LINE, 80, (1.0 - aamLaunchZoneDist.value) * 100,    100, (1.0 - aamLaunchZoneDist.value)    * 100],
      [VECTOR_LINE, 90, (1.0 - aamLaunchZoneDistMin.value) * 100, 100, (1.0 - aamLaunchZoneDistMin.value) * 100],
      [VECTOR_LINE, 90, (1.0 - aamLaunchZoneDistMax.value) * 100, 100, (1.0 - aamLaunchZoneDistMax.value) * 100]
    ]

    local children = {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(4)
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      size = [width, height]
      opacity = 0.42
      commands = commands
    }

    return styleLineForeground.__merge({
      size = SIZE_TO_CONTENT
      children = children
      watch = [ aamLaunchZoneDist, aamLaunchZoneDistMin, aamLaunchZoneDistMax]
    })
  }
}

local distanceGateWidthRelMin = 0.05
local angularGateWidthMultSquare = 4.0

local distanceGateWidthMult = 2.0
local iffDistRelMult = 0.5

local function createTargetOnRadarSquare(index, radius, radarWidth, radarHeight, is_mfd) {
  local target = targets[index]
  local opacity = (1.0 - target.ageRel) * target.signalRel

  local angleRel = HasAzimuthScale.value ? target.azimuthRel : 0.5
  local angularWidthRel = HasAzimuthScale.value ? target.azimuthWidthRel : 1.0
  local angleLeft = angleRel - 0.5 * angularWidthRel
  local angleRight = angleRel + 0.5 * angularWidthRel

  local distanceRel = HasDistanceScale.value ? target.distanceRel : 0.9
  local radialWidthRel = target.distanceWidthRel

  local selectionFrame = null

  if (target.isSelected || target.isDetected || !target.isEnemy) {
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
    ? @() styleLineForeground.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = [radarWidth, radarHeight]
        lineWidth = hdpx(3)
        color = is_mfd ? MfdRadarColor.value : greenColorGrid
        fillColor = Color(0, 0, 0, 0)
        pos = [radius, radius]
        commands = frameCommands
        behavior = Behaviors.RtPropUpdate
        update = function() {
          return {
            opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : opacity
          }
        }
      })
    : styleLineForeground.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [radarWidth, radarHeight]
      lineWidth = hdpx(3)
      color = is_mfd ? MfdRadarColor.value : greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      pos = [radius, radius]
      commands = frameCommands
    })
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [radarWidth, radarHeight]
    lineWidth = 100 * radialWidthRel
    color = is_mfd ? MfdRadarColor.value : greenColorGrid
    fillColor = Color(0, 0, 0, 0)
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
  }
}


local function arrowIcon(size) {
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    color = greenColor
    fillColor = greenColor
    lineWidth = defLineWidth
    size = size
    commands = [
      [VECTOR_POLY, 50, 0,  0, 50,  35, 50,  35, 100,
      65, 100,  65, 50,  100, 50]
    ]
  }
}


local function groundNoiseIcon(size) {
  return {
    size = size
    children = [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        color = greenColor
        fillColor = greenColor
        size = size
        commands = [
          [VECTOR_RECTANGLE, 0, 75, 100, 32]
        ]
      },
      {
        pos = [size[0] * 0.15, 0]
        children = arrowIcon([size[0] * 0.25, size[1] * 0.75])
        transform = {
          pivot = [0.5, 0.5]
          rotate = 180.0
        }
      },
      {
        pos = [size[0] * (1.0 - 0.35), 0]
        children = arrowIcon([size[0] * 0.25, size[1] * 0.75])
      },
    ]
  }
}


local function noiseSignalComponent(signalWatched, size, isIconOnLeftSide) {
  local function indicator() {
    local children = []
    for (local i = 0; i < 4; ++i) {
      children.append({
        rendObj = ROBJ_SOLID
        size = [size[0], size[1] * 0.18]
        color = greenColor
        opacity = signalWatched.value > (3 - i) ? 1.0 : 0.21
      })
    }
    return {
      watch = signalWatched
      size
      flow = FLOW_VERTICAL
      gap = size[1] * (1.0 - 0.18 * 4) / 3.0
      children
    }
  }

  local icon = groundNoiseIcon([size[1], size[1]])

  local children = isIconOnLeftSide
    ? [icon, indicator]
    : [indicator, icon]

  return {
    flow = FLOW_HORIZONTAL
    gap = size[1] * 0.2
    children = children
  }
}


local function noiseSignal(size, pos1, pos2) {
  local showSignal = Computed(@() IsNoiseSignaVisible.value && !MfdRadarEnabled.value)
  local showSignal1 = Computed(@() showSignal.value && IsRadarVisible.value && NoiseSignal.value > 0.5)
  local showSignal2 = Computed(@() showSignal.value && IsRadar2Visible.value && NoiseSignal2.value > 0.5)
  local noize1 = noiseSignalComponent(NoiseSignal, size, true)
  local noize2 = noiseSignalComponent(NoiseSignal2, size, true)
  local signal1 = @() {watch = showSignal1, size, pos=pos1, children =  showSignal1.value ? noize1 : null}
  local signal2 = @() {watch = showSignal2, size, pos=pos2, children =  showSignal2.value ? noize2 : null}

  return {
    size = SIZE_TO_CONTENT
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
local function makeRadarModeText(textConfig, isCollapsed = false) {
  if (isCollapsed)
    return null

  return @() styleText.__merge({
    rendObj = ROBJ_DTEXT
    size = SIZE_TO_CONTENT
    watch = [RadarModeNameId, IsRadarVisible, Irst]
    text = getRadarModeText(RadarModeNameId, IsRadarVisible)
  }).__merge(textConfig)
}

local function makeRadar2ModeText(textConfig, isCollapsed = false) {
  if (isCollapsed)
    return null

  return @() styleText.__merge({
    rendObj = ROBJ_DTEXT
    size = SIZE_TO_CONTENT
    watch = [Radar2ModeNameId, IsRadar2Visible, Irst]
    text = getRadarModeText(Radar2ModeNameId, IsRadar2Visible)
  }).__merge(textConfig)
}

local B_ScopeSquareMarkers = function(radarWidth, radarHeight, is_mfd) {
  local isCollapsed = (!is_mfd && !IsRadarVisible.value && !IsRadar2Visible.value)
  local hiddenText = (isCollapsed && !IndicationForCollapsedRadar.value)
  if (!hiddenText){
    local offsetScaleFactor = 1.3
    local fontSize = (!is_mfd && (IsRadarVisible.value || IsRadar2Visible.value)) ? getFontSize(is_mfd) : hdpx(13)
    return {
      size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarHeight]
      children = [
        {
          size = [0, SIZE_TO_CONTENT]
          children = @() styleText.__merge({
            rendObj = ROBJ_DTEXT
            size = SIZE_TO_CONTENT
            pos = is_mfd ? [ radarWidth * 0.2, -radarHdpx(40)] : [radarWidth * 0.30, - hdpx(20)]
            hplace = ALIGN_RIGHT
            watch = [ HasAzimuthScale, ScanAzimuthMin, ScanAzimuthMax,
                      ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
            text = HasAzimuthScale.value && ScanAzimuthMax.value > ScanAzimuthMin.value
              ? ::str( floor((ScanAzimuthMax.value - ScanAzimuthMin.value) * radToDeg + 0.5), ::loc("measureUnits/deg"), "x",
                floor((ScanElevationMax.value - ScanElevationMin.value) * radToDeg + 0.5), ::loc("measureUnits/deg"),
                (ScanPatternsMax.value > 1 ? "*" : " "))
              : ""
            fontSize = fontSize
            color = is_mfd ? MfdRadarColor.value : greenColor
          })
        }
        @() styleText.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = is_mfd ? [ radarWidth * 0.8, -radarHdpx(40)] : [radarWidth * 0.65, -hdpx(20)]
          watch = [ HasDistanceScale, DistanceMax, DistanceScalesMax ]
          text = HasDistanceScale.value
            ? ::str(::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMax.value * 1000.0, true, false, false),
                (DistanceScalesMax.value > 1 ? "*" : " ")
              )
            : ""
          fontSize = fontSize
          color = is_mfd ? MfdRadarColor.value : greenColor
        })
        styleText.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = is_mfd ? [ radarWidth * 0.8, radarHeight + radarHdpx(8)] :
            [radarWidth * 0.75, radarHeight + hdpx(6)]
          text = !isCollapsed ? ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(0.0, true, false, false) : null
          fontSize = fontSize
          color = is_mfd ? MfdRadarColor.value : greenColor
        })
        @() styleText.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = [hdpx(4), hdpx(4)]
          watch = AzimuthMin
          text = !isCollapsed ? ::str(floor(AzimuthMin.value * radToDeg + 0.5), ::loc("measureUnits/deg")) : null
          fontSize = fontSize
          color = is_mfd ? MfdRadarColor.value : greenColor
        })
        {
          size = [radarWidth, SIZE_TO_CONTENT]
          children = @() styleText.__merge({
            rendObj = ROBJ_DTEXT
            pos = [-hdpx(4), hdpx(4)]
            hplace = ALIGN_RIGHT
            watch = AzimuthMax
            text = !isCollapsed ? ::str(floor(AzimuthMax.value * radToDeg + 0.5), ::loc("measureUnits/deg")) : null
            fontSize = fontSize
            color = is_mfd ? MfdRadarColor.value : greenColor
          })
        }
        makeRadarModeText({
          pos = [radarWidth * 0.5, -hdpx(25)]
          fontSize = fontSize
          color = is_mfd ? MfdRadarColor.value : greenColor
        }, isCollapsed)
        makeRadar2ModeText({
          pos = [radarWidth * 0.5, -hdpx(55)]
          fontSize = fontSize
          color = is_mfd ? MfdRadarColor.value : greenColor
        }, isCollapsed)
        noiseSignal(
          [radarWidth * 0.06, radarWidth * 0.06],
          [radarWidth * 0.35, -hdpx(25)],
          [radarWidth * 0.35, -hdpx(55)])
      ]
    }
  }
  return null
}

local function B_ScopeSquare(width, height, is_mfd) {
  local bkg = B_ScopeSquareBackground(width, height, is_mfd)
  local scopeTgtSectorComp = B_ScopeSquareTargetSectorComponent(width, TurretAzimuth, TargetRadarDist, TargetRadarAzimuthWidth, height, targetSectorColor, is_mfd)
  local scopeSquareAzimuthComp1 = B_ScopeSquareAzimuthComponent(width, height, TurretAzimuth, null, null, true, is_mfd)
  local groundReflComp = {
    size = [width, height]
    rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
    isSquare = true
    xFragments = 30
    yFragments = 10
    color = is_mfd ? MfdRadarColor.value : greenColor
  }
  local scopeSquareAzimuthComp2 = B_ScopeSquareAzimuthComponent(width, height, Azimuth, Distance, AzimuthHalfWidth, false, is_mfd)
  local scopeSquareAzimuthComp3 = B_ScopeSquareAzimuthComponent(width, height, Azimuth2, Distance2, AzimuthHalfWidth2, false, is_mfd)
  local scopeSqLaunchRangeComp = B_ScopeSquareLaunchRangeComponent(width, height, AamLaunchZoneDist,
                                                        AamLaunchZoneDistMin, AamLaunchZoneDistMax)
  local tgts = targetsComponent(width, height, createTargetOnRadarSquare, is_mfd)
  local markers = B_ScopeSquareMarkers(width, height, is_mfd)

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

local function B_ScopeBackground(width, height) {

  local circle = {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    color = greenColorGrid
    fillColor = areaBackgroundColor
    lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)
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
      rendObj = ROBJ_VECTOR_CANVAS
      watch = HasDistanceScale
      lineWidth = defLineWidth
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      size = [width, height]
      opacity = 0.42
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

local function B_ScopeAzimuthComponent(width, valueWatched, distWatched, halfWidthWatched, height, lineWidth = LINE_WIDTH) {
  local showPart1 = (!distWatched || !halfWidthWatched) ? Watched(false) : Computed(@() distWatched.value == 1.0 && (halfWidthWatched.value ?? 0) > 0) //wtf this condition mean?

  local function part1(){
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
      watch = [valueWatched, AzimuthMin, halfWidthWatched, AzimuthMax]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = defLineWidth
      color = greenColor
      fillColor = greenColorGrid
      opacity = 0.6
      size = [width, height]
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
      lineWidth = max(hdpx(lineWidth), lineWidth)
      color = greenColor
      size = [width, height]
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

local function B_ScopeHalfLaunchRangeComponent(width, height, azimuthMin, azimuthMax, aamLaunchZoneDistMin, aamLaunchZoneDistMax) {
  return function(){
    local scanAngleStart = azimuthMin.value - PI * 0.5
    local scanAngleFinish = azimuthMax.value - PI * 0.5
    local scanAngleStartDeg = scanAngleStart * rad2deg
    local scanAngleFinishDeg = scanAngleFinish * rad2deg

    local commands = [
      [VECTOR_SECTOR, 50, 50, aamLaunchZoneDistMin.value * 50, aamLaunchZoneDistMin.value * 50, scanAngleStartDeg, scanAngleFinishDeg],
      [VECTOR_SECTOR, 50, 50, aamLaunchZoneDistMax.value * 50, aamLaunchZoneDistMax.value * 50, scanAngleStartDeg, scanAngleFinishDeg]
    ]

    local children =  {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(4)
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      size = [width, height]
      opacity = 0.42
      commands = commands
    }

    return styleLineForeground.__merge({
      size = SIZE_TO_CONTENT
      children
      watch = [azimuthMin, azimuthMax, aamLaunchZoneDistMin, aamLaunchZoneDistMax ]
    })
  }
}


local function B_ScopeSectorComponent(width, valueWatched, distWatched, halfWidthWatched, height, fillColorP = greenColorGrid) {
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
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = defLineWidth
      color = greenColor
      watch = [valueWatched, distWatched, halfWidthWatched, AzimuthMin]
      fillColor = fillColorP
      opacity = 0.42
      size = [width, height]
      commands = [sectorCommands]
    }
  }

  return @() {
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

local function createTargetOnRadarPolar(index, radius, radarWidth, radarHeight, is_mfd) {

  local target = targets[index]

  local angle = HasAzimuthScale.value ? AzimuthMin.value + AzimuthRange.value * target.azimuthRel - PI * 0.5 : -PI * 0.5
  local angularWidth = AzimuthRange.value * target.azimuthWidthRel
  local angleLeftDeg = (angle - 0.5 * angularWidth) * 180.0 / PI
  local angleRightDeg = (angle + 0.5 * angularWidth) * 180.0 / PI

  local distanceRel = HasDistanceScale.value ? target.distanceRel : 0.9
  local radialWidthRel = HasAzimuthScale.value ? target.distanceWidthRel : 1.0

  local selectionFrame = null

  if (target.isSelected || target.isDetected || !target.isEnemy) {
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
    ? @() styleLineForeground.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = [radarWidth, radarHeight]
        lineWidth = hdpx(3)
        color = is_mfd ? MfdRadarColor.value : greenColorGrid
        fillColor = Color(0, 0, 0, 0)
        pos = [radius, radius]
        commands = frameCommands
        behavior = Behaviors.RtPropUpdate
        update = function() {
          return {
            opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : 1.0
          }
        }
      })
    : styleLineForeground.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [radarWidth, radarHeight]
      lineWidth = hdpx(3)
      color = is_mfd ? MfdRadarColor.value : greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      pos = [radius, radius]
      commands = frameCommands
    })
  }

  return {
   rendObj = ROBJ_VECTOR_CANVAS
    size = [radarWidth, radarHeight]
    lineWidth = 100 * radialWidthRel
    color = is_mfd ? MfdRadarColor.value : greenColorGrid
    fillColor = Color(0, 0, 0, 0)
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
  }
}

local B_ScopeCircleMarkers = function(radarWidth, radarHeight) {
  local hiddenText = (!IsRadarVisible.value && !IsRadar2Visible.value && !IndicationForCollapsedRadar.value)
  if (!hiddenText){
    local offsetScaleFactor = 1.3
    local isCollapsed = IsRadarVisible.value || IsRadar2Visible.value
    return {
      size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarHeight]
      children = [
        {
          size = [0, SIZE_TO_CONTENT]
          children = @() styleText.__merge({
            rendObj = ROBJ_DTEXT
            size = SIZE_TO_CONTENT
            pos = [0 - hdpx(4), radarHeight * 0.5 + hdpx(5)]
            hplace = ALIGN_RIGHT
            watch = [ HasAzimuthScale, ScanAzimuthMin, ScanAzimuthMax,
                      ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
            text = HasAzimuthScale.value && ScanAzimuthMax.value > ScanAzimuthMin.value
              ? ::str(floor((ScanAzimuthMax.value - ScanAzimuthMin.value) * radToDeg + 0.5), ::loc("measureUnits/deg"), "x",
                        floor((ScanElevationMax.value - ScanElevationMin.value) * radToDeg + 0.5), ::loc("measureUnits/deg"),
                       (ScanPatternsMax.value > 1 ? "*" : " ")
                     )
              : ""
          })
        },
        @() styleText.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = [radarWidth + hdpx(4), radarHeight * 0.5 + hdpx(5)]
          watch = [ HasDistanceScale, DistanceMax, DistanceScalesMax ]
          text = HasDistanceScale.value ?
            ::str(::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMax.value * 1000.0, true, false, false),
            (DistanceScalesMax.value > 1 ? "*" : " ")) : ""
        }),
        styleText.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = [radarWidth * 0.5 - hdpx(4), -hdpx(18)]
          text = !isCollapsed ? ::str("0", ::loc("measureUnits/deg")) : ""
        }),
        styleText.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = [radarWidth + hdpx(4), radarHeight * 0.5 - hdpx(15)]
          text = ::str("90", ::loc("measureUnits/deg"))
        }),
        styleText.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = [radarWidth * 0.5 - hdpx(18), radarHeight + hdpx(4)]
          text = ::str("180", ::loc("measureUnits/deg"))
        }),
        styleText.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = [-hdpx(52), radarHeight * 0.5 - hdpx(15)]
          text = ::str("270", ::loc("measureUnits/deg"))
        }),
        makeRadarModeText({
          pos = [radarWidth * (0.5 - 0.15), -hdpx(20)]
        }, isCollapsed),
        makeRadar2ModeText({
          pos = [radarWidth * (0.5 + 0.05), -hdpx(20)]
        }, isCollapsed),
        noiseSignal(
          [radarWidth * 0.06, radarWidth * 0.06],
          [radarWidth * (0.5 - 0.30), -hdpx(25)],
          [radarWidth * (0.5 + 0.20), -hdpx(25)])
      ]
    }
  }
  return null
}

local function B_Scope(width, height) {
  local bkg = B_ScopeBackground(width, height)
  local azComp1 = B_ScopeAzimuthComponent(width, AimAzimuth, null, null, height, AIM_LINE_WIDTH)
  local azComp2 = B_ScopeAzimuthComponent(width, TurretAzimuth, null, null, height, TURRET_LINE_WIDTH)
  local sectorComp = B_ScopeSectorComponent(width, TurretAzimuth, TargetRadarDist, TargetRadarAzimuthWidth, height, targetSectorColor)
  local azComp3 = B_ScopeAzimuthComponent(width, Azimuth, Distance, AzimuthHalfWidth, height)
  local azComp4 = B_ScopeAzimuthComponent(width, Azimuth2, Distance2, AzimuthHalfWidth2, height)
  local tgts = targetsComponent(width, height, createTargetOnRadarPolar, false)
  local size = [width + hdpx(2), height + hdpx(2)]
  local markers = B_ScopeCircleMarkers(width, height)

  return function() {
    local children = [ bkg, azComp1, azComp2, sectorComp ]
    if (IsRadarVisible.value)
      children.append(azComp3)
    if (IsRadar2Visible.value)
      children.append(azComp4)
    children.append(tgts)
    return {
      watch = [ MfdRadarEnabled, IsRadarVisible, RadarModeNameId,
              IsRadar2Visible, Radar2ModeNameId, HasDistanceScale]
       children = [
          {
            size
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

local function B_ScopeHalfBackground(width, height, is_mfd) {
  local size = [width, height]
  local angleLimStartS = Computed(@() AzimuthMin.value - PI * 0.5)
  local angleLimFinishS = Computed(@() AzimuthMax.value - PI * 0.5)

  local function circle(){
    local angleLimStart = angleLimStartS.value
    local angleLimFinish = angleLimFinishS.value
    local angleLimStartDeg = angleLimStart * rad2deg
    local angleLimFinishDeg = angleLimFinish * rad2deg
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      size = size
      watch = [angleLimFinishS, angleLimStartS]
      color = is_mfd ? MfdRadarColor.value : greenColorGrid
      fillColor = areaBackgroundColor
      lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)
      opacity = 0.7
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

    local res = HasDistanceScale.value ? [
        [VECTOR_SECTOR, 50, 50, 12.5, 12.5, scanAngleStartDeg, scanAngleFinishDeg],
        [VECTOR_SECTOR, 50, 50, 25.0, 25.0, scanAngleStartDeg, scanAngleFinishDeg],
        [VECTOR_SECTOR, 50, 50, 37.5, 37.5, scanAngleStartDeg, scanAngleFinishDeg],
      ] : defSecGrid

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
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = defLineWidth
    color = is_mfd ? MfdRadarColor.value : greenColorGrid
    fillColor = Color(0, 0, 0, 0)
    size = size
    opacity = 0.42
    commands = gridSecondaryCom.value
    watch = gridSecondaryCom
  }

  local function gridMain(){
    local scanAngleStart = scanAngleStartS.value
    local scanAngleFinish = scanAngleFinishS.value

    return {
      watch = [scanAngleStartS, scanAngleFinishS]
      rendObj = ROBJ_VECTOR_CANVAS
      size = size
      color = is_mfd ? MfdRadarColor.value : greenColorGrid
      lineWidth = max(2*LINE_WIDTH, hdpx(2 * LINE_WIDTH))
      opacity = 0.7
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

local B_ScopeHalfCircleMarkers = function(radarWidth, radarHeight, is_mfd) {
  local offsetScaleFactor = 1.3
  local hiddenText = (!is_mfd && !IsRadarVisible.value && !IsRadar2Visible.value && !IndicationForCollapsedRadar.value)
  if (!hiddenText){
    local scanRangeX = (!is_mfd && (IsRadarVisible.value || IsRadar2Visible.value)) ? radarWidth * 0.47 : radarWidth * 0.5 * (1.0 - sin(AzimuthMax.value)) + hdpx(4)
    local scanRangeY = (!is_mfd && (IsRadarVisible.value || IsRadar2Visible.value)) ? radarHeight * 0.51 : radarHeight * 0.5 * (1.0 - cos(AzimuthMax.value)) - hdpx(4)
    local scanYaw = (!is_mfd && (IsRadarVisible.value || IsRadar2Visible.value)) ? radarWidth * 0.58 : radarWidth * 0.5 * (1.0 + sin(AzimuthMax.value)) + hdpx(4)
    local scanPitch = (!is_mfd && (IsRadarVisible.value || IsRadar2Visible.value)) ? radarWidth * 0.51 : radarWidth * 0.5 * (1.0 - cos(AzimuthMax.value)) - hdpx(4)
    local fontSize = (!is_mfd && (IsRadarVisible.value || IsRadar2Visible.value)) ? styleText.fontSize : hdpx(13)
    return {
      size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarHeight]
      children = [
        {
          size = [0, SIZE_TO_CONTENT]
          children = @() styleText.__merge({
            rendObj = ROBJ_DTEXT
            size = SIZE_TO_CONTENT
            pos = is_mfd ? [ radarWidth * 0.4, radarHeight * 0.2] :
            [
              scanRangeX,
              scanRangeY
            ]
            key = $"1{is_mfd}"
            hplace = ALIGN_RIGHT
            watch = [ HasAzimuthScale, ScanAzimuthMin, ScanAzimuthMax,
                      ScanElevationMin, ScanElevationMax, ScanPatternsMax ]
            text = HasAzimuthScale.value && ScanAzimuthMax.value > ScanAzimuthMin.value
              ? ::str( floor((ScanAzimuthMax.value - ScanAzimuthMin.value) * radToDeg + 0.5), ::loc("measureUnits/deg"), "x",
                    floor((ScanElevationMax.value - ScanElevationMin.value) * radToDeg + 0.5), ::loc("measureUnits/deg"),
                    (ScanPatternsMax.value > 1 ? "*" : " ")
                )
              : ""
            fontSize = fontSize
          })
        }
        @() styleText.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          key = $"2{is_mfd}"
          pos = is_mfd ? [ radarWidth * 0.55, radarHeight * 0.2] :
          [
            scanYaw,
            scanPitch
          ]
          watch = [ HasDistanceScale, DistanceMax, DistanceScalesMax ]
          text = HasDistanceScale.value ?
            ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(DistanceMax.value * 1000.0, true, false, false) +
            (DistanceScalesMax.value > 1 ? "*" : " ") : ""
            fontSize = fontSize
        })
        makeRadarModeText({
          pos = [radarWidth * (0.5 - 0.15), is_mfd ? radarHeight * 0.1 : -hdpx(20)]
          fontSize = getFontSize(is_mfd)
          key = $"3{is_mfd}"
        })
        makeRadar2ModeText({
          pos = [radarWidth * (0.5 + 0.05), is_mfd ? radarHeight * 0.1 : -hdpx(20)]
          fontSize = getFontSize(is_mfd)
          key = $"4{is_mfd}"
        })
        noiseSignal(
          [radarWidth * 0.06, radarHeight * 0.06],
          [radarWidth * (0.5 - 0.30), -hdpx(25)],
          [radarWidth * (0.5 + 0.20), -hdpx(25)])
      ]
    }
  }
  return null
}

local function B_ScopeHalf(width, height, pos, is_mfd) {
  local bkg = B_ScopeHalfBackground(width, height, is_mfd)
  local sector = B_ScopeSectorComponent(width, null, TargetRadarDist, TargetRadarAzimuthWidth, height, targetSectorColor)
  local reflections = {
    size = [width, height]
    rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
    isSquare = false
    xFragments = 20
    yFragments = 8
    color = is_mfd ? MfdRadarColor.value : greenColor
  }

  local size = [width + hdpx(2), 0.5 * height]
  local markers = B_ScopeHalfCircleMarkers(width, height, is_mfd)
  local az1 = B_ScopeAzimuthComponent(width, Azimuth, Distance, AzimuthHalfWidth, height)
  local az2 = B_ScopeAzimuthComponent(width, Azimuth2, Distance2, AzimuthHalfWidth2, height)
  local aamLaunch = B_ScopeHalfLaunchRangeComponent(width, height, AzimuthMin, AzimuthMax,
                                                      AamLaunchZoneDistMin, AamLaunchZoneDistMax)
  local tgts = targetsComponent(width, height, createTargetOnRadarPolar, is_mfd)
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
      watch = [ MfdRadarEnabled, IsRadarVisible, RadarModeNameId,
                IsRadar2Visible, Radar2ModeNameId, IsAamLaunchZoneVisible]
      children = [
        {
          size
          pos = [0, pos]
          halign = ALIGN_CENTER
          clipChildren = true
          children
        },
        markers
      ]
    }
  }
}

local function C_ScopeSquareBackground(width, height) {

  local back = {
    rendObj = ROBJ_SOLID
    size = [width, height]
    color = areaBackgroundColor
  }

  local frame = {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    color = greenColorGrid
    fillColor = areaBackgroundColor
    commands = [
      [VECTOR_LINE, 0, 0, 0, 100],
      [VECTOR_LINE, 0, 100, 100, 100],
      [VECTOR_LINE, 100, 100, 100, 0],
      [VECTOR_LINE, 100, 0, 0, 0]
    ]
  }

  local offsetW = Computed(@() 100 * (0.5 - (0.0 - ElevationMin.value) * ElevationRangeInv.value))
  local function crosshair(){
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(3)
      color = greenColorGrid
      size = [width, height]
      watch = offsetW
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
    local offset = offsetW.value
    local gridMain = {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      lineWidth = max(LINE_WIDTH, hdpx(2*LINE_WIDTH))
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

    local gridSecondary = {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      color = greenColorGrid
      lineWidth = defLineWidth
      opacity = 0.42
      commands = gridSecondaryCommands
    }

  local children = [back, frame, crosshair, gridMain, gridSecondary]
    return styleLineForeground.__merge({
      size = SIZE_TO_CONTENT
      children
      watch = [ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax]
    })
  }
}

local function C_ScopeSquareAzimuthComponent(width, height, azimuthWatched, elevatonWatched, halfAzimuthWidthWatched, halfElevationWidthWatched) {
  return function() {
    local azimuthRange = AzimuthRange.value
    local halfAzimuthWidth   = 100.0 * (azimuthRange > 0 ? halfAzimuthWidthWatched.value / azimuthRange : 0)
    local halfElevationWidth = 100.0 * (azimuthRange > 0 ? halfElevationWidthWatched.value * ElevationRangeInv.value : 0)

    local children = {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = defLineWidth
      color = greenColor
      fillColor = greenColorGrid
      opacity = 0.6
      size = [width, height]
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
      transform = {
        translate = [azimuthWatched.value * width, (1.0 - elevatonWatched.value) * height]
      }
    })
  }
}

local function createTargetOnRadarCScopeSquare(index, radius, radarWidth, radarHeight, is_mfd) {
  local target = targets[index]
  local opacity = (1.0 - target.ageRel) * target.signalRel

  local azimuthRel = HasAzimuthScale.value ? target.azimuthRel : 0.0
  local azimuthWidthRel = target.azimuthWidthRel
  local azimuthLeft = azimuthRel - azimuthWidthRel * 0.5

  local elevationRel = target.elevationRel
  local elevationWidthRel = target.elevationWidthRel
  local elevationLowerRel = elevationRel - elevationWidthRel * 0.5

  local selectionFrame = null

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

  if (target.isSelected || target.isDetected || !target.isEnemy) {
    local frameCommands = []

    local angularGateWidthMult = 4

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

    selectionFrame = target.isSelected
    ? @() styleLineForeground.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = [radarWidth, radarHeight]
        lineWidth = hdpx(3)
        color = greenColorGrid
        fillColor = Color(0, 0, 0, 0)
        pos = [radius, radius]
        commands = frameCommands
        behavior = Behaviors.RtPropUpdate
        update = function() {
          return {
            opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : opacity
          }
        }
      })
    : styleLineForeground.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [radarWidth, radarHeight]
      lineWidth = hdpx(3)
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      pos = [radius, radius]
      commands = frameCommands
    })
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [radarWidth, radarHeight]
    color = greenColorGrid
    fillColor = greenColorGrid
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
  }
}

local C_ScopeSquareMarkers = function(radarWidth, radarHeight) {
  local offsetScaleFactor = 1.3
  local elevationZeroHeightRel = (0.0 - ElevationMin.value) * ElevationRangeInv.value
  return {
    size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarHeight]
    children = [
      @() styleText.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), hdpx(4)]
        watch = ElevationMax
        text = ::str(floor(ElevationMax.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      })
      @() styleText.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), (1.0 - elevationZeroHeightRel) * radarHeight - hdpx(4)]
        watch = ElevationMin
        text = ::str("0", ::loc("measureUnits/deg"))
      })
      @() styleText.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), radarHeight - hdpx(20)]
        watch = ElevationMin
        text = ::str(floor(ElevationMin.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      })
      @() styleText.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [hdpx(4), hdpx(4)]
        watch = AzimuthMin
        text = ::str(floor(AzimuthMin.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
      })
      {
        size = [radarWidth, SIZE_TO_CONTENT]
        children = @() styleText.__merge({
          rendObj = ROBJ_DTEXT
          pos = [-hdpx(4), hdpx(4)]
          hplace = ALIGN_RIGHT
          watch = AzimuthMax
          text = ::str(floor(AzimuthMax.value * radToDeg + 0.5), ::loc("measureUnits/deg"))
        })
      }
    ]
  }
}

local function C_Scope(width, height) {
  local bkg = C_ScopeSquareBackground(width, height)
  local azim1 = C_ScopeSquareAzimuthComponent(width, height, Azimuth, Elevation, AzimuthHalfWidth, ElevationHalfWidth)
  local azim2 = C_ScopeSquareAzimuthComponent(width, height, Azimuth2, Elevation2, AzimuthHalfWidth2, ElevationHalfWidth2)
  local tgts = targetsComponent(width, height, createTargetOnRadarCScopeSquare, false)
  local markers = C_ScopeSquareMarkers(width, height)

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
          size = SIZE_TO_CONTENT
          clipChildren = true
          children
        }
        markers
      ]
    }
  }
}

local function createTargetOnScreen(id, width) {
  local function radarTgtsSpd(){
    local spd = screenTargets?[id]?.speed
    return {
      text = (spd != null) ? ::cross_call.measureTypes.CLIMBSPEED.getMeasureUnitsText(spd) : ""
      opacity = radarState.selectedTargetSpeedBlinking ? (round(radarState.currentTime * 4) % 2 == 0 ? 1.0 : 0.42) : 1.0
    }
  }

  local function radarTgtsDist() {
    local dist = screenTargets?[id]?.dist
    return {text = (dist != null) ? ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(dist) : ""}
  }

  local function updateTgtVelocityVector() {
    if (radarState.targetAspectEnabled) {
      local target = screenTargets?[id]
      local targetLateralSpeed = 0
      local targetRadialSpeed = 0
      if (target != null) {
        targetLateralSpeed = target.azimuthRate * target.dist
        targetRadialSpeed = target.speed - Speed.value
      }
      local targetSpeed = sqrt(targetLateralSpeed * targetLateralSpeed + targetRadialSpeed * targetRadialSpeed)
      local targetSpeedInv = 1.0 / max(targetSpeed, 1.0)
      local innerRadius = 10
      local outerRadius = 50
      local speedToOuterRadius = 0.1
      return {
        commands = [
          [ VECTOR_ELLIPSE, 50, 50, innerRadius, innerRadius],
          //[ VECTOR_ELLIPSE, 50, 50, outerRadius, outerRadius],
          [ VECTOR_LINE,
            50 + targetLateralSpeed * targetSpeedInv * innerRadius,
            50 + targetRadialSpeed  * targetSpeedInv * innerRadius,
            50 + targetLateralSpeed * targetSpeedInv * min(innerRadius + targetSpeed * speedToOuterRadius, outerRadius),
            50 + targetRadialSpeed  * targetSpeedInv * min(innerRadius + targetSpeed * speedToOuterRadius, outerRadius)
          ]
        ]
      }
    }
    else
      return { commands = [] }
  }

  return @() {
    size = [width, width]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      local tgt = screenTargets?[id]
      return {
        opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : 1.0
        transform = {
          translate = [
            (tgt?.x ?? -100) - 0.5 * width,
            (tgt?.y ?? -100) - 0.5 * width
          ]
        }
      }
    }
    children = [
      @() {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1) * 4.0
        color = greenColor
        size = [width, width]
        commands = [
          [VECTOR_LINE, 0, 0, 0, 100],
          [VECTOR_LINE, 0, 100, 100, 100],
          [VECTOR_LINE, 100, 100, 100, 0],
          [VECTOR_LINE, 100, 0, 0, 0],
        ]
      },
      @() {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1) * 4.0
        color = greenColor
        fillColor = Color(0, 0, 0, 0)
        pos = [-0.25 * width, width]
        size = [1.5 * width, 1.5 * width]
        behavior = Behaviors.RtPropUpdate
        update = updateTgtVelocityVector
      },
      styleText.__merge({
        rendObj = ROBJ_DTEXT
        size = [width * 4, SIZE_TO_CONTENT]
        behavior = Behaviors.RtPropUpdate
        pos = [width + hdpx(5), 0]
        fontSize = hudFontHgt
        fontFxFactor = min(hdpx(8), 8)
        update = radarTgtsDist
      }),
      styleText.__merge({
        rendObj = ROBJ_DTEXT
        size = [width * 4, SIZE_TO_CONTENT]
        behavior = Behaviors.RtPropUpdate
        pos = [width + hdpx(5), hdpx(35) * sh(100) / 1080]
        fontSize = hudFontHgt
        fontFxFactor = min(hdpx(8), 8)
        update = radarTgtsSpd
      })
    ]
  }
}


local forestallRadius = hdpx(15)
local targetOnScreenWidth = hdpx(50)

local targetsOnScreenComponent = function() {
  local targetSize = MfdIlsEnabled.value ? ilsHdpx(100) : targetOnScreenWidth
  local getTargets = function() {
    if (!HasAzimuthScale.value)
      return null
    else if (!screenTargets)
      return null

    local targetsRes = []
    foreach (id, target in screenTargets) {
      if (!target)
        continue
      targetsRes.append(createTargetOnScreen(id, targetSize))
    }
    return targetsRes
  }

  return @(){
    size = [radarSw(100), radarSh(50)]
    children = getTargets()
    watch = [ ScreenTargetsTrigger, HasAzimuthScale ]
  }
}()

local forestallVisible = {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [2 * forestallRadius, 2 * forestallRadius]
    lineWidth = ilsHdpx(2) * LINE_WIDTH
    color = greenColor
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : 1.0
      transform = {
        translate = [forestall.x - forestallRadius, forestall.y - forestallRadius]
      }
    }
}
local function forestallComponent() {
  return {
    size = [sw(100), sh(100)]
    children = IsForestallVisible.value ? forestallVisible : null
    watch = IsForestallVisible
  }
}

local function getLockZoneOpacity() {
  return round(radarState.currentTime * 8) % 2 == 0 ? 100 : 0
}

local scanZoneAzimuthComponent = function mkScanZoneAzimuthComponent() {
  local width = radarSw(100)
  local height = radarSh(100)

  local function scanZoneAzim(){
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
      watch = ScanZoneWatched
      opacity = 0.3
      transform = {
        translate = [_x0, _y0]
      }
      children = {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1) * 4.0
        color = greenColor
        fillColor = Color(0, 0, 0, 0)
        size = [width, height]
        commands = commands
      }
    }
  }
  return function() {
    return {
      watch = IsScanZoneAzimuthVisible
      children = IsScanZoneAzimuthVisible.value ? scanZoneAzim : null
    }
  }
}()

local scanZoneElevationComponent = function mkScanZoneElevationComponent() {
  local width = radarSw(100)
  local height = radarSh(100)
  local mw = 100 / width
  local mh = 100 / height

  local function scanZoneElev(){
    local {x2, x3, y2, y3} = ScanZoneWatched.value
    local _x0 = (x2 + x3) * 0.5
    local _y0 = (y2 + y3) * 0.5
    local px2 = (x2 - _x0) * mw
    local py2 = (y2 - _y0) * mh
    local px3 = (x3 - _x0) * mw
    local py3 = (y3 - _y0) * mh

    return {
      opacity = 0.3
      watch = ScanZoneWatched
      transform = {
        translate = [
          (x2 + x3) * 0.5,
          (y2 + y3) * 0.5
        ]
      }
      children = {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1) * 4.0
        color = greenColor
        fillColor = Color(0, 0, 0, 0)
        size = [width, height]
        commands = [[ VECTOR_LINE, px2, py2, px3, py3 ]]
      }
    }
  }
  return function() {
    return {
      watch = IsScanZoneElevationVisible
      children = IsScanZoneElevationVisible.value ? scanZoneElev : null
    }
  }
}()

local lockZoneComponent = function mkLockZoneComponent() {
  local width = radarSw(100)
  local height = radarSh(100)
  local mw = 100 / width
  local mh = 100 / height
  local corner = 0.1
  local lineWidth = hdpx(1) * 4.0
  local fillColor = Color(0, 0, 0, 0)
  local size = [width, height]
  local function lockZoneComp() {
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
    return {
      watch = [LockZoneWatched, LockDistMin, LockDistMax ]
      opacity = getLockZoneOpacity()
      transform = {
        translate = [_x0, _y0 ]
      }
      children = {
        rendObj = ROBJ_VECTOR_CANVAS
        color = greenColor
        lineWidth
        fillColor
        size
        commands
      }
    }
  }
  return @() {
    watch = IsLockZoneVisible
    children = IsLockZoneVisible?.value ? lockZoneComp : null
  }
}()

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
    resPoint2.y = p2.y + (dy > 0 ? 0.5 : -0.5) * ilsHdpx(50)
  }
  else {
    resPoint2.y = p2.y
    resPoint2.x = p2.x + (dx > 0 ? 0.5 : -0.5) * ilsHdpx(50)
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


local forestallTgtLine = function(){
  local w = sw(100)
  local h = sh(100)
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [w, h]
    lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)
    color = greenColor
    opacity = 0.8
    behavior = Behaviors.RtPropUpdate
    update = function() {
      local resLine = getForestallTargetLineCoords()

      return {
        opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : 1.0
        commands = [
          [VECTOR_LINE, resLine[0].x * 100.0 / w, resLine[0].y * 100.0 / h, resLine[1].x * 100.0 / w, resLine[1].y * 100.0 / h]
        ]
      }
    }
  }
}()

local function forestallTargetLine() {
  return {
    size = [sw(100), sh(100)]
    children = IsForestallVisible.value ? forestallTgtLine : null
    watch = IsForestallVisible
  }
}


local compassComponent = @() {
  size = SIZE_TO_CONTENT
  pos = [sw(50) - 0.5 * compassWidth, sh(12)]
  children = [
    compass(styleText.__merge(styleLineForeground), compassWidth, compassHeight, greenColor)
  ]
}


local function createAzimuthMark(width, height, is_selected, is_detected, is_enemy) {
  local frame = null

  if (is_selected || is_detected || !is_enemy) {
    local frameSizeW = width * 1.5
    local frameSizeH = height * 1.5
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
      pos = [(width - frameSizeW) * 0.5, (height - frameSizeH) * 0.5 ]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1) * 2.0
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      commands = commands
    }
  }

  return {
    size = [width, height]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1) * 3.0
    color = greenColor
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_LINE, 0, 100, 50, 0],
      [VECTOR_LINE, 50, 0, 100, 100],
      [VECTOR_LINE, 100, 100, 0, 100]
    ]
    children = frame
  }
}
local function createAzimuthMarkWithOffset(id, width, height, total_width, angle, is_selected, is_detected, is_enemy, isSecondRound) {
  local offset = (isSecondRound ? total_width : 0) +
    total_width * angle / 360.0 + 0.5 * width

  local animTrigger = ::str("fadeMarker", id, (is_selected ? "_1" : "_0"))

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
    children = createAzimuthMark(width, height, is_selected, is_detected, is_enemy)
    animations
  }
}


local function createAzimuthMarkStrike(total_width, height, markerWidth) {
  return function() {
    local markers = []
    foreach(id, azimuthMarker in azimuthMarkers) {
      if (!azimuthMarker)
        continue

      markers.append(createAzimuthMarkWithOffset(id, markerWidth, height, total_width,
        azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.isEnemy, false))
      markers.append(createAzimuthMarkWithOffset(id, markerWidth, height, total_width,
        azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.isEnemy, true))
    }

    return {
      size = [total_width * 2.0, height]
      pos = [0, height * 0.5]
      watch = AzimuthMarkersTrigger
      children = markers
    }
  }
}

local function createAzimuthMarkStrikeComponent(width, total_width, height) {

  local markerWidth = hdpx(20)
  local offsetW = Computed( @() 0.5 * (width - compassOneElementWidth)
    + CompassValue.value * compassOneElementWidth * 2.0 / compassStep
    - total_width)

  return {
    size = [width, height * 2.0]
    clipChildren = true
    children = @() {
      children = createAzimuthMarkStrike(total_width, height, markerWidth)
      watch = offsetW
      transform = {
        translate = [offsetW.value, 0]
      }
    }
  }
}


local function azimuthMarkStrike() {
  local width = compassWidth * 1.5
  local totalWidth = 2.0 * getCompassStrikeWidth(compassOneElementWidth, compassStep)

  return {
    size = SIZE_TO_CONTENT
    pos = [sw(50) - 0.5 * width, sh(17)]
    children = [
      createAzimuthMarkStrikeComponent(width, totalWidth, hdpx(30))
    ]
  }
}


local mkRadarBase = @(posWatch, size, isAir, mfd = false) function() {
  local mode = mfd ? MfdViewMode.value : ViewMode.value
  local isSquare = mode == RadarViewMode.B_SCOPE_SQUARE
  local width = mfd && MfdRadarEnabled.value ? radarPosSize.value.w : size
  local height = mfd && MfdRadarEnabled.value ? radarPosSize.value.h : width
  local pos = mfd && MfdRadarEnabled.value ? radarPosSize.value.h * 0.3 : 0


  local scopeChild = null
  local cScope = null
  local azimuthRange = AzimuthRange.value
  if (mode == RadarViewMode.B_SCOPE_SQUARE) {
    if (azimuthRange > PI)
      scopeChild = B_Scope(width, height)
    else
      scopeChild = B_ScopeSquare(HasAzimuthScale.value ? width : 0.2 * width, height, mfd)
  }
  else if (mode == RadarViewMode.B_SCOPE_ROUND) {
    if (azimuthRange > PI)
      scopeChild = B_Scope(width, height)
    else
      scopeChild = B_ScopeHalf(width, height, pos, mfd)
  }
  if (IsCScopeVisible.value && !isPlayingReplay.value && azimuthRange <= PI) {
    cScope = {
      pos = [0, isSquare ? width * 0.5 + hdpx(180) : height * 0.5 + hdpx(30)]
      children = C_Scope(width, height * 0.42)
    }
  }
  return {
    watch = [ViewMode, MfdViewMode, MfdRadarEnabled, AzimuthMax, AzimuthMin, IsCScopeVisible, HasAzimuthScale,
      IsRadarVisible, IsRadar2Visible, posWatch]
    pos = posWatch.value
    children = [scopeChild, cScope]
  }
}

local function radarMfdBackground() {
  local backSize = [radarPosSize.value.w / RadarScale.value,
    radarPosSize.value.h / RadarScale.value]
  local backPos = [radarPosSize.value.x - (1.0 - RadarScale.value) * 0.5 * backSize[0],
   radarPosSize.value.y - (1.0 - RadarScale.value) * 0.5 * backSize[1]]
  return {
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

local function mkRadar(radarPosX = sh(8), radarPosY = sh(32), radarSize = sh(28), isAir = false, radar_color = greenColor) {
  updateRadarComponentColor(radar_color)
  local radarPos = !isAir ? Watched([radarPosX, radarPosY])
    : Computed(function() {
        local isSquare = ViewMode.value == RadarViewMode.B_SCOPE_SQUARE
        local offset = isSquare && IsCScopeVisible.value ? -radarSize * 0.5
          : !isSquare && !IsCScopeVisible.value && isAir ? radarSize * 0.5
          : 0
        return [radarPosX, radarPosY + offset]
      })
  local radarHudVisibleChildren = [
    targetsOnScreenComponent
    forestallComponent
    forestallTargetLine
    mkRadarBase(radarPos, radarSize, isAir)
    scanZoneAzimuthComponent
    scanZoneElevationComponent
    lockZoneComponent
    compassComponent
    azimuthMarkStrike
  ]

  return @() {
    watch = IsRadarHudVisible
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = IsRadarHudVisible.value ? radarHudVisibleChildren : null
  }
}

local function mkRadarForMfd(radarPosX = sh(8), radarPosY = sh(32), radarColor = greenColor) {
  updateRadarComponentColor(radarColor)
  local radarMFDEnabled = mkRadarBase(Watched([radarPosX, radarPosY]), sh(28), true, true) //fix me: mfd radar size overrided inside
  return @() {
    watch = [MfdIlsEnabled, MfdRadarEnabled]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = [
      MfdRadarEnabled.value || MfdIlsEnabled.value ? radarMfdBackground : null,
      MfdRadarEnabled.value ? radarMFDEnabled : null
    ]
  }
}


return {
  state = radarState
  mkRadar
  mkRadarForMfd
}