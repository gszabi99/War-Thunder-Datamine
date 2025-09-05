from "%rGui/globals/ui_library.nut" import *
let { paramsTable, turretAngles, launchDistanceMax, sight, rangeFinder, lockSight, targetSize } = require("%rGui/airHudElems.nut")
let { IsMfdSightHudVisible, MfdSightMask, MfdSightPosSize, MfdFontScale, SecondaryMask, HudParamColor } = require("%rGui/airState.nut")
let { ceil } = require("%sqstd/math.nut")

let sightSh = @(h) ceil(h * MfdSightPosSize.get()[3] / 100)
let sightSw = @(w) ceil(w * MfdSightPosSize.get()[2] / 100)
let sightHdpx = @(px) ceil(px * MfdSightPosSize.get()[3] / 1024)

let mfdSightParamTablePos = Watched([hdpx(30), hdpx(175)])

let mfdSightParamsTable = paramsTable(MfdSightMask, SecondaryMask,
  hdpx(250), hdpx(28),
  mfdSightParamTablePos,
  hdpx(3),
  true,
  false,
  false,
  MfdFontScale.get() > 0 ? MfdFontScale.get() * 21 : 21)

function mfdSightHud() {
  return {
    watch = [IsMfdSightHudVisible, MfdFontScale]
    children = IsMfdSightHudVisible.get() ?
    [
      turretAngles(HudParamColor, sightSw(15), sightHdpx(150), sightSw(50), sightSh(90))
      launchDistanceMax(HudParamColor, sightSw(15), sightHdpx(150), sightSw(50), sightSh(90))
      sight(HudParamColor, sightSw(50), sightSh(50), sightHdpx(500))
      rangeFinder(HudParamColor, sightSw(50), sightSh(58))
      lockSight(HudParamColor, sightHdpx(150), sightHdpx(100), sightSw(50), sightSh(50))
      targetSize(HudParamColor, sightSw(100), sightSh(100))
      mfdSightParamsTable(HudParamColor)
    ]
    : null
  }
}

return mfdSightHud