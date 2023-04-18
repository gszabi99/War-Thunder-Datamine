from "%rGui/globals/ui_library.nut" import *

let { IndicatorsVisible, IsMfdSightHudVisible, MfdSightMask, MfdColor, MfdSightPosSize, MlwsLwsForMfd, RwrForMfd,
  IsMfdEnabled, RwrPosSize, SecondaryMask, HudParamColor } = require("airState.nut")
let { paramsTable, turretAngles, launchDistanceMax, sight, rangeFinder, lockSight, targetSize } = require("airHudElems.nut")
let tws = require("tws.nut")
let { mkRadarForMfd } = require("radarComponent.nut")

let { ceil } = require("%sqstd/math.nut")

const mfdFontScale = 1.5

let sightSh = @(h) ceil(h * MfdSightPosSize[3] / 100)
let sightSw = @(w) ceil(w * MfdSightPosSize[2] / 100)
let sightHdpx = @(px) ceil(px * MfdSightPosSize[3] / 1024)

let twsPosComputed = Computed(@() [RwrPosSize.value[0] + 0.17 * RwrPosSize.value[2],
  RwrPosSize.value[1] + 0.17 * RwrPosSize.value[3]])
let twsSizeComputed = Computed(@() [0.66 * RwrPosSize.value[2], 0.66 * RwrPosSize.value[3]])

let mkTws = @() {
  watch = [MlwsLwsForMfd, RwrForMfd]
  children = (!MlwsLwsForMfd.value && !RwrForMfd.value) ? null
    : tws({
      colorWatched = MfdColor
      posWatched = twsPosComputed,
      sizeWatched = twsSizeComputed,
      relativCircleSize = 36
    })
}

let mfdSightParamTablePos = Watched([hdpx(30), hdpx(175)])

let mfdSightParamsTable = paramsTable(MfdSightMask, SecondaryMask,
  hdpx(250), hdpx(28),
  mfdSightParamTablePos,
  hdpx(3))

let function mfdSightHud() {
  return {
    watch = IsMfdSightHudVisible
    pos = [MfdSightPosSize[0], MfdSightPosSize[1]]
    children = IsMfdSightHudVisible.value ?
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


let function Root() {
  let children = [
    mkTws
    mkRadarForMfd(MfdColor)
    mfdSightHud
  ]

  return {
    watch = [
      IndicatorsVisible
      IsMfdEnabled
    ]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = (IndicatorsVisible.value || IsMfdEnabled.value) ? children : null
  }
}


return Root