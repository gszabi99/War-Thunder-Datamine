from "%rGui/globals/ui_library.nut" import *

let { mkRadarForMfd } = require("radarComponent.nut")
let { MfdRadarColor, MfdRadarEnabled } = require("radarState.nut")
let { IsMfdEnabled, RwrScale, RwrBackHide, MfdRadarWithNavVis, MfdRadarNavPosSize,
    MfdVdiVisible, MfdVdiPosSize, DigitalDevicesVisible, DigDevicesPosSize } = require("planeState/planeToolsState.nut")
let tws = require("tws.nut")
let { RwrForMfd, RwrPosSize } = require("airState.nut")
let mfdRadarWithNav = require("planeCockpit/mfdRadarWithNav.nut")
let mfdVdi = require("planeCockpit/mfdVdi.nut")
let digitalDevices = require("planeCockpit/digitalDevices.nut")
let mfdCamera = require("planeMfdCamera.nut")

let twsPosComputed = Computed(@() [RwrPosSize.value[0] + 0.17 * RwrPosSize.value[2],
  RwrPosSize.value[1] + 0.17 * RwrPosSize.value[3]])
let twsSizeComputed = Computed(@() [0.66 * RwrPosSize.value[2], 0.66 * RwrPosSize.value[3]])

let planeMFD = @() {
  watch = [MfdRadarEnabled, RwrForMfd, RwrScale, MfdRadarWithNavVis, MfdVdiVisible, DigitalDevicesVisible, RwrBackHide]
  size = flex()
  children = [
    (MfdRadarEnabled.value ? mkRadarForMfd(MfdRadarColor) : null),
    (RwrForMfd.value
      ? tws({
        colorWatched = MfdRadarColor,
        posWatched = twsPosComputed,
        sizeWatched = twsSizeComputed,
        relativCircleSize = 36,
        scale = RwrScale.value,
        needDrawCentralIcon = !RwrBackHide.value,
        needDrawBackground = !RwrBackHide.value,
        fontSizeMult = 2.0,
        needAdditionalLights = false
      })
      : null),
    mfdCamera,
    (MfdRadarWithNavVis.value ? mfdRadarWithNav(MfdRadarNavPosSize[2], MfdRadarNavPosSize[3], MfdRadarNavPosSize[0], MfdRadarNavPosSize[1]) : null),
    (MfdVdiVisible.value ? mfdVdi(MfdVdiPosSize[2], MfdVdiPosSize[3], MfdVdiPosSize[0], MfdVdiPosSize[1]) : null),
    (DigitalDevicesVisible.value ? digitalDevices(DigDevicesPosSize[2], DigDevicesPosSize[3], DigDevicesPosSize[0], DigDevicesPosSize[1]) : null)
  ]
}

let Root = @() {
  watch = IsMfdEnabled
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = [sw(100), sh(100)]
  children = IsMfdEnabled.value ? planeMFD : null
}

return Root