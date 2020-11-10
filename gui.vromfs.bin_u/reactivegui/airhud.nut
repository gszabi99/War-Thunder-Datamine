local radarComponent = require("radarComponent.nut")
local tws = require("tws.nut")
local {IsMlwsLwsHudVisible, IsRwrHudVisible, IsTwsActivated, CollapsedIcon} = require("twsState.nut")
local {hudFontHgt, greenColor, fontOutlineColor, fontOutlineFxFactor} = require("style/airHudStyle.nut")
local {safeAreaSizeHud} = require("style/screenState.nut")

const STATE_ICON_SIZE = 54

local style = {
  color = greenColor
  lineForeground = {
    color = greenColor
    fillColor = greenColor
    lineWidth = max(hdpx(1) * LINE_WIDTH, 1.4)
    font = Fonts.hud
    fontFxColor = fontOutlineColor
    fontFxFactor = fontOutlineFxFactor
    fontFx = FFT_GLOW
    fontSize = hudFontHgt
  }
}

local rwrPic = Picture("!ui/gameuiskin#rwr_stby_icon")
local function mkTws (colorStyle) {
  local twsPosX = IsTwsActivated.value ? sw(2) : sw(81)
  local twsPosY = IsTwsActivated.value ? sh(37) : sh(35)
  local twsSize = IsTwsActivated.value ? sh(20) : sh(5)
  if (IsTwsActivated.value || !CollapsedIcon.value){
    return @() {
    children = (!IsMlwsLwsHudVisible.value && !IsRwrHudVisible.value) ? null :
      tws({
          colorStyle = colorStyle,
          pos = [twsPosX, twsPosY],
          size = [twsSize, twsSize],
          relativCircleSize = 43
        })
    }
  }
  else if (IsMlwsLwsHudVisible.value || IsRwrHudVisible.value){
    return @() style.__merge({
      pos = [sw(90), sh(33)]
      size = [sh(5), sh(5)]
      rendObj = ROBJ_IMAGE
      image = rwrPic
      color = style.color
    })
  }
  else
    return null
}

local radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
local function mkRadar() {
  local radarVisible = radarComponent.state.IsRadarVisible.value || radarComponent.state.IsRadar2Visible.value
  local radarPosY = radarVisible ? sh(68) : sh(35)
  local radarSize = radarVisible ? sh(28) : sh(8)
  local radarPosX = radarVisible ? safeAreaSizeHud.value.size[0] - radarSize - sw(1.5) : sw(91)
  if (radarVisible || !CollapsedIcon.value){
    return {
      children = radarComponent.radar(false, radarPosX, radarPosY, radarSize, true)
    }
  }
  else if (radarComponent.state.IsRadarHudVisible.value){
    return style.__merge({
      pos = [sw(95), sh(33)]
      size = [sh(5), sh(5)]
      rendObj = ROBJ_IMAGE
      image = radarPic
      color = style.color
    })
  }
  else
    return null
}

local function Root() {
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    watch = [IsMlwsLwsHudVisible, IsRwrHudVisible, IsTwsActivated,
      radarComponent.state.IsRadarVisible, radarComponent.state.IsRadar2Visible,
      radarComponent.state.IsRadarHudVisible]
    children = [
      mkRadar()
      mkTws(style)
    ]
  }
}


return Root
