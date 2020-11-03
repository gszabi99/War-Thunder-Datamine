local {IlsPosSize, IlsMask, MfdColor, IsIlsEnabled, IndicatorsVisible, IsMfdEnabled} = require("helicopterState.nut")
local {paramsTable, compassElem, horSpeed, vertSpeed, rocketAim, taTarget} = require("helicopterHudElems.nut")
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

local mfdPilotParamsTable = paramsTable(IlsMask,
  600,
  [50, 550],
  10,  false, true)

local function ilsHud(elemStyle, isBackground) {
  local ilsStyle = elemStyle.__merge({
    lineWidth = LINE_WIDTH * 3
    color = MfdColor.value
  })
  return @(){
    watch = IsIlsEnabled
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        transform = {
          translate = [IlsPosSize[0], IlsPosSize[1]]
        }
      }
    }
    children = IsIlsEnabled.value ?
    [
      mfdPilotParamsTable(ilsStyle, isBackground)
      vertSpeed(ilsStyle, pilotSh(5), pilotSh(40), pilotSw(50) + pilotHdpx(330), pilotSh(45), isBackground)
      horSpeed(ilsStyle, isBackground, pilotSw(50), pilotSh(80), pilotHdpx(100))
      compassElem(ilsStyle, isBackground, pilotSw(100), pilotSh(13), pilotSw(50) - 0.5 * pilotSw(100), pilotSh(15))
    ]
    : null
  }
}

local function ilsMovingMarks(elemStyle, isBackground) {
  local ilsStyle = elemStyle.__merge({
    lineWidth = LINE_WIDTH * 3
    color = MfdColor.value
  })
  return @(){
    watch = IsIlsEnabled
    children = IsIlsEnabled.value ?
    [
      rocketAim(ilsStyle, pilotSw(4), pilotSh(8), isBackground)
      taTarget(ilsStyle, pilotSw(25), pilotSh(25), isBackground)
    ]
    : null
  }
}

local function ilsHUD(colorStyle, isBackground) {
  return [
    ilsHud(colorStyle, isBackground)
    ilsMovingMarks(colorStyle, isBackground)
  ]
}

local function Root() {
  local children = ilsHUD(styleLineBackground, true)
  children.extend(ilsHUD(styleLineForeground, false))

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