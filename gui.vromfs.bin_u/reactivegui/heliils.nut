local helicopterState = require("helicopterState.nut")
local hudElems = require("helicopterHudElems.nut")

local style = {}
local fontOutlineColor = Color(0, 0, 0, 235)

style.lineBackground <- class {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * (LINE_WIDTH + 1.5)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = 40
  fontFx = FFT_GLOW
  fontScale = 2.0
}


style.lineForeground <- class {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * LINE_WIDTH
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = 40
  fontFx = FFT_GLOW
  fontScale = 2.0
}

local pilotSh = function(h)
{
  return h * helicopterState.IlsPosSize[3] / 100
}
local pilotSw = function(w)
{
  return w * helicopterState.IlsPosSize[2] / 100
}
local pilotHdpx = function(px)
{
  return px * helicopterState.IlsPosSize[3] / 1024
}

local mfdPilotParamsTable = hudElems.paramsTable(helicopterState.IlsMask,
  600,
  [50, 550],
  10,  false, true)

local function ilsHud(elemStyle, isBackground) {
  local ilsStyle = elemStyle.__merge({
    lineWidth = LINE_WIDTH * 3
    color = helicopterState.MfdColor.value
  })
  return @(){
    watch = helicopterState.IsIlsEnabled
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        transform = {
          translate = [helicopterState.IlsPosSize[0], helicopterState.IlsPosSize[1]]
        }
      }
    }
    children = helicopterState.IsIlsEnabled.value ?
    [
      mfdPilotParamsTable(ilsStyle, isBackground)
      hudElems.vertSpeed(ilsStyle, pilotSh(5), pilotSh(40), pilotSw(50) + pilotHdpx(330), pilotSh(45), isBackground)
      hudElems.horSpeed(ilsStyle, isBackground, pilotSw(50), pilotSh(80), pilotHdpx(100))
      hudElems.compassElem(ilsStyle, isBackground, pilotSw(100), pilotSh(13), pilotSw(50) - 0.5 * pilotSw(100), pilotSh(15))
    ]
    : null
  }
}

local function ilsMovingMarks(elemStyle, isBackground) {
  local ilsStyle = elemStyle.__merge({
    lineWidth = LINE_WIDTH * 3
    color = helicopterState.MfdColor.value
  })
  return @(){
    watch = helicopterState.IsIlsEnabled
    children = helicopterState.IsIlsEnabled.value ?
    [
      hudElems.rocketAim(ilsStyle, pilotSw(4), pilotSh(8), isBackground)
      hudElems.taTarget(ilsStyle, pilotSw(25), pilotSh(25), isBackground)
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

local Root = function() {
  local children = ilsHUD(style.lineBackground, true)
  children.extend(ilsHUD(style.lineForeground, false))

  return {
    watch = [
      helicopterState.IndicatorsVisible
      helicopterState.MfdColor
      helicopterState.IsMfdEnabled
    ]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = (helicopterState.IndicatorsVisible.value ||
    helicopterState.IsMfdEnabled.value) ? children : null
  }
}


return Root