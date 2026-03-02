from "%rGui/globals/ui_library.nut" import *
let { RadarModeNameId, ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax } = require("%rGui/radarState.nut")
let { resetRadarZoom } = require("radarGuiControls")
let { abs } = require("math")

let triggerDelta = 0.05

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
