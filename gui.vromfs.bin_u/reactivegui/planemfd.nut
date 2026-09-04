import "%rGui/planeCockpit/radarPage/mfdRadarWithNav.nut" as mfdRadarWithNav
import "%rGui/planeCockpit/instrumentsPage/mfdVdi.nut" as mfdVdi
from "%rGui/radarState.nut" import MfdRadarColor, MfdRadarEnabled, radarPosSize
from "%rGui/planeState/planeToolsState.nut" import IsMfdEnabled, MfdRwrColor, RwrScale, RwrBackHide, MfdRadarWithNavVis, MfdVdiVisible, DigitalDevicesVisible
  , MfdHsdVisible, MfdHsdPosSize
from "%rGui/tws.nut" import mfdRwrSettings
from "%rGui/planeRwr.nut" import planeRwrSwitcher
from "%rGui/airState.nut" import RwrForMfd, RwrPosSize
from "%rGui/planeCockpit/instrumentsPage/digitalDevices.nut" import devices
from "%rGui/planeMfdCamera.nut" import planeMfdCameraSwitcher
from "%rGui/radar.nut" import radarMfd
from "%rGui/planeCockpit/customPageBuilder.nut" import mfdCustomPages
from "%rGui/planeCockpit/instrumentsPage/hsd.nut" import hsd
from "%rGui/globals/ui_library.nut" import *

let { MfdRadarNavPosSize, MfdVdiPosSize, DigDevicesPosSize } = require("%rGui/planeState/planeToolsState.nut")

let twsPosComputed = Computed(@() [RwrPosSize.get()[0] + 0.17 * RwrPosSize.get()[2],
  RwrPosSize.get()[1] + 0.17 * RwrPosSize.get()[3]])
let twsSizeComputed = Computed(@() [0.66 * RwrPosSize.get()[2], 0.66 * RwrPosSize.get()[3]])

let radarMfdComp = @() {
  watch = MfdRadarEnabled
  size = FLEX
  children = MfdRadarEnabled.get() ? radarMfd(radarPosSize, MfdRadarColor) : null
}

let rwrMfdComp = @() {
  watch = [RwrForMfd, RwrScale]
  size = FLEX
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
  size = FLEX
  children = !RwrForMfd.get() ? null
    : planeRwrSwitcher(twsPosComputed, twsSizeComputed, MfdRwrColor, RwrScale.get(), RwrBackHide.get(), 70, 2.0)
}

let mfdRadarWithNavComp = @() {
  watch = MfdRadarWithNavVis
  size = FLEX
  children = !MfdRadarWithNavVis.get() ? null
    : mfdRadarWithNav(MfdRadarNavPosSize[2], MfdRadarNavPosSize[3], MfdRadarNavPosSize[0], MfdRadarNavPosSize[1])
}

let mfdVdiComp = @() {
  watch = MfdVdiVisible
  size = FLEX
  children = !MfdVdiVisible.get() ? null
    : mfdVdi(MfdVdiPosSize[2], MfdVdiPosSize[3], MfdVdiPosSize[0], MfdVdiPosSize[1])
}

let digitalDevicesComp = @() {
  watch = DigitalDevicesVisible
  size = FLEX
  children = !DigitalDevicesVisible.get() ? null
    : devices(DigDevicesPosSize[2], DigDevicesPosSize[3], DigDevicesPosSize[0], DigDevicesPosSize[1])
}

let mfdHsdComp = @() {
  watch = MfdHsdVisible
  size = FLEX
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