from "%rGui/globals/ui_library.nut" import *

let { IndicatorsVisible, MfdColor, MlwsLwsForMfd, RwrForMfd, IsMfdEnabled, RwrPosSize } = require("airState.nut")
let tws = require("tws.nut")
let { mkRadarForMfd } = require("radarComponent.nut")
let mfdSightHud = require("planeMfdCamera.nut")


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
      relativCircleSize = 36,
      needDrawCentralIcon = true,
      needDrawBackground = true,
      fontSizeMult = 2.0,
      needAdditionalLights = false
    })
}

let function Root() {
  let children = [
    mkTws
    mkRadarForMfd(MfdColor)
    mfdSightHud
  ]

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