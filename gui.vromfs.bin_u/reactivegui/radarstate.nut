let interopGen = require("interopGen.nut")

let modeNames =
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

let radarState = {
  targetAspectEnabled = Watched(false)
  currentTime = Watched(0.0)
  selectedTargetBlinking = Watched(false)
  selectedTargetSpeedBlinking = Watched(false)
}

let targets = []
local screenTargets = {}
local azimuthMarkers = {}
let forestall = {
  x = 0.0
  y = 0.0
}
let selectedTarget = {
  x = 0.0
  y = 0.0
}

let radarPosSize = Watched({
  x = 0.0
  y = 0.0
  w = 0.0
  h = 0.0
})

let IsRadarHudVisible = Watched(false)
let IsNoiseSignaVisible = Watched(false)
let MfdRadarEnabled = Watched(false)
let MfdIlsEnabled = Watched(false)
let MfdRadarColor = Watched(Color(10, 202, 10, 250))

let Speed = Watched(0.0)

  //radar 1
let IsRadarVisible = Watched(false)
let RadarModeNameId = Watched(-1)
let Azimuth = Watched(0.0)
let Elevation = Watched(0.0)
let Distance = Watched(0.0)
let AzimuthHalfWidth = Watched(0.0)
let ElevationHalfWidth = Watched(0.0)
let DistanceGateWidthRel = Watched(0.0)
let NoiseSignal = Watched(0)

  //radar 2
let IsRadar2Visible = Watched(false)
let Radar2ModeNameId = Watched(-1)
let Azimuth2 = Watched(0.0)
let Elevation2 = Watched(0.0)
let Distance2 = Watched(0.0)
let AzimuthHalfWidth2 = Watched(0.0)
let ElevationHalfWidth2 = Watched(0.0)
let NoiseSignal2 = Watched(0)

let AimAzimuth = Watched(0.0)
let TurretAzimuth = Watched(0.0)
let TargetRadarAzimuthWidth = Watched(0.0)
let TargetRadarDist = Watched(0.0)
let CueAzimuthHalfWidthRel = Watched(0.0)
let CueDistWidthRel = Watched(0.0)
let AzimuthMin = Watched(0)
let AzimuthMax = Watched(0)
let ElevationMin = Watched(0)
let ElevationMax = Watched(0)

let IsBScopeVisible = Watched(false)
let IsCScopeVisible = Watched(false)
let ScanAzimuthMin = Watched(0)
let ScanAzimuthMax = Watched(0)
let ScanElevationMin = Watched(0)
let ScanElevationMax = Watched(0)

let CueVisible = Watched(false)
let CueAzimuth = Watched(0)
let CueDist = Watched(0)

let TargetsTrigger = Watched(0)
let ScreenTargetsTrigger = Watched(0)
let ViewMode = Watched(0)
let MfdViewMode = Watched(0)
let HasAzimuthScale = Watched(0)
let HasDistanceScale = Watched(0)
let ScanPatternsMax = Watched(0)
let DistanceMin = Watched(0)
let DistanceMax = Watched(0)
let DistanceScalesMax = Watched(0)
let VelocitySearch = Watched(false)
let AzimuthMarkersTrigger = Watched(0)
let Irst = Watched(false)
let RadarScale = Watched(1.0)

let MfdIlsHeight = Watched(0)

let IsForestallVisible = Watched(false)

let UseLockZoneRotated = Watched(false)
let FoV = Watched(0)
let ScanZoneWatched = Watched({x0=0,x1=0,x2=0,x3=0,y0=0,y1=0,y2=0,y3=0})
let LockZoneWatched = Watched({x0=0, y0=0, x1=0, y1=0, x2=0, y2=0, x3=0, y3=0})
let IsScanZoneAzimuthVisible = Watched(false)
let IsScanZoneElevationVisible = Watched(false)
let IsLockZoneVisible = Watched(false)
let LockDistMin = Watched(0)
let LockDistMax = Watched(0)

let IsAamLaunchZoneVisible = Watched(false)
let AamLaunchZoneDist    = Watched(0.0)
let AamLaunchZoneDistMin = Watched(0.0)
let AamLaunchZoneDistMax = Watched(0.0)

let AzimuthRange = Computed(@() ::max(0.0, AzimuthMax.value - AzimuthMin.value))
let AzimuthRangeInv = Computed(@() AzimuthRange.value != 0 ? 1.0 / AzimuthRange.value : 1.0)
let ElevationRange = Computed(@() ::max(0.0, ElevationMax.value - ElevationMin.value))
let ElevationRangeInv = Computed(@() ElevationRange.value != 0 ? 1.0 / ElevationRange.value : 1.0)


radarState.__update({
    modeNames, IsRadarHudVisible, IsNoiseSignaVisible, MfdRadarEnabled, MfdIlsEnabled, MfdRadarColor,

    Speed,

    //radar 1
    IsRadarVisible, RadarModeNameId, Azimuth, Elevation, Distance, AzimuthHalfWidth, ElevationHalfWidth, DistanceGateWidthRel, NoiseSignal,

    //radar 2
    IsRadar2Visible, Radar2ModeNameId, Azimuth2, Elevation2, Distance2, AzimuthHalfWidth2, ElevationHalfWidth2, NoiseSignal2,

    AimAzimuth, TurretAzimuth, TargetRadarAzimuthWidth, TargetRadarDist, CueAzimuthHalfWidthRel, CueDistWidthRel, AzimuthMin, AzimuthMax, ElevationMin, ElevationMax,

    IsBScopeVisible, IsCScopeVisible, ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax, CueVisible, CueAzimuth, CueDist,

    targets, TargetsTrigger, screenTargets, ScreenTargetsTrigger, ViewMode, MfdViewMode, HasAzimuthScale, HasDistanceScale, ScanPatternsMax,
    DistanceMax, DistanceMin, DistanceScalesMax, azimuthMarkers, AzimuthMarkersTrigger, Irst, RadarScale, MfdIlsHeight,

    IsForestallVisible, forestall, selectedTarget,

    UseLockZoneRotated, FoV, ScanZoneWatched, LockZoneWatched, IsScanZoneAzimuthVisible, IsScanZoneElevationVisible, IsLockZoneVisible,
    LockDistMin, LockDistMax, radarPosSize,

    IsAamLaunchZoneVisible, AamLaunchZoneDist, AamLaunchZoneDistMin, AamLaunchZoneDistMax,

    VelocitySearch

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

  let cvt = @(val, vmin, vmax, omin, omax) omin + ((omax - omin) * (val - vmin)) / (vmax - vmin)

  let signalRel = signal_rel < 0.05
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