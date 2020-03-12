local math = require("std/math.nut")
local screenState = require("style/screenState.nut")
local interopGen = require("daRg/helpers/interopGen.nut")
local compass = require("compass.nut")
local compassState = require("compassState.nut")
local hudState = require("hudState.nut")


local style = {}

local greenColor = Color(10, 202, 10, 250)
local greenColorGrid = Color(10, 202, 10, 200)
local backgroundColor = Color(0, 0, 0, 150)
local fontOutlineColor = Color(0, 0, 0, 235)
local targetSectorColor = Color(10, 40, 10, 200)

const AIM_LINE_WIDTH = 2.0
const TURRET_LINE_WIDTH = 1.0

local compassWidth = hdpx(500)
local compassHeight = hdpx(40)
local compassStep = 5.0
local compassOneElementWidth = compassHeight

local getCompassStrikeWidth = @(oneElementWidth, step) 360.0 * oneElementWidth / step

local modeNames = [ "hud/standby", "hud/search", "hud/acquisition", "hud/ACM", "hud/track", "hud/air_search", "hud/ground_search" ]

local radarState = {
  IsRadarHudVisible = Watched(false)
  IsNoiseSignaVisible = Watched(false)
  MfdRadarEnabled = Watched(false)
  MfdIlsEnabled = Watched(false)

  //radar 1
  IsRadarVisible = Watched(false)
  RadarModeNameId = Watched(-1)
  Azimuth = Watched(0.0)
  Elevation = Watched(0.0)
  Distance = Watched(0.0)
  AzimuthHalfWidth = Watched(0.0)
  ElevationHalfWidth = Watched(0.0)
  DistanceGateWidthRel = Watched(0.0)
  NoiseSignal = Watched(0)

  //radar 2
  IsRadar2Visible = Watched(false)
  Radar2ModeNameId = Watched(-1)
  Azimuth2 = Watched(0.0)
  Elevation2 = Watched(0.0)
  Distance2 = Watched(0.0)
  AzimuthHalfWidth2 = Watched(0.0)
  ElevationHalfWidth2 = Watched(0.0)
  NoiseSignal2 = Watched(0)

  AimAzimuth = Watched(0.0)
  TurretAzimuth = Watched(0.0)
  TargetRadarAzimuthWidth = Watched(0.0)
  TargetRadarDist = Watched(0.0)
  AzimuthMin = Watched(0)
  AzimuthMax = Watched(0)
  ElevationMin = Watched(0)
  ElevationMax = Watched(0)

  IsCScopeVisible = Watched(false)
  ScanAzimuthMin = Watched(0)
  ScanAzimuthMax = Watched(0)
  ScanElevationMin = Watched(0)
  ScanElevationMax = Watched(0)

  targets = []
  TargetsTrigger = Watched(0)
  currentTime = 0.0
  screenTargets = {}
  ScreenTargetsTrigger = Watched(0)
  ViewMode = Watched(0)
  HasAzimuthScale = Watched(0)
  HasDistanceScale = Watched(0)
  ScanPatternsMax = Watched(0)
  DistanceMax = Watched(0)
  DistanceScalesMax = Watched(0)
  azimuthMarkers = {}
  AzimuthMarkersTrigger = Watched(0)
  Irst = Watched(false)

  MfdIlsHeight = Watched(0)

  IsForestallVisible = Watched(false)
  forestall = {
    x = 0.0
    y = 0.0
  }
  selectedTarget = {
    x = 0.0
    y = 0.0
  }

  UseLockZoneRotated = Watched(false)
  FoV = Watched(0)
  LockZoneTrigger = Watched(false)
  IsLockZoneVisible = Watched(false)
  LockDistMin = Watched(0)
  LockDistMax = Watched(0)
  lockZone = {
    x = 0.0
    y = 0.0
    w = 0.0
    h = 0.0
    a = 0.0
    x0 = 0.0
    y0 = 0.0
    x1 = 0.0
    y1 = 0.0
    x2 = 0.0
    y2 = 0.0
    x3 = 0.0
    y3 = 0.0
  }

  radarPosSize = {
    x = 0.0
    y = 0.0
    w = 0.0
    h = 0.0
  }

  selectedTargetBlinking = false
  selectedTargetSpeedBlinking = false

  IsAamLaunchZoneVisible = Watched(false)
  AamLaunchZoneDist    = Watched(0.0)
  AamLaunchZoneDistMin = Watched(0.0)
  AamLaunchZoneDistMax = Watched(0.0)
}

local getAzimuthRange = @() radarState.AzimuthMax.value - radarState.AzimuthMin.value
local getElevationRange = @() radarState.ElevationMax.value - radarState.ElevationMin.value
local getBlinkOpacity = @() math.round(radarState.currentTime * 3) % 2 == 0 ? 1.0 : 0.2


::interop.updateCurrentTime <- function(curr_time) {
  radarState.currentTime = curr_time
}


::interop.updateBlinking <- function(isTargetBlink, isSpeedBlink) {
  radarState.selectedTargetBlinking = isTargetBlink
  radarState.selectedTargetSpeedBlinking = isSpeedBlink
}


::interop.clearTargets <- function() {
  local needUpdate = false
  for(local i = 0; i < radarState.targets.len(); ++i)
  {
    if (radarState.targets[i] != null)
    {
      radarState.targets[i] = null
      needUpdate = true
    }
  }

  if (needUpdate)
    radarState.TargetsTrigger.trigger()
}


