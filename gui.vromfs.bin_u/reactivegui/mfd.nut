from "%rGui/globals/ui_library.nut" import *

let { IndicatorsVisible, MlwsLwsForMfd, RwrForMfd, IsMfdEnabled, RwrPosSize } = require("airState.nut")
let { tws } = require("tws.nut")
let mfdSightHud = require("planeMfdCamera.nut")
let { MfdRadarColor, radarPosSize } = require("radarState.nut")
let { radarMfd } = require("%rGui/radar.nut")
let mfdCustomPages = require("%rGui/planeCockpit/customPageBuilder.nut")
let { MfdRwrColor, DigitalDevicesVisible, DigDevicesPosSize } = require("planeState/planeToolsState.nut")
let digitalDevices = require("planeCockpit/digitalDevices.nut")


let twsPosComputed = Computed(@() [RwrPosSize.value[0] + 0.17 * RwrPosSize.value[2],
  RwrPosSize.value[1] + 0.17 * RwrPosSize.value[3]])
let twsSizeComputed = Computed(@() [0.66 * RwrPosSize.value[2], 0.66 * RwrPosSize.value[3]])

let mkTws = @() {
  watch = [MlwsLwsForMfd, RwrForMfd]
  children = (!MlwsLwsForMfd.value && !RwrForMfd.value) ? null
    : tws({
      colorWatched = MfdRwrColor
      posWatched = twsPosComputed,
      sizeWatched = twsSizeComputed,
      relativCircleSize = 36,
      needDrawCentralIcon = true,
      needDrawBackground = true,
      fontSizeMult = 2.0,
      needAdditionalLights = false,
      forMfd = true
    })
}

let digitalDev = @(){
  watch = DigitalDevicesVisible
  size = flex()
  children = DigitalDevicesVisible.get() ? digitalDevices(DigDevicesPosSize[2], DigDevicesPosSize[3], DigDevicesPosSize[0], DigDevicesPosSize[1]) : null
}

function Root() {
  let children = [
    mkTws
    radarMfd(radarPosSize, MfdRadarColor)
    mfdSightHud
    mfdCustomPages
    digitalDev
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