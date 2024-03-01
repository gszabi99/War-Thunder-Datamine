from "%rGui/globals/ui_library.nut" import *

let interopGen = require("interopGen.nut")

let { interop } = require("%rGui/globals/interop.nut")
let { isEqual } = require("%sqstd/underscore.nut")

let modeNames = [
  "hud/standby",
  "hud/search",
  "hud/acquisition",
  "hud/ACM",
  "hud/HMD",
  "hud/BST",
  "hud/VSL",
  "hud/track",

  "hud/PD VS standby",
  "hud/PD VS search",
  "hud/PD VS acquisition",
  "hud/PD VS ACM",
  "hud/PD VS BST",
  "hud/PD VS VSL",

  "hud/PD HDN VS standby",
  "hud/PD HDN VS search",
  "hud/PD HDN VS acquisition",
  "hud/PD HDN VS ACM",
  "hud/PD HDN VS BST",
  "hud/PD HDN VS VSL",

  "hud/PD standby",
  "hud/PD search",
  "hud/PD acquisition",
  "hud/PD ACM",
  "hud/PD HMD",
  "hud/PD BST",
  "hud/PD VSL",
  "hud/PD track",

  "hud/PD HDN standby",
  "hud/PD HDN search",
  "hud/PD HDN acquisition",
  "hud/PD HDN ACM",
  "hud/PD HDN BST",
  "hud/PD HDN VSL",
  "hud/PD HDN track",

  "hud/GTM standby",
  "hud/GTM search",
  "hud/GTM acquisition",
  "hud/GTM ACM",
  "hud/GTM BST",
  "hud/GTM VSL",
  "hud/GTM track",


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

  "hud/TWS standby",
  "hud/TWS search",
  "hud/TWS acquisition",
  "hud/TWS ACM",
  "hud/TWS BST",
  "hud/TWS VSL",
  "hud/TWS track",

  "hud/TWS HDN standby",
  "hud/TWS HDN search",
  "hud/TWS HDN acquisition",
  "hud/TWS HDN ACM",
  "hud/TWS HDN BST",
  "hud/TWS HDN VSL",
  "hud/TWS HDN track",

  "hud/TWS GTM standby",
  "hud/TWS GTM search",
  "hud/TWS GTM acquisition",
  "hud/TWS GTM ACM",
  "hud/TWS GTM BST",
  "hud/TWS GTM VSL",
  "hud/TWS GTM track",

  "hud/IRST standby",
  "hud/IRST search",
  "hud/IRST acquisition",
  "hud/IRST ACM",
  "hud/IRST HMD",
  "hud/IRST track",

  "hud/air_search",
  "hud/ground_search",

  "hud/auto acquisition",
  "hud/auto ACM",
  "hud/auto HMD",
  "hud/track memory",
]