::interop.updateTarget <- function (index, azimuth_rel, azimuth_width_rel, elevation_rel, elevation_width_rel, distance_rel, distance_width_rel, age_rel, is_selected, is_detected, is_enemy, signal_rel) {
  if(index >= radarState.targets.len())
    radarState.targets.resize(index + 1)

  local cvt = @(val, vmin, vmax, omin, omax) omin + ((omax - omin) * (val - vmin)) / (vmax - vmin)

  local signalRel = signal_rel < 0.05
    ? 0.0
    : cvt(signal_rel, 0.05, 1.0, 0.3, 1.0)

  radarState.targets[index] = {
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

  radarState.TargetsTrigger.trigger()
}

local radarHdpx = function(px)
{
  return radarState.MfdIlsEnabled.value ? (px * radarState.MfdIlsHeight.value / 1024) : hdpx(px)
}
local radarSh = function(h)
{
  return radarState.MfdIlsEnabled.value ? (h * radarState.MfdIlsHeight.value / 100) : sh(h)
}
local radarSw = function(w)
{
  return radarState.MfdIlsEnabled.value ? (w * radarState.MfdIlsHeight.value / 100) : sw(w)
}
local getFontScale = function()
{
  return radarState.MfdRadarEnabled.value || radarState.MfdIlsEnabled.value ? 2.5 : (sh(100) / 1080)
}
style.lineForeground <- class {
  color = greenColor
  fillColor = greenColor
  lineWidth = hdpx(1) * LINE_WIDTH
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = 40
  fontFx = FFT_GLOW
  fontScale = getFontScale()
}

const targetLifeTime = 5.0


::interop.updateScreenTarget <- function(id, x, y, dist, speed) {
  if (!radarState.screenTargets)
    radarState.screenTargets = {}

  if (!radarState.screenTargets?[id])
  {
    radarState.screenTargets[id] <- {
      x = x
      y = y
      dist = dist
      speed = speed
      isUpdated = true
    }
  }
  else
  {
    radarState.screenTargets[id].x = x
    radarState.screenTargets[id].y = y
    radarState.screenTargets[id].dist = dist
    radarState.screenTargets[id].speed = speed
    radarState.screenTargets[id].isUpdated = true
  }

  radarState.ScreenTargetsTrigger.trigger()
}


::interop.updateAzimuthMarker <- function(id, target_time, age, azimuth_world_deg, is_selected, is_detected, is_enemy) {
  if (!radarState.azimuthMarkers)
    radarState.azimuthMarkers = {}

  if (!radarState.azimuthMarkers?[id])
  {
    radarState.azimuthMarkers[id] <- {
      azimuthWorldDeg = azimuth_world_deg
      targetTime = target_time
      age = age
      isSelected = is_selected
      isDetected = is_detected
      isEnemy = is_enemy
      isUpdated = true
    }
  }
  else if (target_time > radarState.azimuthMarkers[id].targetTime)
  {
    radarState.azimuthMarkers[id].azimuthWorldDeg = azimuth_world_deg
    radarState.azimuthMarkers[id].isSelected = is_selected
    radarState.azimuthMarkers[id].targetTime = target_time
    radarState.azimuthMarkers[id].age = age
    radarState.azimuthMarkers[id].isDetected = is_detected
    radarState.azimuthMarkers[id].isEnemy = is_enemy
    radarState.azimuthMarkers[id].isUpdated = true
  }
  else
    return

  radarState.AzimuthMarkersTrigger.trigger()
}


::interop.resetTargetsFlags <- function()
{
  foreach(id, target in radarState.screenTargets)
    if (target)
      target.isUpdated = false

  foreach(id, marker in radarState.azimuthMarkers)
    if (marker)
      marker.isUpdated = false
}


::interop.clearUnusedTargets <- function()
{
  local needUpdate = false
  foreach(id, target in radarState.screenTargets)
    if (target && !target.isUpdated)
    {
      radarState.screenTargets[id] = null
      needUpdate = true
    }
  if(needUpdate)
    radarState.ScreenTargetsTrigger.trigger()

  needUpdate = false
  foreach(id, marker in radarState.azimuthMarkers)
    if (marker && !marker.isUpdated && radarState.currentTime > marker.targetTime + targetLifeTime)
    {
      radarState.azimuthMarkers[id] = null
      needUpdate = true
    }
  if(needUpdate)
    radarState.AzimuthMarkersTrigger.trigger()
}


::interop.updateForestall <- function(x, y)
{
  radarState.forestall.x = x
  radarState.forestall.y = y
}


::interop.updateSelectedTarget <- function(x, y)
{
  radarState.selectedTarget.x = x
  radarState.selectedTarget.y = y
}

::interop.updateLockZone <- function(x0, y0, x1, y1, x2, y2, x3, y3)
{
  radarState.lockZone.x0 = x0
  radarState.lockZone.y0 = y0
  radarState.lockZone.x1 = x1
  radarState.lockZone.y1 = y1
  radarState.lockZone.x2 = x2
  radarState.lockZone.y2 = y2
  radarState.lockZone.x3 = x3
  radarState.lockZone.y3 = y3

  radarState.LockZoneTrigger.trigger()
}

::interop.updateLockZoneRotated <- function(x0, y0, x1, y1, x2, y2, x3, y3)
{
  ::updateLockZone(x0, y0, x1, y1, x2, y2, x3, y3)
}

::interop.updateRadarPosSize <- function(x, y, w, h)
{
  radarState.radarPosSize.x = x
  radarState.radarPosSize.y = y
  radarState.radarPosSize.w = w
  radarState.radarPosSize.h = h
}

interopGen({
  stateTable = radarState
  prefix = "radar"
  postfix = "Update"
})

local targetsComponent = function(radarWidth, radarHeight, createTargetFunc)
{
  local getTargets = function() {
    local targets = []
    for(local i = 0; i < radarState.targets.len(); ++i)
    {
      if (!radarState.targets[i])
        continue
      targets.append(createTargetFunc(i, hdpx(5) * 0, radarWidth, radarHeight))
    }
    return targets
  }

  return @()
  {
    size = [radarWidth, radarHeight]
    children = getTargets()
    watch = radarState.TargetsTrigger
  }
}

local B_ScopeSquareBackground = function(width, height) {

  local getChildren = function() {

    local azimuthRangeInv   = 1.0 / getAzimuthRange()

    local scanAzimuthMinRel = radarState.ScanAzimuthMin.value * azimuthRangeInv
    local scanAzimuthMaxRel = radarState.ScanAzimuthMax.value * azimuthRangeInv

    local gridSecondaryCommands = []

    if (radarState.HasDistanceScale.value)
      gridSecondaryCommands = [
        [VECTOR_LINE, 50 + scanAzimuthMinRel * 100, 25, 50 + scanAzimuthMaxRel * 100, 25],
        [VECTOR_LINE, 50 + scanAzimuthMinRel * 100, 50, 50 + scanAzimuthMaxRel * 100, 50],
        [VECTOR_LINE, 50 + scanAzimuthMinRel * 100, 75, 50 + scanAzimuthMaxRel * 100, 75]
      ]

    if (radarState.HasAzimuthScale.value)
    {
      local azimuthRelStep = math.PI / 12.0 * azimuthRangeInv
      local azimuthRel = 0.0
      while (azimuthRel > radarState.ScanAzimuthMin.value * azimuthRangeInv)
      {
        gridSecondaryCommands.append([
          VECTOR_LINE,
          50 + azimuthRel * 100, 0,
          50 + azimuthRel * 100, 100
        ])
        azimuthRel -= azimuthRelStep
      }
      azimuthRel = 0.0
      while (azimuthRel < radarState.ScanAzimuthMax.value * azimuthRangeInv)
      {
        gridSecondaryCommands.append([
          VECTOR_LINE,
          50 + azimuthRel * 100, 0,
          50 + azimuthRel * 100, 100
        ])
        azimuthRel += azimuthRelStep
      }
    }

    local back = {
      rendObj = ROBJ_SOLID
      size = [width, height]
      color = backgroundColor
    }

    local frame = style.lineForeground.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      gridSecondaryCommands = [
        [VECTOR_LINE, 0, 0, 0, 100],
        [VECTOR_LINE, 0, 100, 100, 100],
        [VECTOR_LINE, 100, 100, 100, 0],
        [VECTOR_LINE, 100, 0, 0, 0]
      ]
    })

    local gridMain = {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      color = greenColorGrid
      lineWidth = hdpx(2) * LINE_WIDTH
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

    local gridSecondary = {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1)
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      size = [width, height]
      opacity = 0.42
      commands = gridSecondaryCommands
    }

    return [ back, frame, gridMain, gridSecondary ]
  }

  return @() style.lineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = getChildren()
    watch = [radarState.ScanAzimuthMin, radarState.ScanAzimuthMax, radarState.ScanElevationMin, radarState.ScanElevationMax]
  })
}

local function B_ScopeSquareTargetSectorComponent(width, valueWatched, distWatched, halfWidthWatched, height, fillColor = greenColorGrid) {

  local function getChildren() {
    if (distWatched && halfWidthWatched && halfWidthWatched.value > 0) {

      local halfAzimuthWidth = 100.0 * (getAzimuthRange() > 0 ? halfWidthWatched.value / getAzimuthRange() : 0)
      local com = [[VECTOR_POLY, -halfAzimuthWidth, 100 * (1 - distWatched.value), halfAzimuthWidth, 100 * (1 - distWatched.value),
            halfAzimuthWidth, 100, -halfAzimuthWidth, 100]]

      if (valueWatched.value * 100 - halfAzimuthWidth < 0)
        com.append([VECTOR_POLY, -halfAzimuthWidth + 100, 100 * (1 - distWatched.value), halfAzimuthWidth + 100, 100 * (1 - distWatched.value),
            halfAzimuthWidth + 100, 100, -halfAzimuthWidth + 100, 100])
      if (valueWatched.value * 100 + halfAzimuthWidth > 100)
        com.append([VECTOR_POLY, -halfAzimuthWidth - 100, 100 * (1 - distWatched.value), halfAzimuthWidth - 100, 100 * (1 - distWatched.value),
            halfAzimuthWidth - 100, 100, -halfAzimuthWidth - 100, 100])
      return {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1)
        color = greenColor
        fillColor = fillColor
        opacity = 0.42
        size = [width, height]
        commands = com
      }
    }
    return null
  }

  local isTank = getAzimuthRange() > math.PI
  return @() style.lineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = isTank ? getChildren() : []
    watch = [valueWatched, distWatched, halfWidthWatched]
    transform = {
      translate = [valueWatched.value * width, 0]
    }
  })
}

local B_ScopeSquareAzimuthComponent = function(width, height, valueWatched, distWatched, halfWidthWatched, tanksOnly)
{
  local getChildren = function() {
    if (distWatched && distWatched.value == 1.0 && halfWidthWatched && halfWidthWatched.value > 0)
    {
      local halfAzimuthWidth = 100.0 * (getAzimuthRange() > 0 ? halfWidthWatched.value / getAzimuthRange() : 0)

      return {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1)
        color = greenColor
        fillColor = greenColorGrid
        opacity = 0.6
        size = [width, height]
        commands = [
          [VECTOR_POLY, -halfAzimuthWidth, 0, halfAzimuthWidth, 0, halfAzimuthWidth, 100, -halfAzimuthWidth, 100]
        ]
      }
    }
    else
    {
      return style.lineForeground.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = [width, height]
        commands = distWatched
          ? [[VECTOR_LINE_DASHED, 0, 100.0 * (1.0 - distWatched.value), 0, 100.0, hdpx(10), hdpx(5)]]
          : [[VECTOR_LINE, 0, 0, 0, 100.0]]
      })
    }
  }

  local isTank = getAzimuthRange() > math.PI
  return @() style.lineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = !tanksOnly || isTank ? getChildren() : []
    watch = [valueWatched, distWatched, halfWidthWatched]
    transform = {
      translate = [valueWatched.value * width, 0]
    }
  })
}

local B_ScopeSquareLaunchRangeComponent = function(width, height, aamLaunchZoneDist, aamLaunchZoneDistMin, aamLaunchZoneDistMax) {

  local getChildren = function() {
    local commands = [
      [VECTOR_LINE, 80, (1.0 - aamLaunchZoneDist.value) * 100,    100, (1.0 - aamLaunchZoneDist.value)    * 100],
      [VECTOR_LINE, 90, (1.0 - aamLaunchZoneDistMin.value) * 100, 100, (1.0 - aamLaunchZoneDistMin.value) * 100],
      [VECTOR_LINE, 90, (1.0 - aamLaunchZoneDistMax.value) * 100, 100, (1.0 - aamLaunchZoneDistMax.value) * 100]
    ]

    local launchRange = {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(4)
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      size = [width, height]
      opacity = 0.42
      commands = commands
    }

    return launchRange
  }

  return @() style.lineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = getChildren()
    watch = [ aamLaunchZoneDist, aamLaunchZoneDistMin, aamLaunchZoneDistMax]
  })
}

