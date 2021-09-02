local radarComponent = require("radarComponent.nut")
local {IsMfdEnabled, MfdOpticAtgmSightVis, MfdSightPosSize, RwrScale} = require("planeState.nut")
local tws = require("tws.nut")
local opticAtgmSight = require("opticAtgmSight.nut")
local {RwrForMfd, RwrPosSize} = require("helicopterState.nut")
local {hudFontHgt, fontOutlineColor, fontOutlineFxFactor} = require("style/airHudStyle.nut")

local colorStyle = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt*1.5
}

local function planeMFD() {
  local rwrStyle = colorStyle.__merge({
    color = radarComponent.state.MfdRadarColor.value
  })
  return @() {
    watch = [radarComponent.state.MfdRadarEnabled, RwrForMfd, radarComponent.state.MfdRadarColor, MfdOpticAtgmSightVis, RwrScale]
    size = flex()
    children = [
      (radarComponent.state.MfdRadarEnabled.value ? radarComponent.mkRadarForMfd(radarComponent.state.MfdRadarColor.value) : null),
      (RwrForMfd.value ?
        tws({
          colorStyle = rwrStyle,
          pos = [RwrPosSize[0] + RwrPosSize[2] * 0.17,
            RwrPosSize[1] + RwrPosSize[3] * 0.17],
          size = [RwrPosSize[2] * 0.66, RwrPosSize[3] * 0.66],
          relativCircleSize = 36
          scale = RwrScale.value
        })
        : null),
        (MfdOpticAtgmSightVis.value ? opticAtgmSight(MfdSightPosSize[2], MfdSightPosSize[3], MfdSightPosSize[0], MfdSightPosSize[1]) : null)
    ]
  }
}

local Root = function() {
  local children = planeMFD()

  return {
    watch = IsMfdEnabled
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = IsMfdEnabled.value ? children : null
  }
}


return Root