let radarState = {
  targetAspectEnabled = Watched(false)
  currentTime = Watched(0.0)
  SelectedTargetBlinking = Watched(false)
  SelectedTargetSpeedBlinking = Watched(false)
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
let MfdRadarHideBkg = Watched(false)
let MfdRadarFontScale = Watched(-1)

let Speed = Watched(0.0)

  //radar 1
let IsRadarVisible = Watched(false)
let IsRadarEmitting = Watched(false)
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
let IsRadar2Emitting = Watched(false)
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
let ScanZoneWatched = Watched({ x0 = 0, x1 = 0, x2 = 0, x3 = 0, y0 = 0, y1 = 0, y2 = 0, y3 = 0 })
let LockZoneWatched = Watched({ x0 = 0, y0 = 0, x1 = 0, y1 = 0, x2 = 0, y2 = 0, x3 = 0, y3 = 0 })
let IsScanZoneAzimuthVisible = Watched(false)
let IsScanZoneElevationVisible = Watched(false)
let IsLockZoneVisible = Watched(false)
let LockDistMin = Watched(0)
let LockDistMax = Watched(0)

let IsAamLaunchZoneVisible = Watched(false)
let AamLaunchZoneDist    = Watched(0.0)
let AamLaunchZoneDistMin = Watched(0.0)
let AamLaunchZoneDistMax = Watched(0.0)
let AamTimeOfFlightMax = Watched(0.0)
let AamLaunchZoneDistMinVal = Watched(1.0)
let AamLaunchZoneDistMaxVal = Watched(1.0)
let AamLaunchZoneDistDgftMin = Watched(0.0)
let AamLaunchZoneDistDgftMax = Watched(0.0)

let HmdSensorVisible = Watched(false)
let HmdSensorDesignation = Watched(false)

let AzimuthRange = Computed(@() max(0.0, AzimuthMax.value - AzimuthMin.value))
let AzimuthRangeInv = Computed(@() AzimuthRange.value != 0 ? 1.0 / AzimuthRange.value : 1.0)
let ElevationRange = Computed(@() max(0.0, ElevationMax.value - ElevationMin.value))
let ElevationRangeInv = Computed(@() ElevationRange.value != 0 ? 1.0 / ElevationRange.value : 1.0)

let isCollapsedRadarInReplay = Watched(false)

radarState.__update({
    modeNames, IsRadarHudVisible, IsNoiseSignaVisible, MfdRadarEnabled, MfdIlsEnabled, MfdRadarColor, MfdRadarHideBkg,

    Speed,

    //radar 1
    IsRadarVisible, IsRadarEmitting, RadarModeNameId, Azimuth, Elevation, Distance, AzimuthHalfWidth, ElevationHalfWidth, DistanceGateWidthRel, NoiseSignal,

    //radar 2
    IsRadar2Visible, IsRadar2Emitting, Radar2ModeNameId, Azimuth2, Elevation2, Distance2, AzimuthHalfWidth2, ElevationHalfWidth2, NoiseSignal2,

    AimAzimuth, TurretAzimuth, TargetRadarAzimuthWidth, TargetRadarDist, CueAzimuthHalfWidthRel, CueDistWidthRel, AzimuthMin, AzimuthMax, ElevationMin, ElevationMax,

    IsBScopeVisible, IsCScopeVisible, ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax, CueVisible, CueAzimuth, CueDist,

    targets, TargetsTrigger, screenTargets, ScreenTargetsTrigger, ViewMode, MfdViewMode, HasAzimuthScale, HasDistanceScale, ScanPatternsMax,
    DistanceMax, DistanceMin, DistanceScalesMax, azimuthMarkers, AzimuthMarkersTrigger, Irst, RadarScale, MfdIlsHeight,

    IsForestallVisible, forestall, selectedTarget,

    UseLockZoneRotated, FoV, ScanZoneWatched, LockZoneWatched, IsScanZoneAzimuthVisible, IsScanZoneElevationVisible, IsLockZoneVisible,
    LockDistMin, LockDistMax, radarPosSize,

    IsAamLaunchZoneVisible, AamLaunchZoneDist, AamLaunchZoneDistMin, AamLaunchZoneDistMax, AamLaunchZoneDistDgftMin, AamLaunchZoneDistDgftMax,

    VelocitySearch

    AzimuthRange, AzimuthRangeInv, ElevationRange, ElevationRangeInv, AamTimeOfFlightMax, AamLaunchZoneDistMinVal, AamLaunchZoneDistMaxVal,

    HmdSensorVisible, HmdSensorDesignation, MfdRadarFontScale, isCollapsedRadarInReplay
  }
)

interop.updateCurrentTime <- function(curr_time) {
  radarState.currentTime(curr_time)
}

interop.clearTargets <- function() {
  local needUpdate = false
  for (local i = 0; i < targets.len(); ++i) {
    if (targets[i] != null) {
      targets[i] = null
      needUpdate = true
    }
  }

  if (needUpdate)
    TargetsTrigger.trigger()
}


interop.updateTarget <- function (index,
                                    azimuth_rel, elevation_rel, distance_rel,
                                    azimuth_width_rel, elevation_width_rel, distance_width_rel,
                                    los_hor_speed, los_ver_speed, los_speed,
                                    age_rel, is_selected, is_detected, is_enemy, signal_rel) {
  local needUpdate = false
  if (index >= targets.len()) {
    targets.resize(index + 1)
    needUpdate = true
  }

  let cvt = @(val, vmin, vmax, omin, omax) omin + ((omax - omin) * (val - vmin)) / (vmax - vmin)

  let signalRel = signal_rel < 0.01
    ? 0.0
    : cvt(signal_rel, 0.05, 1.0, 0.3, 1.0)
  let old_tgt = targets[index]
  targets[index] = {
    azimuthRel = azimuth_rel
    azimuthWidthRel = max(azimuth_width_rel, 0.02)
    elevationRel = elevation_rel
    elevationWidthRel = max(elevation_width_rel, 0.02)
    distanceRel = distance_rel
    distanceWidthRel = max(distance_width_rel, 0.05)
    losHorSpeed = los_hor_speed
    losVerSpeed = los_ver_speed
    losSpeed = los_speed
    ageRel = age_rel
    isSelected = is_selected
    isDetected = is_detected
    isEnemy = is_enemy
    signalRel = signalRel
  }
  needUpdate = needUpdate || !isEqual(old_tgt, targets[index])

  if (needUpdate)
    TargetsTrigger.trigger()
}

const targetLifeTime = 5.0

interop.updateScreenTarget <- function(id, x, y, dist, los_hor_speed, los_ver_speed, los_speed, rad_speed, is_detected, is_tracked) {
  local needUpdate = false
  if (!screenTargets) {
    screenTargets = {}
    needUpdate = true
  }

  radarState.targetAspectEnabled(true)
  if (!screenTargets?[id]) {
    needUpdate = true
    screenTargets[id] <- {
      x = x
      y = y
      dist = dist
      losHorSpeed = los_hor_speed
      losVerSpeed = los_ver_speed
      losSpeed = los_speed
      radSpeed = rad_speed
      isDetected = is_detected
      isTracked = is_tracked
      isUpdated = true
    }
  }
  else {
    let screenTarget = screenTargets[id]
    let new_tgt = screenTarget.__merge({ x, y, dist,
      losHorSpeed = los_hor_speed
      losVerSpeed = los_ver_speed
      losSpeed = los_speed
      radSpeed = rad_speed
      isDetected = is_detected
      isTracked = is_tracked
      isUpdated = true
    })
    needUpdate = needUpdate || !isEqual(screenTarget, new_tgt)
    screenTarget.__update(new_tgt)
  }
  if (needUpdate)
    ScreenTargetsTrigger.trigger()
}

interop.updateAzimuthMarker <- function(id, target_time, age, azimuth_world_deg, is_selected, is_detected, is_enemy) {
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
    let marker = azimuthMarkers[id]
    marker.azimuthWorldDeg = azimuth_world_deg
    marker.isSelected = is_selected
    marker.targetTime = target_time
    marker.age = age
    marker.isDetected = is_detected
    marker.isEnemy = is_enemy
    marker.isUpdated = true
  }
  else
    return

  AzimuthMarkersTrigger.trigger()
}