local angularGateWidthMultMin = 4.0
local angularGateWidthMultMax = 6.0
local angularGateWidthMultMinDistanceRel = 0.06
local angularGateWidthMultMaxDistanceRel = 0.33
local angularGateBeamWidthMin = 2.0 * 0.0174
local distanceGateWidthRelMin = 0.05

local function calcAngularGateWidth(distance_rel)
{
  local blend = min((distance_rel - angularGateWidthMultMinDistanceRel) / (angularGateWidthMultMaxDistanceRel - angularGateWidthMultMinDistanceRel), 1.0)
  return angularGateWidthMultMin * blend + angularGateWidthMultMax * (1.0 - blend)
}

local distanceGateWidthMult = 2.0
local iffDistRelMult = 0.5

local function createTargetOnRadarSquare(index, radius, radarWidth, radarHeight)
{
  local target = radarState.targets[index]
  local opacity = (1.0 - target.ageRel) * target.signalRel

  local angleRel = radarState.HasAzimuthScale.value ? target.azimuthRel : 0.5
  local angularWidthRel = radarState.HasAzimuthScale.value ? target.azimuthWidthRel : 1.0
  local angleLeft = angleRel - 0.5 * angularWidthRel
  local angleRight = angleRel + 0.5 * angularWidthRel

  local distanceRel = radarState.HasDistanceScale.value ? target.distanceRel : 0.9
  local radialWidthRel = target.distanceWidthRel

  local selectionFrame = null

  if (target.isSelected || target.isDetected || !target.isEnemy)
  {
    local frameCommands = []

    local angularGateWidthMult = calcAngularGateWidth(distanceRel)
    local angularGateWidthRel = angularGateWidthMult * 2.0 * max(radarState.AzimuthHalfWidth.value, angularGateBeamWidthMin) / getAzimuthRange()
    local angleGateLeftRel = angleRel - 0.5 * angularGateWidthRel
    local angleGateRightRel = angleRel + 0.5 * angularGateWidthRel

    local distanceGateWidthRel = max(radarState.DistanceGateWidthRel.value, distanceGateWidthRelMin) * distanceGateWidthMult
    local distanceInner = distanceRel - 0.5 * distanceGateWidthRel
    local distanceOuter = distanceRel + 0.5 * distanceGateWidthRel

    if (target.isDetected || target.isSelected)
    {
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
    if (target.isSelected)
    {
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
    if (!target.isEnemy)
    {
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
    ? @() style.lineForeground.__merge({
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
    : style.lineForeground.__merge({
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
    lineWidth = 100 * radialWidthRel
    color = greenColorGrid
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


local arrowIcon = function(size)
{
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    color = greenColor
    fillColor = greenColor
    lineWidth = hdpx(1)
    size = size
    commands = [
      [VECTOR_POLY, 50, 0,  0, 50,  35, 50,  35, 100,
      65, 100,  65, 50,  100, 50]
    ]
  }
}


local groundNoiseIcon = function(size)
{
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


local noiseSignalComponent = function(signalWatched, size, isIconOnLeftSide)
{
  local getChildren = function() {
    local children = []
    for (local i = 0; i < 4; ++i)
    {
      children.append({
        rendObj = ROBJ_SOLID
        size = [size[0], size[1] * 0.18]
        color = greenColor
        opacity = signalWatched.value > (3 - i) ? 1.0 : 0.21
      })
    }
    return children
  }

  local indicator = @() {
    watch = signalWatched
    size = size
    flow = FLOW_VERTICAL
    gap = size[1] * (1.0 - 0.18 * 4) / 3.0
    children = getChildren()
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


local noiseSignal = function(size, pos1, pos2)
{
  local getChildren = function() {
    if (!radarState.IsNoiseSignaVisible.value)
      return null
    local children = []
    if (radarState.IsRadarVisible.value && radarState.NoiseSignal.value > 0.5)
      children.append(@(){
        size = size
        pos = pos1
        children = noiseSignalComponent(radarState.NoiseSignal, size, true)
      })
    if (radarState.IsRadar2Visible.value && radarState.NoiseSignal2.value > 0.5)
      children.append(@(){
        size = size
        pos = pos2
        children = noiseSignalComponent(radarState.NoiseSignal2, size, false)
    })
    return children
  }

  return @(){
    size = SIZE_TO_CONTENT
    children = getChildren()
    watch = [
      radarState.IsRadarVisible,
      radarState.IsRadar2Visible,
      radarState.NoiseSignal,
      radarState.NoiseSignal2,
    ]
  }
}


local radToDeg = 180.0 / 3.14159

local makeRadarModeText = function ()
{
  local text = ""
  if (radarState.RadarModeNameId.value >= 0)
    text += ::loc(modeNames[radarState.RadarModeNameId.value])
  else if (radarState.IsRadarVisible.value)
    text += radarState.Irst.value ? ::loc("hud/irst") : ::loc("hud/radarEmitting")
  return text
}

local makeRadar2ModeText = function ()
{
  local text = ""
  if (radarState.Radar2ModeNameId.value >= 0)
    text += ::loc(modeNames[radarState.Radar2ModeNameId.value])
  else if (radarState.IsRadar2Visible.value)
    text += radarState.Irst.value ? ::loc("hud/irst") : ::loc("hud/radarEmitting")
  return text
}

local B_ScopeSquareMarkers = function(radarWidth, radarHeight)
{
  local offsetScaleFactor = 1.3
  return {
    size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarHeight]
    children = [
      {
        size = [0, SIZE_TO_CONTENT]
        children = @() style.lineForeground.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = [hdpx(4), hdpx(4)]
          hplace = ALIGN_RIGHT
          watch = [ radarState.HasAzimuthScale, radarState.ScanAzimuthMin, radarState.ScanAzimuthMax,
                    radarState.ScanElevationMin, radarState.ScanElevationMax, radarState.ScanPatternsMax ]
          text = radarState.HasAzimuthScale.value && radarState.ScanAzimuthMax.value > radarState.ScanAzimuthMin.value ?
            math.floor((radarState.ScanAzimuthMax.value - radarState.ScanAzimuthMin.value) * radToDeg + 0.5) + ::loc("measureUnits/deg") + "x" +
            math.floor((radarState.ScanElevationMax.value - radarState.ScanElevationMin.value) * radToDeg + 0.5) + ::loc("measureUnits/deg") +
            (radarState.ScanPatternsMax.value > 1 ? "*" : " ") : ""
        })
      }
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), hdpx(4)]
        watch = [ radarState.HasDistanceScale, radarState.DistanceMax, radarState.DistanceScalesMax ]
        text = radarState.HasDistanceScale.value ?
          ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(radarState.DistanceMax.value * 1000.0) +
          (radarState.DistanceScalesMax.value > 1 ? "*" : " ") : ""
      })
      style.lineForeground.__merge({
        rendObj = ROBJ_STEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), radarHeight - hdpx(20)]
        text = ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(0.0)
      })
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [hdpx(4), hdpx(4)]
        watch = radarState.AzimuthMin
        text = math.floor(radarState.AzimuthMin.value * radToDeg + 0.5) + ::loc("measureUnits/deg")
      })
      {
        size = [radarWidth, SIZE_TO_CONTENT]
        children = @() style.lineForeground.__merge({
          rendObj = ROBJ_DTEXT
          pos = [-hdpx(4), hdpx(4)]
          hplace = ALIGN_RIGHT
          watch = radarState.AzimuthMax
          text = math.floor(radarState.AzimuthMax.value * radToDeg + 0.5) + ::loc("measureUnits/deg")
        })
      }
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * (0.5 - 0.15), -hdpx(20)]
        text = makeRadarModeText()
      })
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * (0.5 + 0.05), -hdpx(20)]
        text = makeRadar2ModeText()
      })
      noiseSignal(
        [radarWidth * 0.06, radarWidth * 0.06],
        [radarWidth * (0.5 - 0.30), -hdpx(25)],
        [radarWidth * (0.5 + 0.20), -hdpx(25)])
    ]
  }
}

local B_ScopeSquare = function(width, height) {
  local getChildren = function() {
    local children = [
      B_ScopeSquareBackground(width, height),
      B_ScopeSquareTargetSectorComponent(width, radarState.TurretAzimuth, radarState.TargetRadarDist, radarState.TargetRadarAzimuthWidth, height, targetSectorColor),
      B_ScopeSquareAzimuthComponent(width, height, radarState.TurretAzimuth, null, null, true),
      {
        size = [width, width]
        rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
        isSquare = true
        xFragments = 30
        yFragments = 10
        color = greenColor
      }
    ]
    if (radarState.IsRadarVisible.value)
      children.append(B_ScopeSquareAzimuthComponent(width, height, radarState.Azimuth, radarState.Distance, radarState.AzimuthHalfWidth, false))
    if (radarState.IsRadar2Visible.value)
      children.append(B_ScopeSquareAzimuthComponent(width, height, radarState.Azimuth2, radarState.Distance2, radarState.AzimuthHalfWidth2, false))
    if (radarState.IsAamLaunchZoneVisible.value && radarState.HasDistanceScale.value)
      children.append(B_ScopeSquareLaunchRangeComponent(width, height, radarState.AamLaunchZoneDist,
                                                        radarState.AamLaunchZoneDistMin, radarState.AamLaunchZoneDistMax))
    children.append(targetsComponent(width, height, createTargetOnRadarSquare))
    return children
  }

  return @() {
    watch = [ radarState.IsRadarVisible, radarState.RadarModeNameId,
              radarState.IsRadar2Visible, radarState.Radar2ModeNameId,
              radarState.IsAamLaunchZoneVisible, radarState.HasDistanceScale]
    children = [
      {
        size = SIZE_TO_CONTENT
        clipChildren = true
        children = getChildren()
      },
      B_ScopeSquareMarkers(width, height)
    ]
  }
}

