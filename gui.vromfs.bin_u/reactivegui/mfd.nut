local {IndicatorsVisible, IsMfdSightHudVisible, MfdSightMask, MfdColor, MfdSightPosSize, MlwsLwsForMfd, RwrForMfd, IsMfdEnabled, RwrPosSize} = require("helicopterState.nut")
local hudElems = require("helicopterHudElems.nut")
local tws = require("tws.nut")
local radarComponent = require("radarComponent.nut")
local {hudFontHgt, fontOutlineColor, backgroundColor, fontOutlineFxFactor} = require("style/airHudStyle.nut")

const mfdFontScale = 1.5

local getColor = @(isBackground) isBackground ? backgroundColor : MfdColor.value

local sightSh = @(h) h * MfdSightPosSize[3] / 100
local sightSw = @(w) w * MfdSightPosSize[2] / 100
local sightHdpx = @(px) px * MfdSightPosSize[3] / 1024
local getMfdFontSize = @() hudFontHgt*mfdFontScale * min(MfdSightPosSize[2], MfdSightPosSize[3]) / 512

local styleLineBackground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * (LINE_WIDTH + 1.5)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt*1.5
}


local styleLineForeground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt*1.5
}

local mkTws = @(colorStyle) @() {
  watch = [MlwsLwsForMfd, RwrForMfd]
  children = (!MlwsLwsForMfd.value && !RwrForMfd) ? null
    : tws({
      colorStyle = colorStyle,
      pos = [RwrPosSize[0] + RwrPosSize[2] * 0.17,
        RwrPosSize[1] + RwrPosSize[3] * 0.17],
      size = [RwrPosSize[2] * 0.66, RwrPosSize[3] * 0.66],
      relativCircleSize = 36
    })
}

local mfdSightParamsTable = hudElems.paramsTable(MfdSightMask,
  250,
  [30, 175],
  hdpx(3))

local function mfdSightHud(elemStyle, isBackground) {
  local mfdStyle = elemStyle.__merge({
        fontSize = getMfdFontSize()
        color = MfdColor.value
      })
  return @(){
    watch = IsMfdSightHudVisible
    pos = [MfdSightPosSize[0], MfdSightPosSize[1]]
    children = IsMfdSightHudVisible.value ?
    [
      hudElems.turretAngles(mfdStyle, sightSw(15), sightHdpx(150), sightSw(50), sightSh(90), isBackground)
      hudElems.launchDistanceMax(mfdStyle, sightSw(15), sightHdpx(150), sightSw(50), sightSh(90), isBackground)
      hudElems.sight(mfdStyle, sightSw(50), sightSh(50), sightHdpx(500), isBackground)
      hudElems.rangeFinder(mfdStyle, sightSw(50), sightSh(58), isBackground)
      hudElems.lockSight(mfdStyle, sightHdpx(150), sightHdpx(100), sightSw(50), sightSh(50), isBackground)
      hudElems.targetSize(mfdStyle, sightSw(100), sightSh(100), isBackground)
      mfdSightParamsTable(mfdStyle, isBackground)
    ]
    : null
  }
}



local function mfdHUD(colorStyle, isBackground) {
  local rwrStyle = colorStyle.__merge({
    color = getColor(isBackground)
  })

  return [
    mfdSightHud(colorStyle, isBackground)
    mkTws(rwrStyle)
    radarComponent.radar(true, sw(6), sh(6), getColor(isBackground))
  ]
}

local Root = function() {
  local children = mfdHUD(styleLineBackground, true)
  children.extend(mfdHUD(styleLineForeground, false))

  return {
    watch = [
      IndicatorsVisible
      MfdColor
      IsMfdEnabled
    ]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = (IndicatorsVisible.value || IsMfdEnabled.value) ? children : null
  }
}


return Root