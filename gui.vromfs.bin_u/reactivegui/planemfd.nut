local {mkRadarForMfd} = require("radarComponent.nut")
local {MfdRadarColor, MfdRadarEnabled} = require("radarState.nut")
local {IsMfdEnabled, MfdOpticAtgmSightVis, MfdSightPosSize, RwrScale, MfdRadarWithNavVis, MfdRadarNavPosSize} = require("planeState.nut")
local tws = require("tws.nut")
local opticAtgmSight = require("opticAtgmSight.nut")
local {RwrForMfd, RwrPosSize} = require("airState.nut")
local mfdRadarWithNav = require("planeCockpit/mfdRadarWithNav.nut");

local twsPosComputed = Computed(@() [RwrPosSize.value[0] + 0.17 * RwrPosSize.value[2],
  RwrPosSize.value[1] + 0.17 * RwrPosSize.value[3]])
local twsSizeComputed = Computed(@() [0.66 * RwrPosSize.value[2], 0.066 * RwrPosSize.value[3]])

local planeMFD = @() {
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

local Root = @() {
  watch = IsMfdEnabled
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = [sw(100), sh(100)]
  children = IsMfdEnabled.value ? planeMFD : null
}

return Root