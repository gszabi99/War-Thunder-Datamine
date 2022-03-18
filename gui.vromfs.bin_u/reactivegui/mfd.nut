let {IndicatorsVisible, IsMfdSightHudVisible, MfdSightMask, MfdColor, MfdSightPosSize, MlwsLwsForMfd, RwrForMfd,
  IsMfdEnabled, RwrPosSize, SecondaryMask} = require("airState.nut")
let {paramsTable, turretAngles, launchDistanceMax, sight, rangeFinder, lockSight, targetSize} = require("airHudElems.nut")
let tws = require("tws.nut")
let {mkRadarForMfd} = require("radarComponent.nut")

let {ceil} = require("%sqstd/math.nut")

const mfdFontScale = 1.5

let sightSh = @(h) ceil(h * MfdSightPosSize[3] / 100)
let sightSw = @(w) ceil(w * MfdSightPosSize[2] / 100)
let sightHdpx = @(px) ceil(px * MfdSightPosSize[3] / 1024)

let twsPosComputed = Computed(@() [RwrPosSize.value[0] + 0.17 * RwrPosSize.value[2],
  RwrPosSize.value[1] + 0.17 * RwrPosSize.value[3]])
let twsSizeComputed = Computed(@() [0.66 * RwrPosSize.value[2], 0.66 * RwrPosSize.value[3]])

let mkTws = @() {
  watch = [MlwsLwsForMfd, RwrForMfd]
  children = (!MlwsLwsForMfd.value && !RwrForMfd.value) ? null
    : tws({
      colorWatched = MfdColor
      posWatched = twsPosComputed,
      sizeWatched = twsSizeComputed,
      relativCircleSize = 36
    })
}

let mfdSightParamTablePos = Watched([hdpx(30), hdpx(175)])

let mfdSightParamsTable = paramsTable(MfdSightMask, SecondaryMask,
  hdpx(250), hdpx(28),
  mfdSightParamTablePos,
  hdpx(3))

let function mfdSightHud(isBackground) {
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



let function mfdHUD(isBackground) {

  return [
    mfdSightHud(isBackground)
    mkTws
    mkRadarForMfd(MfdColor)
  ]
}

let Root = function() {
  let children = mfdHUD(true)
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