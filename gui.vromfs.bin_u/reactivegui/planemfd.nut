from "%rGui/globals/ui_library.nut" import *

let { MfdRadarColor, MfdRadarEnabled, radarPosSize } = require("%rGui/radarState.nut")
let { IsMfdEnabled, MfdRwrColor, RwrScale, RwrBackHide, MfdRadarWithNavVis, MfdRadarNavPosSize,
    MfdVdiVisible, MfdVdiPosSize, DigitalDevicesVisible, DigDevicesPosSize, MfdHsdVisible, MfdHsdPosSize } = require("%rGui/planeState/planeToolsState.nut")
let { mfdRwrSettings } = require("%rGui/tws.nut")
let { planeRwrSwitcher } = require("%rGui/planeRwr.nut")
let { RwrForMfd, RwrPosSize } = require("%rGui/airState.nut")
let mfdRadarWithNav = require("%rGui/planeCockpit/mfdRadarWithNav.nut")
let mfdVdi = require("%rGui/planeCockpit/mfdVdi.nut")
let {devices} = require("%rGui/planeCockpit/digitalDevices.nut")
let { planeMfdCameraSwitcher } = require("%rGui/planeMfdCamera.nut")
let { radarMfd } = require("%rGui/radar.nut")
let { mfdCustomPages } = require("%rGui/planeCockpit/customPageBuilder.nut")
let {hsd}  = require("%rGui/planeCockpit/hsd.nut")

let twsPosComputed = Computed(@() [RwrPosSize.get()[0] + 0.17 * RwrPosSize.get()[2],
  RwrPosSize.get()[1] + 0.17 * RwrPosSize.get()[3]])
let twsSizeComputed = Computed(@() [0.66 * RwrPosSize.get()[2], 0.66 * RwrPosSize.get()[3]])

let radarMfdComp = @() {
  watch = MfdRadarEnabled
  size = flex()
  children = MfdRadarEnabled.get() ? radarMfd(radarPosSize, MfdRadarColor) : null
}

let rwrMfdComp = @() {
  watch = [RwrForMfd, RwrScale]
  size = flex()
  children = !RwrForMfd.get() || RwrScale.get() == 0.0 ? null
    : @() {
        watch = [RwrPosSize, mfdRwrSettings]
        rendObj = ROBJ_SOLID
        pos = [RwrPosSize.get()[0] - (1.0-RwrScale.get()) * 0.5 * RwrPosSize.get()[2] / RwrScale.get(), RwrPosSize.get()[1] - (1.0-RwrScale.get()) * 0.5 * RwrPosSize.get()[3] / RwrScale.get()]
        size = [RwrPosSize.get()[2] / RwrScale.get(), RwrPosSize.get()[3] / RwrScale.get()]
        color = mfdRwrSettings.get().backgroundColor
      }
}

let planeRwrSwitcherComp = @() {
  watch = [RwrForMfd, RwrScale, RwrBackHide]
  size = flex()
  children = !RwrForMfd.get() ? null
    : planeRwrSwitcher(twsPosComputed, twsSizeComputed, MfdRwrColor, RwrScale.get(), RwrBackHide.get(), 70, 2.0)
}

let mfdRadarWithNavComp = @() {
  watch = MfdRadarWithNavVis
  size = flex()
  children = !MfdRadarWithNavVis.get() ? null
    : mfdRadarWithNav(MfdRadarNavPosSize[2], MfdRadarNavPosSize[3], MfdRadarNavPosSize[0], MfdRadarNavPosSize[1])
}

let mfdVdiComp = @() {
  watch = MfdVdiVisible
  size = flex()
  children = !MfdVdiVisible.get() ? null
    : mfdVdi(MfdVdiPosSize[2], MfdVdiPosSize[3], MfdVdiPosSize[0], MfdVdiPosSize[1])
}

let digitalDevicesComp = @() {
  watch = DigitalDevicesVisible
  size = flex()
  children = !DigitalDevicesVisible.get() ? null
    : devices(DigDevicesPosSize[2], DigDevicesPosSize[3], DigDevicesPosSize[0], DigDevicesPosSize[1])
}

let mfdHsdComp = @() {
  watch = MfdHsdVisible
  size = flex()
  children = MfdHsdVisible.get() ? hsd(MfdHsdPosSize) : null
}

let Root = @() {
  watch = IsMfdEnabled
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = const [sw(100), sh(100)]
  children = !IsMfdEnabled.get() ? null
    : [radarMfdComp, rwrMfdComp, planeRwrSwitcherComp, planeMfdCameraSwitcher, mfdCustomPages,
      mfdRadarWithNavComp, mfdVdiComp, digitalDevicesComp, mfdHsdComp]
}

return Root