local interopGen = require("interopGen.nut")

local modeNames =
[
  "hud/standby",
  "hud/search",
  "hud/acquisition",
  "hud/ACM",
  "hud/track",

  "hud/PD VS standby",
  "hud/PD VS search",
  "hud/PD VS acquisition",
  "hud/PD VS ACM",

  "hud/PD standby",
  "hud/PD search",
  "hud/PD acquisition",
  "hud/PD ACM",
  "hud/PD track",

  "hud/LD standby",
  "hud/LD search",
  "hud/LD acquisition",
  "hud/LD ACM",
  "hud/LD track",

  "hud/MTI standby",
  "hud/MTI search",
  "hud/MTI acquisition",
  "hud/MTI ACM",
  "hud/MTI track",

  "hud/IRST standby",
  "hud/IRST search",
  "hud/IRST acquisition",
  "hud/IRST ACM",
  "hud/IRST track",

  "hud/air_search",
  "hud/ground_search"
]

local radarState = {
  targetAspectEnabled = Watched(false)
  currentTime = Watched(0.0)
  selectedTargetBlinking = Watched(false)
  selectedTargetSpeedBlinking = Watched(false)
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

local IsBScopeVisible = Watched(false)
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
local DistanceMin = Watched(0)
local DistanceMax = Watched(0)
local DistanceScalesMax = Watched(0)
local VelocitySearch = Watched(false)
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

local AzimuthRange = Computed(@() ::max(0.0, AzimuthMax.value - AzimuthMin.value))
local AzimuthRangeInv = Computed(@() AzimuthRange.value != 0 ? 1.0 / AzimuthRange.value : 1.0)
local ElevationRange = Computed(@() ::max(0.0, ElevationMax.value - ElevationMin.value))
local ElevationRangeInv = Computed(@() ElevationRange.value != 0 ? 1.0 / ElevationRange.value : 1.0)


local IndicationForCollapsedRadar = Watched(false)

radarState.__update({
    modeNames, IsRadarHudVisible, IsNoiseSignaVisible, MfdRadarEnabled, MfdIlsEnabled, MfdRadarColor,

    Speed,

    //radar 1
    IsRadarVisible, RadarModeNameId, Azimuth, Elevation, Distance, AzimuthHalfWidth, ElevationHalfWidth, DistanceGateWidthRel, NoiseSignal,

    //radar 2
    IsRadar2Visible, Radar2ModeNameId, Azimuth2, Elevation2, Distance2, AzimuthHalfWidth2, ElevationHalfWidth2, NoiseSignal2,

    AimAzimuth, TurretAzimuth, TargetRadarAzimuthWidth, TargetRadarDist, AzimuthMin, AzimuthMax, ElevationMin, ElevationMax,

    IsBScopeVisible, IsCScopeVisible, ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax,

    targets, TargetsTrigger, screenTargets, ScreenTargetsTrigger, ViewMode, MfdViewMode, HasAzimuthScale, HasDistanceScale, ScanPatternsMax,
    DistanceMax, DistanceMin, DistanceScalesMax, azimuthMarkers, AzimuthMarkersTrigger, Irst, RadarScale, MfdIlsHeight,

    IsForestallVisible, forestall, selectedTarget,

    UseLockZoneRotated, FoV, ScanZoneWatched, LockZoneWatched, IsScanZoneAzimuthVisible, IsScanZoneElevationVisible, IsLockZoneVisible,
    LockDistMin, LockDistMax, radarPosSize,

    IsAamLaunchZoneVisible, AamLaunchZoneDist, AamLaunchZoneDistMin, AamLaunchZoneDistMax,

    IndicationForCollapsedRadar, VelocitySearch

    AzimuthRange, AzimuthRangeInv, ElevationRange, ElevationRangeInv
  }
)

::interop.updateCurrentTime <- function(curr_time) {
  radarState.currentTime(curr_time)
}


::interop.updateBlinking <- function(isTargetBlink, isSpeedBlink) {
  radarState.selectedTargetBlinking(isTargetBlink)
  radarState.selectedTargetSpeedBlinking(isSpeedBlink)
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

const targetLifeTime = 5.0

::interop.updateScreenTarget <- function(id, x, y, dist, speed) {
  if (!screenTargets)
    screenTargets = {}

  radarState.targetAspectEnabled(false)
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

  radarState.targetAspectEnabled(true)
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
    if (marker && !marker.isUpdated && radarState.currentTime.value > marker.targetTime + targetLifeTime) {
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

return radarState