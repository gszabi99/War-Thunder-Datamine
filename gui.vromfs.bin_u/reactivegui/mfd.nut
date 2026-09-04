from "%rGui/airState.nut" import IndicatorsVisible, MlwsLwsForMfd, RwrForMfd, IsMfdEnabled, RwrPosSize
from "%rGui/planeMfdCamera.nut" import planeMfdCameraSwitcher
from "%rGui/radarState.nut" import MfdRadarColor, radarPosSize
from "%rGui/radar.nut" import radarMfd
from "%rGui/planeCockpit/customPageBuilder.nut" import mfdCustomPages
from "%rGui/planeState/planeToolsState.nut" import MfdRwrColor, DigitalDevicesVisible, MfdHsdVisible, MfdHsdPosSize
from "%rGui/planeRwr.nut" import planeRwrSwitcher
from "%rGui/planeCockpit/instrumentsPage/digitalDevices.nut" import devices
from "%rGui/planeCockpit/instrumentsPage/hsd.nut" import hsd
from "%rGui/globals/ui_library.nut" import *

let { DigDevicesPosSize } = require("%rGui/planeState/planeToolsState.nut")


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
  size = FLEX
  children = DigitalDevicesVisible.get() ? devices(DigDevicesPosSize[2], DigDevicesPosSize[3], DigDevicesPosSize[0], DigDevicesPosSize[1]) : null
}

let mfdHsd = @(){
  watch = MfdHsdVisible
  size = FLEX
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
    size = const [sw(100), sh(100)]
    children = (IndicatorsVisible.get() || IsMfdEnabled.get()) ? children : null
  }
}


return Root