from "%rGui/globals/ui_library.nut" import *

let { IndicatorsVisible, MlwsLwsForMfd, RwrForMfd, IsMfdEnabled, RwrPosSize } = require("airState.nut")
let mfdSightHud = require("planeMfdCamera.nut")
let { MfdRadarColor, radarPosSize } = require("radarState.nut")
let { radarMfd } = require("%rGui/radar.nut")
let mfdCustomPages = require("%rGui/planeCockpit/customPageBuilder.nut")
let { MfdRwrColor, DigitalDevicesVisible, DigDevicesPosSize, MfdHsdVisible, MfdHsdPosSize } = require("planeState/planeToolsState.nut")
let { planeRwrSwitcher, rwrSetting } = require("planeRwr.nut")
let digitalDevices = require("planeCockpit/digitalDevices.nut")
let hsd = require("planeCockpit/hsd.nut")


let twsPosComputed = Computed(@() [RwrPosSize.value[0] + 0.17 * RwrPosSize.value[2],
  RwrPosSize.value[1] + 0.17 * RwrPosSize.value[3]])
let twsSizeComputed = Computed(@() [0.66 * RwrPosSize.value[2], 0.66 * RwrPosSize.value[3]])

let mkTws = @() {
  watch = [MlwsLwsForMfd, RwrForMfd]
  children = (!MlwsLwsForMfd.value && !RwrForMfd.value) ? null
    : planeRwrSwitcher(twsPosComputed, twsSizeComputed, MfdRwrColor, 1.0, false, 70.0, 2.0)
}

let digitalDev = @(){
  watch = DigitalDevicesVisible
  size = flex()
  children = DigitalDevicesVisible.get() ? digitalDevices(DigDevicesPosSize[2], DigDevicesPosSize[3], DigDevicesPosSize[0], DigDevicesPosSize[1]) : null
}

let mfdHsd = @(){
  watch = MfdHsdVisible
  size = flex()
  children = MfdHsdVisible.get() ? hsd(MfdHsdPosSize) : null
}

function Root() {
  let children = [
    mkTws
    radarMfd(radarPosSize, MfdRadarColor)
    mfdSightHud
    mfdCustomPages
    digitalDev
    mfdHsd
  ]

  return {
    watch = [
      IndicatorsVisible
      IsMfdEnabled
      rwrSetting
    ]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = (IndicatorsVisible.value || IsMfdEnabled.value) ? children : null
  }
}


return Root