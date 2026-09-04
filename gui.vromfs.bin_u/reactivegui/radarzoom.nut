from "%rGui/radarState.nut" import RadarModeNameId, ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax
from "radarGuiControls" import resetRadarZoom
from "math" import abs
from "%rGui/globals/ui_library.nut" import *

const triggerDelta = 0.05

local scanAzimuthRangeCached = 0.0
let scanAzimuthRange = keepref(Computed(@() ScanAzimuthMax.get() - ScanAzimuthMin.get()))
scanAzimuthRange.subscribe(function(v){
  if (abs(v - scanAzimuthRangeCached) > triggerDelta)
    resetRadarZoom()
  scanAzimuthRangeCached = v
})

local canElevationRangeCached = 0.0
let scanElevationRange = keepref(Computed(@() ScanElevationMax.get() - ScanElevationMin.get()))
scanElevationRange.subscribe(function(v){
  if (abs(v - canElevationRangeCached) > triggerDelta)
    resetRadarZoom()
  canElevationRangeCached = v
})


RadarModeNameId.subscribe(@(_) resetRadarZoom())