local B_ScopeBackground = function(width, height) {

  local circle = {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    color = greenColorGrid
    fillColor = backgroundColor
    lineWidth = hdpx(1) * LINE_WIDTH
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
  }

  local commands = radarState.HasDistanceScale.value ?
  [
    [VECTOR_ELLIPSE, 50, 50, 12.5, 12.5],
    [VECTOR_ELLIPSE, 50, 50, 25.0, 25.0],
    [VECTOR_ELLIPSE, 50, 50, 37.5, 37.5]
  ] :
  [
    [VECTOR_ELLIPSE, 50, 50, 45.0, 45.0]
  ]

  const angleGrad = 30.0
  local angle = math.PI * angleGrad / 180.0
  local dashCount = 360.0 / angleGrad
  for(local i = 0; i < dashCount; ++i)
  {
    commands.append([
      VECTOR_LINE, 50, 50,
      50 + math.cos(i * angle) * 50.0,
      50 + math.sin(i * angle) * 50.0
    ])
  }

  local gridSecondary = {
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    color = greenColorGrid
    fillColor = Color(0, 0, 0, 0)
    size = [width, height]
    opacity = 0.42
    commands = commands
  }

  return {
    children = [
      circle
      gridSecondary
    ]
  }
}

local B_ScopeAzimuthComponent = function(width, valueWatched, distWatched, halfWidthWatched, height, lineWidth = LINE_WIDTH)
{
  local getChildren = function() {
    if (distWatched && distWatched.value == 1.0 && halfWidthWatched && halfWidthWatched.value > 0)
    {
      local sectorCommands = [VECTOR_POLY, 50, 50]
      local step = math.PI * 0.05
      local angleCenter = radarState.AzimuthMin.value + getAzimuthRange() * valueWatched.value - math.PI * 0.5
      local angleFinish = angleCenter + halfWidthWatched.value
      local angle = angleCenter - halfWidthWatched.value

      while (angle <= angleFinish) {
        sectorCommands.append(50.0 + 50.0 * math.cos(angle))
        sectorCommands.append(50.0 + 50.0 * math.sin(angle))
        if (angle == angleFinish)
          break;
        angle += step
        if (angle > angleFinish)
          angle = angleFinish
      }

      return {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1)
        color = greenColor
        fillColor = greenColorGrid
        opacity = 0.6
        size = [width, height]
        commands = [sectorCommands]
      }
    }
    else {
      return function() {
        local angle = radarState.AzimuthMin.value + getAzimuthRange() * valueWatched.value - math.PI * 0.5
        local commands = distWatched ? [VECTOR_LINE_DASHED] : [VECTOR_LINE]
        commands.append(
          50, 50,
          50.0 + 50.0 * (distWatched?.value ?? 1.0) * math.cos(angle),
          50.0 + 50.0 * (distWatched?.value ?? 1.0) * math.sin(angle)
        )
        if (distWatched)
          commands.append(hdpx(10), hdpx(5))

        return {
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = hdpx(1) * lineWidth
          color = greenColor
          size = [width, height]
          watch = [valueWatched, distWatched]
          commands = [commands]
        }
      }
    }
  }

  return @() {
    watch = [valueWatched, distWatched, halfWidthWatched]
    size = SIZE_TO_CONTENT
    children = getChildren()
  }
}

local rad2deg = 180.0 / math.PI

local B_ScopeHalfLaunchRangeComponent = function(width, height, azimuthMin, azimuthMax, aamLaunchZoneDistMin, aamLaunchZoneDistMax) {

  local getChildren = function() {

    local scanAngleStart = azimuthMin.value - math.PI * 0.5
    local scanAngleFinish = azimuthMax.value - math.PI * 0.5
    local scanAngleStartDeg = scanAngleStart * rad2deg
    local scanAngleFinishDeg = scanAngleFinish * rad2deg

    local commands = [
      [VECTOR_SECTOR, 50, 50, aamLaunchZoneDistMin.value * 50, aamLaunchZoneDistMin.value * 50, scanAngleStartDeg, scanAngleFinishDeg],
      [VECTOR_SECTOR, 50, 50, aamLaunchZoneDistMax.value * 50, aamLaunchZoneDistMax.value * 50, scanAngleStartDeg, scanAngleFinishDeg]
    ]

    local launchRange = {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(4)
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      size = [width, height]
      opacity = 0.42
      commands = commands
    }

    return launchRange
  }

  return @() style.lineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = getChildren()
    watch = [azimuthMin, azimuthMax, aamLaunchZoneDistMin, aamLaunchZoneDistMax ]
  })
}

local function B_ScopeSectorComponent(width, valueWatched, distWatched, halfWidthWatched, height, fillColorP = greenColorGrid) {

  local function getChildren() {
    if (distWatched && halfWidthWatched && halfWidthWatched.value > 0) {

      local sectorCommands = [VECTOR_POLY, 50, 50]
      local step = math.PI * 0.05
      local angleCenter = radarState.AzimuthMin.value + getAzimuthRange() *
        (valueWatched?.value ?? 0.5) - math.PI * 0.5
      local angleFinish = angleCenter + halfWidthWatched.value
      local angle = angleCenter - halfWidthWatched.value

      while (angle <= angleFinish) {
        sectorCommands.append(50.0 + distWatched.value * 50 * math.cos(angle))
        sectorCommands.append(50.0 + distWatched.value * 50 * math.sin(angle))
        if (angle == angleFinish)
          break;
        angle += step
        if (angle > angleFinish)
          angle = angleFinish
      }

      return {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1)
        color = greenColor
        fillColor = fillColorP
        opacity = 0.42
        size = [width, height]
        commands = [sectorCommands]
      }
    }
    return null
  }

  return @() {
    watch = [valueWatched, distWatched, halfWidthWatched]
    size = SIZE_TO_CONTENT
    children = getChildren()
  }
}

