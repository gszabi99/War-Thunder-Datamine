let {mkRadarForMfd} = require("radarComponent.nut")
let {MfdRadarColor, MfdRadarEnabled} = require("radarState.nut")
let {IsMfdEnabled, MfdOpticAtgmSightVis, MfdSightPosSize, RwrScale, MfdRadarWithNavVis, MfdRadarNavPosSize} = require("planeState/planeToolsState.nut")
let tws = require("tws.nut")
let opticAtgmSight = require("opticAtgmSight.nut")
let {RwrForMfd, RwrPosSize} = require("airState.nut")
let mfdRadarWithNav = require("planeCockpit/mfdRadarWithNav.nut");

let twsPosComputed = Computed(@() [RwrPosSize.value[0] + 0.17 * RwrPosSize.value[2],
  RwrPosSize.value[1] + 0.17 * RwrPosSize.value[3]])
let twsSizeComputed = Computed(@() [0.66 * RwrPosSize.value[2], 0.66 * RwrPosSize.value[3]])

let planeMFD = @() {
  watch = [MfdRadarEnabled, RwrForMfd, MfdOpticAtgmSightVis, RwrScale, MfdRadarWithNavVis]
  size = flex()
  children = [
    (MfdRadarEnabled.value ? mkRadarForMfd(MfdRadarColor) : null),
    (RwrForMfd.value
      ? tws({
        colorWatched = MfdRadarColor,
        posWatched = twsPosComputed,
        sizeWatched = twsSizeComputed,
        relativCircleSize = 36
        scale = RwrScale.value
      })
      : null),
    (MfdOpticAtgmSightVis.value ? opticAtgmSight(MfdSightPosSize[2], MfdSightPosSize[3], MfdSightPosSize[0], MfdSightPosSize[1]) : null),
    (MfdRadarWithNavVis.value ? mfdRadarWithNav(MfdRadarNavPosSize[2], MfdRadarNavPosSize[3], MfdRadarNavPosSize[0], MfdRadarNavPosSize[1]) : null)
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