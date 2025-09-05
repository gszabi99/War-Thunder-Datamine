from "%rGui/globals/ui_library.nut" import *

let { IndicatorsVisible, MlwsLwsForMfd, RwrForMfd, IsMfdEnabled, RwrPosSize } = require("%rGui/airState.nut")
let { planeMfdCameraSwitcher } = require("%rGui/planeMfdCamera.nut")
let { MfdRadarColor, radarPosSize } = require("%rGui/radarState.nut")
let { radarMfd } = require("%rGui/radar.nut")
let { mfdCustomPages } = require("%rGui/planeCockpit/customPageBuilder.nut")
let { MfdRwrColor, DigitalDevicesVisible, DigDevicesPosSize, MfdHsdVisible, MfdHsdPosSize } = require("%rGui/planeState/planeToolsState.nut")
let { planeRwrSwitcher } = require("%rGui/planeRwr.nut")
let { devices } = require("%rGui/planeCockpit/digitalDevices.nut")
let { hsd } = require("%rGui/planeCockpit/hsd.nut")


let twsPosComputed = Computed(@() [RwrPosSize.get()[0] + 0.17 * RwrPosSize.get()[2],
  RwrPosSize.get()[1] + 0.17 * RwrPosSize.get()[3]])
let twsSizeComputed = Computed(@() [0.66 * RwrPosSize.get()[2], 0.66 * RwrPosSize.get()[3]])

let mkTws = @() {
  watch = [MlwsLwsForMfd, RwrForMfd]
  children = (!MlwsLwsForMfd.get() && !RwrForMfd.get()) ? null
    : planeRwrSwitcher(twsPosComputed, twsSizeComputed, MfdRwrColor, 1.0, false, 70.0, 2.0)
}

let digitalDev = @(){
  watch = DigitalDevicesVisible
  size = flex()
  children = DigitalDevicesVisible.get() ? devices(DigDevicesPosSize[2], DigDevicesPosSize[3], DigDevicesPosSize[0], DigDevicesPosSize[1]) : null
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
    planeMfdCameraSwitcher
    mfdCustomPages
    digitalDev
    mfdHsd
  ]

  return {
    watch = [
      IndicatorsVisible
      IsMfdEnabled
    ]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = static [sw(100), sh(100)]
    children = (IndicatorsVisible.get() || IsMfdEnabled.get()) ? children : null
  }
}


return Root