local function createTargetOnRadarPolar(index, radius, radarWidth, radarHeight)
{
  local target = radarState.targets[index]

  local angle = radarState.HasAzimuthScale.value ? radarState.AzimuthMin.value + getAzimuthRange() * target.azimuthRel - math.PI * 0.5 : -math.PI * 0.5
  local angularWidth = getAzimuthRange() * target.azimuthWidthRel
  local angleLeftDeg = (angle - 0.5 * angularWidth) * 180.0 / math.PI
  local angleRightDeg = (angle + 0.5 * angularWidth) * 180.0 / math.PI

  local distanceRel = radarState.HasDistanceScale.value ? target.distanceRel : 0.9
  local radialWidthRel = radarState.HasAzimuthScale.value ? target.distanceWidthRel : 1.0

  local selectionFrame = null

  if (target.isSelected || target.isDetected || !target.isEnemy)
  {
    local angularGateWidthMult = calcAngularGateWidth(distanceRel)
    local angularGateWidth = angularGateWidthMult * 2.0 * max(radarState.AzimuthHalfWidth.value, angularGateBeamWidthMin)
    local angleGateLeft  = angle - 0.5 * angularGateWidth
    local angleGateRight = angle + 0.5 * angularGateWidth
    if (radarState.AzimuthMax.value - radarState.AzimuthMin.value < math.PI)
    {
      angleGateLeft  = max(angleGateLeft, radarState.AzimuthMin.value - math.PI * 0.5)
      angleGateRight = min(angleGateRight, radarState.AzimuthMax.value - math.PI * 0.5)
    }
    local angleGateLeftDeg = angleGateLeft * 180.0 / math.PI
    local angleGateRightDeg = angleGateRight * 180.0 / math.PI

    local distanceGateWidthRel = max(radarState.DistanceGateWidthRel.value, distanceGateWidthRelMin) * distanceGateWidthMult
    local radiusInner = distanceRel - 0.5 * distanceGateWidthRel
    local radiusOuter = distanceRel + 0.5 * distanceGateWidthRel

    local frameCommands = []

    if (target.isDetected || target.isSelected)
    {
      frameCommands.append(
        [ VECTOR_LINE,
          50 + 50 * math.cos(angleGateLeft) * radiusInner,
          50 + 50 * math.sin(angleGateLeft) * radiusInner,
          50 + 50 * math.cos(angleGateLeft) * radiusOuter,
          50 + 50 * math.sin(angleGateLeft) * radiusOuter
        ],
        [ VECTOR_LINE,
          50 + 50 * math.cos(angleGateRight) * radiusInner,
          50 + 50 * math.sin(angleGateRight) * radiusInner,
          50 + 50 * math.cos(angleGateRight) * radiusOuter,
          50 + 50 * math.sin(angleGateRight) * radiusOuter
        ]
      )
    }
    if (target.isSelected)
    {
      frameCommands.append(
        [ VECTOR_SECTOR, 50, 50, 50 * radiusInner, 50 * radiusInner, angleGateLeftDeg, angleGateRightDeg ],
        [ VECTOR_SECTOR, 50, 50, 50 * radiusOuter, 50 * radiusOuter, angleGateLeftDeg, angleGateRightDeg ]
      )
    }
    if (!target.isEnemy)
    {
      local iffMarkDistanceRel = distanceRel + iffDistRelMult * distanceGateWidthRel
      frameCommands.append(
        [ VECTOR_SECTOR, 50, 50, 50 * iffMarkDistanceRel, 50 * iffMarkDistanceRel, angleLeftDeg, angleRightDeg ]
      )
    }

    selectionFrame = target.isSelected
    ? @() style.lineForeground.__merge({
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
            opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : 1.0
          }
        }
      })
    : style.lineForeground.__merge({
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
    lineWidth = 100 * radialWidthRel
    color = greenColorGrid
    fillColor = Color(0, 0, 0, 0)
    opacity = (1.0 - radarState.targets[index].ageRel)
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

local B_ScopeCircleMarkers = function(radarWidth, radarHeight)
{
  local offsetScaleFactor = 1.3
  return {
    size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarHeight]
    children = [
      {
        size = [0, SIZE_TO_CONTENT]
        children = @() style.lineForeground.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = [0 - hdpx(4), radarHeight * 0.5 + hdpx(5)]
          hplace = ALIGN_RIGHT
          watch = [ radarState.HasAzimuthScale, radarState.ScanAzimuthMin, radarState.ScanAzimuthMax,
                    radarState.ScanElevationMin, radarState.ScanElevationMax, radarState.ScanPatternsMax ]
          text = radarState.HasAzimuthScale.value && radarState.ScanAzimuthMax.value > radarState.ScanAzimuthMin.value ?
            math.floor((radarState.ScanAzimuthMax.value - radarState.ScanAzimuthMin.value) * radToDeg + 0.5) + ::loc("measureUnits/deg") + "x" +
            math.floor((radarState.ScanElevationMax.value - radarState.ScanElevationMin.value) * radToDeg + 0.5) + ::loc("measureUnits/deg") +
            (radarState.ScanPatternsMax.value > 1 ? "*" : " ") : ""
        })
      },
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), radarHeight * 0.5 + hdpx(5)]
        watch = [ radarState.HasDistanceScale, radarState.DistanceMax, radarState.DistanceScalesMax ]
        text = radarState.HasDistanceScale.value ?
          ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(radarState.DistanceMax.value * 1000.0) +
          (radarState.DistanceScalesMax.value > 1 ? "*" : " ") : ""
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_STEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * 0.5 - hdpx(4), -hdpx(18)]
        text = "0" + ::loc("measureUnits/deg")
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_STEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), radarHeight * 0.5 - hdpx(15)]
        text = "90" + ::loc("measureUnits/deg")
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_STEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * 0.5 - hdpx(18), radarHeight + hdpx(4)]
        text = "180" + ::loc("measureUnits/deg")
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_STEXT
        size = SIZE_TO_CONTENT
        pos = [-hdpx(52), radarHeight * 0.5 - hdpx(15)]
        text = "270" + ::loc("measureUnits/deg")
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * (0.5 - 0.15), -hdpx(20)]
        text = makeRadarModeText()
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * (0.5 + 0.05), -hdpx(20)]
        text = makeRadar2ModeText()
      }),
      noiseSignal(
        [radarWidth * 0.06, radarWidth * 0.06],
        [radarWidth * (0.5 - 0.30), -hdpx(25)],
        [radarWidth * (0.5 + 0.20), -hdpx(25)])
    ]
  }
}

local B_Scope = function(width, height) {
  local getChildren = function() {
    local children = [
      B_ScopeBackground(width, height),
      B_ScopeAzimuthComponent(width, radarState.AimAzimuth, null, null, height, AIM_LINE_WIDTH),
      B_ScopeAzimuthComponent(width, radarState.TurretAzimuth, null, null, height, TURRET_LINE_WIDTH),
      B_ScopeSectorComponent(width, radarState.TurretAzimuth, radarState.TargetRadarDist, radarState.TargetRadarAzimuthWidth, height, targetSectorColor)
    ]
    if (radarState.IsRadarVisible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth, radarState.Distance, radarState.AzimuthHalfWidth, height))
    if (radarState.IsRadar2Visible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth2, radarState.Distance2, radarState.AzimuthHalfWidth2, height))
    children.append(targetsComponent(width, height, createTargetOnRadarPolar))
    return children
  }

  return @() {
    watch = [ radarState.IsRadarVisible, radarState.RadarModeNameId,
              radarState.IsRadar2Visible, radarState.Radar2ModeNameId, radarState.HasDistanceScale]
    children = [
      {
        size = [width + hdpx(2), height + hdpx(2)]
        clipChildren = true
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = getChildren()
      },
      B_ScopeCircleMarkers(width, height)
    ]
  }
}

local B_ScopeHalfBackground = function(width, height) {
  local getChildren = function() {

    local angleLimStart = radarState.AzimuthMin.value - math.PI * 0.5
    local angleLimFinish = radarState.AzimuthMax.value - math.PI * 0.5
    local angleLimStartDeg = angleLimStart * rad2deg
    local angleLimFinishDeg = angleLimFinish * rad2deg

    local circle = {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      color = greenColorGrid
      fillColor = backgroundColor
      lineWidth = hdpx(1) * LINE_WIDTH
      opacity = 0.7
      commands = [
        [VECTOR_SECTOR, 50, 50, 50, 50, angleLimStartDeg, angleLimFinishDeg],
        [
          VECTOR_LINE, 50, 50,
          50 + math.cos(angleLimStart) * 50.0,
          50 + math.sin(angleLimStart) * 50.0
        ],
        [
          VECTOR_LINE, 50, 50,
          50 + math.cos(angleLimFinish) * 50.0,
          50 + math.sin(angleLimFinish) * 50.0
        ]
      ]
    }

    local scanAngleStart = radarState.ScanAzimuthMin.value - math.PI * 0.5
    local scanAngleFinish = radarState.ScanAzimuthMax.value - math.PI * 0.5
    local scanAngleStartDeg = scanAngleStart * rad2deg
    local scanAngleFinishDeg = scanAngleFinish * rad2deg

    local gridSecodaryCommands = []

    if (radarState.HasDistanceScale.value)
      gridSecodaryCommands = [
        [VECTOR_SECTOR, 50, 50, 12.5, 12.5, scanAngleStartDeg, scanAngleFinishDeg],
        [VECTOR_SECTOR, 50, 50, 25.0, 25.0, scanAngleStartDeg, scanAngleFinishDeg],
        [VECTOR_SECTOR, 50, 50, 37.5, 37.5, scanAngleStartDeg, scanAngleFinishDeg],
      ]

    const angleGrad = 15.0
    local angle = math.PI * angleGrad / 180.0
    local dashCount = 360.0 / angleGrad
    for(local i = 0; i < dashCount; ++i)
    {
      local currAngle = i * angle
      if (currAngle < scanAngleStart + 2 * math.PI || currAngle > scanAngleFinish + 2 * math.PI)
        continue

      gridSecodaryCommands.append([
        VECTOR_LINE, 50, 50,
        50 + math.cos(currAngle) * 50.0,
        50 + math.sin(currAngle) * 50.0
      ])
    }

    local gridSecondary = {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1)
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      size = [width, height]
      opacity = 0.42
      commands = gridSecodaryCommands
    }

    local gridMain = {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      color = greenColorGrid
      lineWidth = hdpx(2) * LINE_WIDTH
      opacity = 0.7
      commands = [
        [
          VECTOR_LINE, 50, 50,
          50 + math.cos(scanAngleStart) * 50.0,
          50 + math.sin(scanAngleStart) * 50.0
        ],
        [
          VECTOR_LINE, 50, 50,
          50 + math.cos(scanAngleFinish) * 50.0,
          50 + math.sin(scanAngleFinish) * 50.0
        ]
      ]
    }

    return [
      circle
      gridSecondary
      gridMain
    ]
  }

  return @() {
    watch = [radarState.AzimuthMin, radarState.AzimuthMax, radarState.ScanAzimuthMin, radarState.ScanAzimuthMax]
    children = getChildren()
  }
}

