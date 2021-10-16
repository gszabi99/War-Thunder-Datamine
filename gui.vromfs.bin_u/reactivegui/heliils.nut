local {IlsPosSize, IlsMask, IsIlsEnabled, IndicatorsVisible, IsMfdEnabled, SecondaryMask, MfdColor} = require("airState.nut")
local {paramsTable, horSpeed, vertSpeed, rocketAim, taTarget} = require("airHudElems.nut")
local compass = require("compass.nut")
local {hudFontHgt, fontOutlineColor, fontOutlineFxFactor} = require("style/airHudStyle.nut")

local styleLineBackground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = max( LINE_WIDTH + 1.5, hdpx(LINE_WIDTH + 1.5))
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt*2
}


local styleLineForeground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt*2
}

local pilotSh = @(h) h * IlsPosSize[3] / 100

local pilotSw = @(w) w * IlsPosSize[2] / 100

local pilotHdpx = @(px) px * IlsPosSize[3] / 1024

local mfdPilotParamsTablePos = Watched([0, 300])

local mfdPilotParamsTable = paramsTable(IlsMask, SecondaryMask,
  800, 50,
  mfdPilotParamsTablePos,
  10,  false, true)

local function compassComponent(style, size, pos) {
  return @() {
    pos
    watch = MfdColor
    children = compass(size, MfdColor.value, style)
  }
}

local function ilsHud(elemStyle, isBackground) {
  local ilsStyle = elemStyle.__merge({
    lineWidth = LINE_WIDTH * 3
    color = MfdColor.value
  })
  return @(){
    watch = [IsIlsEnabled, MfdColor]
    pos = [IlsPosSize[0], IlsPosSize[1]]
    children = IsIlsEnabled.value ?
    [
      mfdPilotParamsTable(isBackground, ilsStyle)
      vertSpeed(pilotSh(5), pilotSh(40), pilotSw(50) + pilotHdpx(330), pilotSh(45), MfdColor.value, isBackground, ilsStyle)
      horSpeed(isBackground, MfdColor.value, pilotSw(50), pilotSh(80), pilotHdpx(100), ilsStyle)
      compassComponent(ilsStyle, [pilotSw(100), pilotSh(13)], [pilotSw(50) - 0.5 * pilotSw(100), pilotSh(15)])
    ]
    : null
  }
}

local function ilsMovingMarks(style, isBackground) {
  local ilsStyle = style.__merge({
    lineWidth = LINE_WIDTH * 3
    color = MfdColor.value
  })
  return @(){
    watch = [IsIlsEnabled, MfdColor]
    children = IsIlsEnabled.value ?
    [
      rocketAim(pilotSw(4), pilotSh(8), isBackground, MfdColor.value, ilsStyle)
      taTarget(pilotSw(25), pilotSh(25), isBackground)
    ]
    : null
  }
}

local function ilsHUD(style, isBackground) {
  return [
    ilsHud(style, isBackground)
    ilsMovingMarks(style, isBackground)
  ]
}

local function Root() {
  local children = ilsHUD(styleLineBackground, true)
  children.extend(ilsHUD(styleLineForeground, false))

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