interop.resetTargetsFlags <- function() {
  foreach (target in screenTargets)
    if (target)
      target.isUpdated = false

  foreach (marker in azimuthMarkers)
    if (marker)
      marker.isUpdated = false
}


interop.clearUnusedTargets <- function() {
  local needUpdate = false
  foreach (id, target in screenTargets)
    if (target && !target.isUpdated) {
      screenTargets[id] = null
      needUpdate = true
    }
  if (needUpdate)
    ScreenTargetsTrigger.trigger()

  needUpdate = false
  foreach (id, marker in azimuthMarkers)
    if (marker && !marker.isUpdated && radarState.currentTime.value > marker.targetTime + targetLifeTime) {
      azimuthMarkers[id] = null
      needUpdate = true
    }
  if (needUpdate)
    AzimuthMarkersTrigger.trigger()
}


interop.updateForestall <- function(x, y) {
  forestall.x = x
  forestall.y = y
}


interop.updateSelectedTarget <- function(x, y) {
  selectedTarget.x = x
  selectedTarget.y = y
}

interop.updateScanZone <- function(x0, y0, x1, y1, x2, y2, x3, y3) {
  let curVal = ScanZoneWatched.value
  if (curVal.x0 != x0 || curVal.y0 != y0 || curVal.x1 != x1 || curVal.y1 != y1
    || curVal.x2 != x2 || curVal.y2 != y2 || curVal.x3 != x3 || curVal.y3 != y3) {
    ScanZoneWatched({ x0, y0, x1, y1, x2, y2, x3, y3 })
  }
}

interop.updateLockZone <- function(x0, y0, x1, y1, x2, y2, x3, y3) {
  let curVal = LockZoneWatched.value
  if (curVal.x0 != x0 || curVal.y0 != y0 || curVal.x1 != x1 || curVal.y1 != y1
    || curVal.x2 != x2 || curVal.y2 != y2 || curVal.x3 != x3 || curVal.y3 != y3) {
    LockZoneWatched({ x0, x1, x2, x3, y0, y1, y2, y3 })
  }
}


interop.updateRadarPosSize <- function(x, y, w, h) {
  let curVal = radarPosSize.value
  if (curVal.x != x || curVal.y != y || curVal.w != w || curVal.h != h)
    radarPosSize({ x, y, w, h })
}

interopGen({
  stateTable = radarState
  prefix = "radar"
  postfix = "Update"
})

return radarState