local B_ScopeHalfCircleMarkers = function(radarWidth, radarHeight)
{
  local offsetScaleFactor = 1.3
  return {
    size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarHeight]
    children = [
      {
        size = [0, SIZE_TO_CONTENT]
        children = @() style.lineForeground.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = radarState.MfdRadarEnabled.value ? [ radarWidth * 0.3, radarHeight * 0.75] :
          [
            radarWidth * 0.5 * (1.0 - math.sin(radarState.AzimuthMax.value)) + hdpx(4),
            radarHeight * 0.5 * (1.0 - math.cos(radarState.AzimuthMax.value)) - hdpx(4)
          ]
          hplace = ALIGN_RIGHT
          watch = [ radarState.HasAzimuthScale, radarState.ScanAzimuthMin, radarState.ScanAzimuthMax,
                    radarState.ScanElevationMin, radarState.ScanElevationMax, radarState.ScanPatternsMax ]
          text = radarState.HasAzimuthScale.value && radarState.ScanAzimuthMax.value > radarState.ScanAzimuthMin.value ?
            math.floor((radarState.ScanAzimuthMax.value - radarState.ScanAzimuthMin.value) * radToDeg + 0.5) + ::loc("measureUnits/deg") + "x" +
            math.floor((radarState.ScanElevationMax.value - radarState.ScanElevationMin.value) * radToDeg + 0.5) + ::loc("measureUnits/deg") +
            (radarState.ScanPatternsMax.value > 1 ? "*" : " ") : ""
        })
      }
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = radarState.MfdRadarEnabled.value ? [ radarWidth * 0.3, radarHeight * 0.75] :
        [
          radarWidth * 0.5 * (1.0 + math.sin(radarState.AzimuthMax.value)) + hdpx(4),
          radarWidth * 0.5 * (1.0 - math.cos(radarState.AzimuthMax.value)) - hdpx(4)
        ]
        watch = [ radarState.HasDistanceScale, radarState.DistanceMax, radarState.DistanceScalesMax ]
        text = radarState.HasDistanceScale.value ?
          ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(radarState.DistanceMax.value * 1000.0) +
          (radarState.DistanceScalesMax.value > 1 ? "*" : " ") : ""
        fontScale = getFontScale()
      })
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * (0.5 - 0.15), radarState.MfdRadarEnabled.value ? 0 : -hdpx(20)]
        text = makeRadarModeText()
      })
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * (0.5 + 0.05), radarState.MfdRadarEnabled.value ? 0 : -hdpx(20)]
        text = makeRadar2ModeText()
      })
      noiseSignal(
        [radarWidth * 0.06, radarHeight * 0.06],
        [radarWidth * (0.5 - 0.30), -hdpx(25)],
        [radarWidth * (0.5 + 0.20), -hdpx(25)])
    ]
  }
}

local B_ScopeHalf = function(width, height, pos) {
  local getChildren = function() {
    local children = [
      B_ScopeHalfBackground(width, height),
      B_ScopeSectorComponent(width, null, radarState.TargetRadarDist, radarState.TargetRadarAzimuthWidth, height, targetSectorColor),
      {
        size = [width, height]
        rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
        isSquare = false
        xFragments = 20
        yFragments = 8
        color = greenColor
      }
    ]
    if (radarState.IsRadarVisible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth, radarState.Distance, radarState.AzimuthHalfWidth, height))
    if (radarState.IsRadar2Visible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth2, radarState.Distance2, radarState.AzimuthHalfWidth2, height))
    if (radarState.IsAamLaunchZoneVisible.value && radarState.HasDistanceScale.value)
      children.append(B_ScopeHalfLaunchRangeComponent(width, height, radarState.AzimuthMin, radarState.AzimuthMax,
                                                      radarState.AamLaunchZoneDistMin, radarState.AamLaunchZoneDistMax))
    children.append(targetsComponent(width, height, createTargetOnRadarPolar))
    return children
  }

  return @() {
    watch = [ radarState.IsRadarVisible, radarState.RadarModeNameId,
              radarState.IsRadar2Visible, radarState.Radar2ModeNameId, radarState.IsAamLaunchZoneVisible]
    children = [
      {
        size = [width + hdpx(2), 0.5 * height]
        pos = [0, pos]
        halign = ALIGN_CENTER
        clipChildren = true
        children = getChildren()
      },
      B_ScopeHalfCircleMarkers(width, height)
    ]
  }
}

local C_ScopeSquareBackground = function(width, height) {

  local getChildren = function()
  {

    local back = {
      rendObj = ROBJ_SOLID
      size = [width, height]
      color = backgroundColor
    }

    local frame = {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      color = greenColorGrid
      fillColor = backgroundColor
      commands = [
        [VECTOR_LINE, 0, 0, 0, 100],
        [VECTOR_LINE, 0, 100, 100, 100],
        [VECTOR_LINE, 100, 100, 100, 0],
        [VECTOR_LINE, 100, 0, 0, 0]
      ]
    }

    local azimuthRangeInv   = 1.0 / getAzimuthRange();
    local elevationRangeInv = 1.0 / getElevationRange();

    local offset = 100 * (0.5 - (0.0 - radarState.ElevationMin.value) * elevationRangeInv)

    local crosshair = {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(3)
      color = greenColorGrid
      size = [width, height]
      opacity = 0.62
      commands = [
        [VECTOR_LINE, 50, 0, 50, 100],
        [VECTOR_LINE, 0, 50 + offset, 100, 50 + offset],
      ]
    }

    local scanAzimuthMinRel = radarState.ScanAzimuthMin.value * azimuthRangeInv
    local scanAzimuthMaxRel = radarState.ScanAzimuthMax.value * azimuthRangeInv
    local scanElevationMinRel = (radarState.ScanElevationMin.value - radarState.ElevationHalfWidth.value) * elevationRangeInv
    local scanElevationMaxRel = (radarState.ScanElevationMax.value + radarState.ElevationHalfWidth.value) * elevationRangeInv

    local gridMain = {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      lineWidth = hdpx(2) * LINE_WIDTH
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

    local azimuthRelStep = math.PI / 12.0 * azimuthRangeInv
    local azimuthRel = 0.0
    while (azimuthRel > radarState.ScanAzimuthMin.value * azimuthRangeInv)
    {
      gridSecondaryCommands.append([
        VECTOR_LINE,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMaxRel * 100) + offset,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMinRel * 100) + offset
      ])
      azimuthRel -= azimuthRelStep
    }
    azimuthRel = 0.0
    while (azimuthRel < radarState.ScanAzimuthMax.value * azimuthRangeInv)
    {
      gridSecondaryCommands.append([
        VECTOR_LINE,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMaxRel * 100) + offset,
        50 + azimuthRel * 100, 100 - (50 + scanElevationMinRel * 100) + offset
      ])
      azimuthRel += azimuthRelStep
    }

    local elevationRelStep = math.PI / 12.0 * elevationRangeInv
    local elevationRel = 0.0
    while (elevationRel > radarState.ScanElevationMin.value * elevationRangeInv)
    {
      gridSecondaryCommands.append([
        VECTOR_LINE,
        50 + scanAzimuthMinRel * 100, 100 - (50 + elevationRel * 100) + offset,
        50 + scanAzimuthMaxRel * 100, 100 - (50 + elevationRel * 100) + offset
      ])
      elevationRel -= elevationRelStep
    }
    elevationRel = 0.0
    while (elevationRel < radarState.ScanElevationMax.value * elevationRangeInv)
    {
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
      lineWidth = hdpx(1)
      opacity = 0.42
      commands = gridSecondaryCommands
    }

    return [back, frame, crosshair, gridMain, gridSecondary]
  }

  return @() style.lineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = getChildren()
    watch = [radarState.ScanAzimuthMin, radarState.ScanAzimuthMax, radarState.ScanElevationMin, radarState.ScanElevationMax]
  })
}

local C_ScopeSquareAzimuthComponent = function(width, height, azimuthWatched, elevatonWatched, halfAzimuthWidthWatched, halfElevationWidthWatched)
{
  local getChildren = function() {
    local halfAzimuthWidth   = 100.0 * (getAzimuthRange() > 0 ? halfAzimuthWidthWatched.value / getAzimuthRange() : 0)
    local halfElevationWidth = 100.0 * (getElevationRange() > 0 ? halfElevationWidthWatched.value / getElevationRange() : 0)

    return {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1)
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
  }

  return @() style.lineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = getChildren()
    watch = [azimuthWatched, elevatonWatched, halfAzimuthWidthWatched, halfElevationWidthWatched]
    transform = {
      translate = [azimuthWatched.value * width, (1.0 - elevatonWatched.value) * height]
    }
  })
}

