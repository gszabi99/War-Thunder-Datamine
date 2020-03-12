local rwr = require("rwr.nut")
local helicopterState = require("helicopterState.nut")
local hudElems = require("helicopterHudElems.nut")
local mlws = require("mlws.nut")
local radarComponent = require("radarComponent.nut")


local backgroundColor = Color(0, 0, 0, 150)
local fontOutlineColor = Color(0, 0, 0, 235)
local ilsFontScale = 2.0
local mfdFontScale = 1.5

local getColor = function(isBackground){
  return isBackground ? backgroundColor : helicopterState.MfdColor.value
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
local sightSh = function(h)
{
  return h * helicopterState.MfdSightPosSize[3] / 100
}
local sightSw = function(w)
{
  return w * helicopterState.MfdSightPosSize[2] / 100
}
local sightHdpx = function(px)
{
  return px * helicopterState.MfdSightPosSize[3] / 1024
}
local getMfdFontScale = function()
{
  return mfdFontScale * min(helicopterState.MfdSightPosSize[2], helicopterState.MfdSightPosSize[3]) / 512
}

local style = {}
style.lineBackground <- class {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * (LINE_WIDTH + 1.5)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = 40
  fontFx = FFT_GLOW
  fontScale = 1.5
}


style.lineForeground <- class {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * LINE_WIDTH
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = 40
  fontFx = FFT_GLOW
  fontScale = 1.5
}

local getRwr = function(colorStyle) {
  local getChildren = function() {
    return rwr(colorStyle,
       helicopterState.RwrPosSize[0] + helicopterState.RwrPosSize[2] * 0.17,
       helicopterState.RwrPosSize[1] + helicopterState.RwrPosSize[3] * 0.17,
       helicopterState.RwrPosSize[2] * 0.66,
       helicopterState.RwrPosSize[3] * 0.66, true)
  }
  return @(){
    watch = helicopterState.RwrForMfd
    children = getChildren()
  }
}

local getMlws = function(colorStyle) {
  local getChildren = function() {
    return mlws(colorStyle,
       helicopterState.RwrPosSize[0] + helicopterState.RwrPosSize[2] * 0.17,
       helicopterState.RwrPosSize[1] + helicopterState.RwrPosSize[3] * 0.17,
       helicopterState.RwrPosSize[2] * 0.66,
       helicopterState.RwrPosSize[3] * 0.66, true)
  }
  return @(){
    watch = helicopterState.MlwsForMfd
    children = getChildren()
  }
}

local mfdSightParamsTable = hudElems.paramsTable(helicopterState.MfdSightMask,
  250,
  [30, 175],
  hdpx(3))

local mfdPilotParamsTable = hudElems.paramsTable(helicopterState.IlsMask,
  300,
  [50, 225],
  0,  false)

local function mfdSightHud(elemStyle, isBackground) {
  local mfdStyle = elemStyle.__merge({
        fontScale = getMfdFontScale()
        color = helicopterState.MfdColor.value
      })
  return @(){
    watch = helicopterState.IsMfdSightHudVisible
    pos = [helicopterState.MfdSightPosSize[0], helicopterState.MfdSightPosSize[1]]
    children = helicopterState.IsMfdSightHudVisible.value ?
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

local function ilsHud(elemStyle, isBackground) {
  local ilsStyle = elemStyle.__merge({
    fontScale = ilsFontScale
    lineWidth = LINE_WIDTH * 3
    color = helicopterState.MfdColor.value
  })
  return @(){
    watch = helicopterState.IsIlsEnabled
    pos = [helicopterState.IlsPosSize[0], helicopterState.IlsPosSize[1]]
    children = helicopterState.IsIlsEnabled.value ?
    [
      mfdPilotParamsTable(ilsStyle, isBackground)
      hudElems.vertSpeed(ilsStyle, pilotSh(5), pilotSh(40), pilotSw(50) + pilotHdpx(384), pilotSh(35), isBackground)
      hudElems.horSpeed(ilsStyle, isBackground, pilotSw(50), pilotSh(60), pilotHdpx(100))
      hudElems.compassElem(ilsStyle, isBackground, pilotSw(75), pilotSh(13), pilotSw(50) - 0.5 * pilotSw(75), pilotSh(5))
      hudElems.rocketAim(ilsStyle, pilotSw(4), pilotSh(8), isBackground)
      hudElems.taTarget(ilsStyle, pilotSw(25), pilotSh(25), isBackground)
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
    ilsHud(colorStyle, isBackground)
    getRwr(rwrStyle)
    getMlws(rwrStyle)
    radarComponent.radar(true, sw(6), sh(6), getColor(isBackground))
  ]
}

local Root = function() {
  local children = mfdHUD(style.lineBackground, true)
  children.extend(mfdHUD(style.lineForeground, false))

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