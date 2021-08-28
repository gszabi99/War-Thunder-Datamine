local {IndicatorsVisible, IsMfdSightHudVisible, MfdSightMask, MfdColor, MfdSightPosSize, MlwsLwsForMfd, RwrForMfd,
  IsMfdEnabled, RwrPosSize, SecondaryMask} = require("airState.nut")
local {paramsTable, turretAngles, launchDistanceMax, sight, rangeFinder, lockSight, targetSize} = require("airHudElems.nut")
local tws = require("tws.nut")
local {mkRadarForMfd} = require("radarComponent.nut")

local {ceil} = require("std/math.nut")

const mfdFontScale = 1.5

local sightSh = @(h) ceil(h * MfdSightPosSize[3] / 100)
local sightSw = @(w) ceil(w * MfdSightPosSize[2] / 100)
local sightHdpx = @(px) ceil(px * MfdSightPosSize[3] / 1024)

local twsPosComputed = Computed(@() [RwrPosSize.value[0] + 0.17 * RwrPosSize.value[2],
  RwrPosSize.value[1] + 0.17 * RwrPosSize.value[3]])
local twsSizeComputed = Computed(@() [0.66 * RwrPosSize.value[2], 0.66 * RwrPosSize.value[3]])

local mkTws = @() {
  watch = [MlwsLwsForMfd, RwrForMfd]
  children = (!MlwsLwsForMfd.value && !RwrForMfd.value) ? null
    : tws({
      colorWatched = MfdColor
      posWatched = twsPosComputed,
      sizeWatched = twsSizeComputed,
      relativCircleSize = 36
    })
}

local mfdSightParamTablePos = Watched([hdpx(30), hdpx(175)])

local mfdSightParamsTable = paramsTable(MfdSightMask, SecondaryMask,
  hdpx(250), hdpx(28),
  mfdSightParamTablePos,
  hdpx(3))

local function mfdSightHud(isBackground) {
  return @(){
    watch = IsMfdSightHudVisible
    pos = [MfdSightPosSize[0], MfdSightPosSize[1]]
    children = IsMfdSightHudVisible.value ?
    [
      turretAngles(MfdColor, sightSw(15), sightHdpx(150), sightSw(50), sightSh(90), isBackground)
      launchDistanceMax(MfdColor, sightSw(15), sightHdpx(150), sightSw(50), sightSh(90), isBackground)
      sight(MfdColor, sightSw(50), sightSh(50), sightHdpx(500), isBackground)
      rangeFinder(MfdColor, sightSw(50), sightSh(58), isBackground)
      lockSight(MfdColor, sightHdpx(150), sightHdpx(100), sightSw(50), sightSh(50), isBackground)
      targetSize(MfdColor, sightSw(100), sightSh(100))
      mfdSightParamsTable(isBackground)
    ]
    : null
  }
}



local function mfdHUD(isBackground) {

  return [
    mfdSightHud(isBackground)
    mkTws
    mkRadarForMfd(MfdColor)
  ]
}

local Root = function() {
  local children = mfdHUD(true)
  children.extend(mfdHUD(false))

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