local function createTargetOnRadarCScopeSquare(index, radius, radarWidth, radarHeight)
{
  local target = radarState.targets[index]
  local opacity = (1.0 - target.ageRel) * target.signalRel

  local azimuthRel = radarState.HasAzimuthScale.value ? target.azimuthRel : 0.0
  local azimuthWidthRel = target.azimuthWidthRel
  local azimuthLeft = azimuthRel - azimuthWidthRel * 0.5

  local elevationRel = target.elevationRel
  local elevationWidthRel = target.elevationWidthRel
  local elevationLowerRel = elevationRel - elevationWidthRel * 0.5

  local selectionFrame = null

  if (!target.isDetected)
  {
    local inSelectedTargetRangeGate = false
    foreach(secondTargetId, secondTarget in radarState.targets)
    {
      if (secondTarget != null &&
          secondTargetId != index && secondTarget.isDetected &&
          math.fabs(target.distanceRel - secondTarget.distanceRel) < 0.05)
      {
        inSelectedTargetRangeGate = true
        break
      }
    }
    if (!inSelectedTargetRangeGate)
      opacity = 0
  }

  if (target.isSelected || target.isDetected || !target.isEnemy)
  {
    local frameCommands = []

    local angularGateWidthMult = 4

    local azimuthGateWidthRel = angularGateWidthMult * 2.0 * max(radarState.AzimuthHalfWidth.value, angularGateBeamWidthMin) / getAzimuthRange()
    local azimuthGateLeftRel = azimuthRel - 0.5 * azimuthGateWidthRel
    local azimuthGateRightRel = azimuthRel + 0.5 * azimuthGateWidthRel

    local elevationGateWidthRel = angularGateWidthMult * 2.0 * max(radarState.ElevationHalfWidth.value, angularGateBeamWidthMin) / getElevationRange()
    local elevationGateLowerRel = elevationRel - 0.5 * elevationGateWidthRel
    local elevationGateUpperRel = elevationRel + 0.5 * elevationGateWidthRel

    if (target.isDetected || target.isSelected)
    {
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
    if (target.isSelected)
    {
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
    if (!target.isEnemy)
    {
    }

    selectionFrame = target.isSelected
    ? @() style.lineForeground.__merge({
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
    : style.lineForeground.__merge({
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

local C_ScopeSquareMarkers = function(radarWidth, radarHeight)
{
  local offsetScaleFactor = 1.3
  local elevationZeroHeightRel = (0.0 - radarState.ElevationMin.value) / getElevationRange()
  return {
    size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarHeight]
    children = [
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), hdpx(4)]
        watch = radarState.ElevationMax
        text = math.floor(radarState.ElevationMax.value * radToDeg + 0.5) + ::loc("measureUnits/deg")
      })
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), (1.0 - elevationZeroHeightRel) * radarHeight - hdpx(4)]
        watch = radarState.ElevationMin
        text = "0" + ::loc("measureUnits/deg")
      })
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), radarHeight - hdpx(20)]
        watch = radarState.ElevationMin
        text = math.floor(radarState.ElevationMin.value * radToDeg + 0.5) + ::loc("measureUnits/deg")
      })
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [hdpx(4), hdpx(4)]
        watch = radarState.AzimuthMin
        text = math.floor(radarState.AzimuthMin.value * radToDeg + 0.5) + ::loc("measureUnits/deg")
      })
      {
        size = [radarWidth, SIZE_TO_CONTENT]
        children = @() style.lineForeground.__merge({
          rendObj = ROBJ_DTEXT
          pos = [-hdpx(4), hdpx(4)]
          hplace = ALIGN_RIGHT
          watch = radarState.AzimuthMax
          text = math.floor(radarState.AzimuthMax.value * radToDeg + 0.5) + ::loc("measureUnits/deg")
        })
      }
    ]
  }
}

local C_Scope = function(width, height) {
  local getChildren = function() {
    local children = [C_ScopeSquareBackground(width, height)]

    if (radarState.IsRadarVisible.value)
      children.append(C_ScopeSquareAzimuthComponent(width, height, radarState.Azimuth, radarState.Elevation, radarState.AzimuthHalfWidth, radarState.ElevationHalfWidth))
    if (radarState.IsRadar2Visible.value)
      children.append(C_ScopeSquareAzimuthComponent(width, height, radarState.Azimuth2, radarState.Elevation2, radarState.AzimuthHalfWidth2, radarState.ElevationHalfWidth2))
    children.append(targetsComponent(width, height, createTargetOnRadarCScopeSquare))
    return children
  }

  return @() {
    watch = [radarState.IsRadarVisible, radarState.IsRadar2Visible]
    children = [
      {
        size = SIZE_TO_CONTENT
        clipChildren = true
        children = getChildren()
      }
      C_ScopeSquareMarkers(width, height)
    ]
  }
}

local function createTargetOnScreen(id, width) {
  local function radarTgtsSpd(){
    local spd = radarState.screenTargets?[id]?.speed
    return {
      text = (spd != null) ? ("Vr " + ::cross_call.measureTypes.CLIMBSPEED.getMeasureUnitsText(spd)) : ""
      opacity = radarState.selectedTargetSpeedBlinking ? (math.round(radarState.currentTime * 4) % 2 == 0 ? 1.0 : 0.42) : 1.0
    }
  }

  local function radarTgtsDist(){
    local dist = radarState.screenTargets?[id]?.dist
    return {text = (dist != null) ? ("D " + ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(dist)) : ""}
  }

  return @() {
    size = [width, width]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      local tgt = radarState.screenTargets?[id]
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
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = [width * 4, SIZE_TO_CONTENT]
        behavior = Behaviors.RtPropUpdate
        pos = [width + hdpx(5), 0]
        fontScale = getFontScale() * 1.4
        fontFxFactor = 8
        update = radarTgtsDist
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = [width * 4, SIZE_TO_CONTENT]
        behavior = Behaviors.RtPropUpdate
        pos = [width + hdpx(5), hdpx(35) * getFontScale()]
        fontScale = getFontScale() * 1.2
        fontFxFactor = 8
        update = radarTgtsSpd
      })
    ]
  }
}


local forestallRadius = hdpx(15)
local targetOnScreenWidth = hdpx(50)

local targetsOnScreenComponent = function() {
  local targetSize = radarState.MfdIlsEnabled.value ? radarHdpx(100) : targetOnScreenWidth
  local getTargets = function() {
    if (!radarState.HasAzimuthScale.value)
      return null
    else if (!radarState.screenTargets)
      return null

    local targets = []
    foreach (id, target in radarState.screenTargets)
    {
      if (!target)
        continue
      targets.append(createTargetOnScreen(id, targetSize))
    }
    return targets
  }

  return @(){
    size = [radarSw(100), radarSh(50)]
    children = getTargets()
    watch = [ radarState.ScreenTargetsTrigger, radarState.HasAzimuthScale ]
  }
}


local forestallComponent = function() {
  local widthMul = radarState.MfdIlsEnabled.value ? 3 : 1
  local getChildren = function() {
    return radarState.IsForestallVisible.value ?
      @() {
          rendObj = ROBJ_VECTOR_CANVAS
          size = [2 * forestallRadius * widthMul, 2 * forestallRadius * widthMul]
          lineWidth = radarHdpx(2) * LINE_WIDTH * widthMul
          color = greenColor
          fillColor = Color(0, 0, 0, 0)
          commands = [
            [VECTOR_ELLIPSE, 50, 50, 50, 50]
          ]
          behavior = Behaviors.RtPropUpdate
          update = @() {
            opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : 1.0
            transform = {
              translate = [radarState.forestall.x - forestallRadius * widthMul, radarState.forestall.y - forestallRadius * widthMul]
            }
          }
        }
      : null
  }

  return @(){
    size = [sw(100), sh(100)]
    children = getChildren()
    watch = radarState.IsForestallVisible
  }
}

local function getLockZoneOpacity() {
  return math.round(radarState.currentTime * 8) % 2 == 0 ? 100 : 0
}

local function lockZoneComponent() {
  local width = radarSw(100)
  local height = radarSh(100)

  local function radarLockDistRange() {
    local distMin = radarState.LockDistMin.value
    local distMax = radarState.LockDistMax.value
    return (distMin != null && distMax != null) ?
      ( "D:" +
        ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(distMin) + "-" +
        ::cross_call.measureTypes.DISTANCE.getMeasureUnitsText(distMax)) : ""
  }

  local function getCommands() {
    local x0 = (radarState.lockZone.x0 + radarState.lockZone.x1 + radarState.lockZone.x2 + radarState.lockZone.x3) * 0.25
    local y0 = (radarState.lockZone.y0 + radarState.lockZone.y1 + radarState.lockZone.y2 + radarState.lockZone.y3) * 0.25
    local mw = 100 / width
    local mh = 100 / height
    return [
      [ VECTOR_LINE,
        (radarState.lockZone.x0 - x0) * mw, (radarState.lockZone.y0 - y0) * mh,
        (radarState.lockZone.x1 - x0) * mw, (radarState.lockZone.y1 - y0) * mh],
      [ VECTOR_LINE,
        (radarState.lockZone.x1 - x0) * mw, (radarState.lockZone.y1 - y0) * mh,
        (radarState.lockZone.x2 - x0) * mw, (radarState.lockZone.y2 - y0) * mh],
      [ VECTOR_LINE,
        (radarState.lockZone.x2 - x0) * mw, (radarState.lockZone.y2 - y0) * mh,
        (radarState.lockZone.x3 - x0) * mw, (radarState.lockZone.y3 - y0) * mh],
      [ VECTOR_LINE,
        (radarState.lockZone.x3 - x0) * mw, (radarState.lockZone.y3 - y0) * mh,
        (radarState.lockZone.x0 - x0) * mw, (radarState.lockZone.y0 - y0) * mh]
    ]
  }

  local function getChildren() {
    return radarState.IsLockZoneVisible.value ?
      [
        @() {
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = hdpx(1) * 4.0
          color = greenColor
          fillColor = Color(0, 0, 0, 0)
          size = [width, height]
          commands = getCommands()
        },
        style.lineForeground.__merge({
          rendObj = ROBJ_DTEXT
          size = SIZE_TO_CONTENT
          pos = [ math.sqrt(math.pow(radarState.lockZone.x1 - radarState.lockZone.x0, 2) +
                            math.pow(radarState.lockZone.y1 - radarState.lockZone.y0, 2)) * 1.4 + hdpx(5), 0]
          fontScale = getFontScale() * 1.4
          fontFxFactor = 8
          text = radarLockDistRange()
        })
      ] : []
  }

  return @() {
    size = SIZE_TO_CONTENT
    watch = [ radarState.IsLockZoneVisible, radarState.LockZoneTrigger, radarState.LockDistMin, radarState.LockDistMax ]
    opacity = getLockZoneOpacity()
    transform = {
      translate = [
        (radarState.lockZone.x0 + radarState.lockZone.x1 + radarState.lockZone.x2 + radarState.lockZone.x3) * 0.25,
        (radarState.lockZone.y0 + radarState.lockZone.y1 + radarState.lockZone.y2 + radarState.lockZone.y3) * 0.25
      ]
    }
    children = getChildren()
  }
}

