local { bw } = require("style/screenState.nut")
local { turretAngles, sight, paramsTable, targetSize, launchDistanceMax } = require("airHudElems.nut")
local { TargetPodMask, EmptyMask, TargetPodHudColor  } = require("airState.nut")

local paramsTableWidthAircraft = hdpx(330)
local paramsTableHeightAircraft = hdpx(22)
local aircraftParamsTablePos = Computed(@() [max(bw.value, sw(50) - hdpx(500)), sh(50) - hdpx(100)])

local aircraftParamsTable = paramsTable(TargetPodMask, EmptyMask,
        paramsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftParamsTablePos,
        hdpx(1), true, false, true, true)

local function Root(width, height) {
  return {
    size = [width, height]
    children = [
      turretAngles(TargetPodHudColor, hdpx(150), hdpx(150), sw(50), sh(90), false, 0.22)
      sight(TargetPodHudColor, sw(50), sh(50), hdpx(500), false)
      targetSize(TargetPodHudColor, sw(100), sh(100))
      launchDistanceMax(TargetPodHudColor, hdpx(150), hdpx(150), sw(50), sh(90), false)
      aircraftParamsTable(false, true)
    ]
  }
}

return Root