from "%rGui/globals/ui_library.nut" import *

let { bw } = require("%rGui/style/screenState.nut")
let { turretAngles, sight, paramsTable, targetSize, launchDistanceMax } = require("%rGui/airHudElems.nut")
let { TargetPodMask, EmptyMask, HudColor, HudParamColor } = require("%rGui/airState.nut")
let missileSalvoTimer = require("%rGui/missileSalvoTimer.nut")

let paramsTableWidthAircraft = hdpx(330)
let paramsTableHeightAircraft = hdpx(22)
let aircraftParamsTablePos = Computed(@() [max(bw.get(), sw(50) - hdpx(500)), sh(50) - hdpx(100)])

let aircraftParamsTable = paramsTable(TargetPodMask, EmptyMask,
        paramsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftParamsTablePos,
        hdpx(1), true, false, true)

function Root(width, height) {
  return {
    size = [width, height]
    children = [
      missileSalvoTimer(HudColor, sw(50) - hdpx(150), sh(90) - hdpx(174))
      turretAngles(HudColor, hdpx(150), hdpx(150), sw(50), sh(90), 0.22)
      sight(HudColor, sw(50), sh(50), hdpx(500))
      targetSize(HudColor, sw(100), sh(100))
      launchDistanceMax(HudColor, hdpx(150), hdpx(150), sw(50), sh(90))
      aircraftParamsTable(HudParamColor, false)
    ]
  }
}

return Root