local getForestallTargetLineCoords = function(widthMul) {
  local p1 = {
    x = radarState.forestall.x
    y = radarState.forestall.y
  }
  local p2 = {
    x = radarState.selectedTarget.x
    y = radarState.selectedTarget.y
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
  local absDx = math.fabs(dx)
  local absDy = math.fabs(dy)

  if (absDy >= absDx)
  {
    resPoint2.x = p2.x
    resPoint2.y = p2.y + (dy > 0 ? 0.5 : -0.5) * radarHdpx(50)
  }
  else
  {
    resPoint2.y = p2.y
    resPoint2.x = p2.x + (dx > 0 ? 0.5 : -0.5) * radarHdpx(50)
  }

  local vecDx = p1.x - resPoint2.x
  local vecDy = p1.y - resPoint2.y
  local vecLength = math.sqrt(vecDx * vecDx + vecDy * vecDy)
  local vecNorm = {
    x = vecLength > 0 ? vecDx / vecLength : 0
    y = vecLength > 0 ? vecDy / vecLength : 0
  }

  resPoint1.x = resPoint2.x + vecNorm.x * (vecLength - forestallRadius * widthMul)
  resPoint1.y = resPoint2.y + vecNorm.y * (vecLength - forestallRadius * widthMul)

  return [resPoint2, resPoint1]
}


local forestallTargetLine = function() {
  local w = sw(100)
  local h = sh(100)
  local widthMul = radarState.MfdIlsEnabled.value ? 3 : 1

  local getChildren = function() {
    return radarState.IsForestallVisible.value
      ? @() {
          rendObj = ROBJ_VECTOR_CANVAS
          size = [w, h]
          lineWidth = hdpx(1) * LINE_WIDTH * widthMul
          color = greenColor
          opacity = 0.8
          behavior = Behaviors.RtPropUpdate
          update = function() {
            local resLine = getForestallTargetLineCoords(widthMul)

            return {
              opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : 1.0
              commands = [
                [VECTOR_LINE, resLine[0].x * 100.0 / w, resLine[0].y * 100.0 / h, resLine[1].x * 100.0 / w, resLine[1].y * 100.0 / h]
              ]
            }
          }
        }
      : null
  }

  return @(){
    size = [sw(100), sh(100)]
    children = getChildren()
    watch = radarState.IsForestallVisible
  }
}


local compassComponent = @() {
  size = SIZE_TO_CONTENT
  pos = [sw(50) - 0.5 * compassWidth, sh(12)]
  children = [
    compass(style.lineForeground, compassWidth, compassHeight, greenColor)
  ]
}


local createAzimuthMark = function(width, height, is_selected, is_detected, is_enemy) {
  local frame = null

  if (is_selected || is_detected || !is_enemy)
  {
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

    if (!is_enemy)
    {
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


local createAzimuthMarkWithOffset = function(id, width, height, total_width, angle, is_selected, is_detected, is_enemy, isSecondRound) {
  local offset = (isSecondRound ? total_width : 0) +
    total_width * angle / 360.0 + 0.5 * width

  local animTrigger = "fadeMarker" + id + (is_selected ? "_1" : "_0")

  if (!is_selected)
    ::anim_start(animTrigger)

  return @() {
    size = SIZE_TO_CONTENT
    pos = [offset, 0]
    children = createAzimuthMark(width, height, is_selected, is_detected, is_enemy)
    animations = [
      {
        trigger = animTrigger
        prop = AnimProp.opacity
        from = 1.0
        to = 0.0
        duration = targetLifeTime
      }
    ]
  }
}


local createAzimuthMarkStrike = function(total_width, height, markerWidth) {
  local getChildren = function() {
    if (!radarState.azimuthMarkers)
      return null

    local markers = []
    foreach(id, azimuthMarker in radarState.azimuthMarkers)
    {
      if (!azimuthMarker)
        continue

      markers.append(createAzimuthMarkWithOffset(id, markerWidth, height, total_width,
        azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.isEnemy, false))
      markers.append(createAzimuthMarkWithOffset(id, markerWidth, height, total_width,
        azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.isEnemy, true))
    }

    return markers
  }

  return @() {
    size = [total_width * 2.0, height]
    pos = [0, height * 0.5]
    watch = radarState.AzimuthMarkersTrigger
    children = getChildren()
  }
}


local createAzimuthMarkStrikeComponent = function(width, total_width, height) {

  local markerWidth = hdpx(20)

  local getOffset = @() 0.5 * (width - compassOneElementWidth)
    + compassState.CompassValue.value * compassOneElementWidth * 2.0 / compassStep
    - total_width

  return @() {
    size = [width, height * 2.0]
    clipChildren = true
    children = @() {
      children = createAzimuthMarkStrike(total_width, height, markerWidth)
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [getOffset(), 0]
        }
      }
    }
  }
}


local azimuthMarkStrike = function() {
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


local radar = function(posX, posY){
  return {
    pos = [posX, posY]
    size = SIZE_TO_CONTENT
    children = function(){
      local width = radarState.MfdRadarEnabled.value ? radarState.radarPosSize.w * 0.9 : sh(28)
      local height = radarState.MfdRadarEnabled.value ? radarState.radarPosSize.h * 0.9 : width
      local pos = radarState.MfdRadarEnabled.value ? radarState.radarPosSize.h * 0.2 : 0

      local scopeChild = null
      local cScope = null
      if (radarState.ViewMode.value == RadarViewMode.B_SCOPE_ROUND)
      {
        if (getAzimuthRange() > math.PI)
          scopeChild = B_Scope(width, height)
        else
          scopeChild = B_ScopeHalf(width, height, pos)
      }
      else if (radarState.ViewMode.value == RadarViewMode.B_SCOPE_SQUARE)
      {
        if (getAzimuthRange() > math.PI)
          scopeChild = B_Scope(width, height)
        else
          scopeChild = B_ScopeSquare(radarState.HasAzimuthScale.value ? width : 0.2 * width, height)
      }
      if (radarState.IsCScopeVisible.value && !hudState.isPlayingReplay.value && getAzimuthRange() <= math.PI)
      {
        local isSquare = radarState.ViewMode.value == RadarViewMode.B_SCOPE_SQUARE
        cScope = {
          pos = [0, isSquare ? width * 0.5 + hdpx(180) : height * 0.5 + hdpx(30)]
          children = C_Scope(width, height * 0.42)
        }
      }
      return {
        size = SIZE_TO_CONTENT
        watch = [radarState.ViewMode, radarState.AzimuthMax, radarState.AzimuthMin, radarState.IsCScopeVisible, radarState.HasAzimuthScale]
        children = [scopeChild, cScope]
      }
    }
  }
}

local radarMfdBackground = function()
{
  return {
    pos = [radarState.radarPosSize.x, radarState.radarPosSize.y]
    size = [radarState.radarPosSize.w, radarState.radarPosSize.h]
    rendObj = ROBJ_SOLID
    lineWidth = radarState.radarPosSize.h
    color = Color(0, 0, 0, 255)
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_LINE, 0, 50, 100, 50]
    ]
  }
}

local Root = function(for_mfd, radarPosX = sh(8), radarPosY = sh(32), radar_color = greenColor) {
  style.lineForeground = style.lineForeground.__merge({
    color = radar_color
  })
  greenColorGrid = radar_color
  greenColor = radar_color
  local getChildren = function() {
    if (!for_mfd && (radarState.MfdRadarEnabled.value || radarState.MfdIlsEnabled.value))
      return null
    local radarMfd = radarState.MfdRadarEnabled.value ?
          radar(radarState.radarPosSize.x + radarState.radarPosSize.w * 0.05, radarState.radarPosSize.y + radarState.radarPosSize.h * 0.05) : null
    return radarState.IsRadarHudVisible.value ?
      ((radarState.MfdRadarEnabled.value || radarState.MfdIlsEnabled.value) ?
       [
         targetsOnScreenComponent()
         forestallComponent()
         forestallTargetLine()
         radarMfdBackground()
         radarMfd
       ] :
       [
        targetsOnScreenComponent()
        forestallComponent()
        forestallTargetLine()
        radar(screenState.safeAreaSizeHud.value.borders[1] + radarPosX, radarPosY)
        lockZoneComponent()
        compassComponent
        azimuthMarkStrike
      ])
      : null
  }

  return @(){
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    watch = [radarState.IsRadarHudVisible, radarState.MfdRadarEnabled, radarState.MfdIlsEnabled]
    children = getChildren()
  }
}


return {
  radar = Root
  state = radarState
}