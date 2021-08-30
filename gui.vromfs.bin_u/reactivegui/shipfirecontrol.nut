local interopGen = require("interopGen.nut")
local compass = require("compass.nut")
local {CompassValue} = require("compassState.nut")
local {hudFontHgt, fontOutlineFxFactor, greenColor, greenColorGrid, fontOutlineColor} = require("style/airHudStyle.nut")
local {fwdAngle, sightAngle} = require("shipState.nut")
local radar = require("radarComponent.nut")

local compassWidth = hdpx(500)
local compassHeight = hdpx(40)
local compassStep = 5.0
local compassOneElementWidth = compassHeight
local compassDegreeWidth = compassOneElementWidth / compassStep

local fcsState = {
  IsVisible = Watched(false)

  IsTargetSelected = Watched(false)
  TargetFwdDir = Watched(0.0)
  TargetSpeed =Watched(0.0)

  IsForestallVisible = Watched(false)
  ForestallAzimuth = Watched(0.0)
  ForestallAzimuthWidth = Watched(0.0)
}

interopGen({
  stateTable = fcsState
  prefix = "fcs"
  postfix = "Update"
})

local compassStyle = {
  color = greenColor
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
  fillColor = greenColor
  lineWidth = max(LINE_WIDTH, hdpx(LINE_WIDTH))
}

local compassComponent = {
  size = SIZE_TO_CONTENT
  pos = [sw(50) - 0.5 * compassWidth, sh(12)]
  children = compass(compassStyle, compassWidth, compassHeight, greenColor)
}

local function norm_s_ang_deg(a) {
  a = a % 360.0;
  return a > 180.0 ? a - 360.0 : (a < -180.0 ? a + 360.0 : a)
}

local azimuthMark = @() {
  watch = [fcsState.ForestallAzimuth, fcsState.ForestallAzimuthWidth, CompassValue]
  size = [3.0 * compassDegreeWidth * (fcsState.ForestallAzimuthWidth.value + 1), hdpx(5)]
  rendObj = ROBJ_SOLID
  pos = [norm_s_ang_deg(CompassValue.value - fcsState.ForestallAzimuth.value) * compassDegreeWidth, 0]
  color = greenColor
}

local compassMarks = {
  halign = ALIGN_CENTER
  size = [compassWidth, hdpx(5)]
  pos = [sw(50) - 0.5 * compassWidth, sh(15)]
  clipChildren = true
  children = azimuthMark
}

local background = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [sh(28), sh(28)]
  color = greenColorGrid
  fillColor = Color(0,32,0,120)
  lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)
  commands = [
    [VECTOR_ELLIPSE, 50, 50, 50, 50]
  ]
}

local function drawShipIcon(iconSize, iconPos, iconColor, absBearing) {
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = iconSize
    pos = iconPos
    color = iconColor
    transform = {
      pivot = [0.5, 0.5]
      rotate = absBearing.value - sightAngle.value
    }
    lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)
    commands = [
      [VECTOR_LINE, 40, 100, 40, 10],
      [VECTOR_LINE, 40, 10, 50, 0],
      [VECTOR_LINE, 50, 0, 60, 10],
      [VECTOR_LINE, 60, 10, 60, 100],
      [VECTOR_LINE, 60, 100, 40, 100]
    ]
  }
}

local targetSpeed = @() {
  watch = fcsState.TargetSpeed
  rendObj = ROBJ_DTEXT
  text = ::cross_call.measureTypes.SPEED.getMeasureUnitsText(fcsState.TargetSpeed.value)
  font = Fonts.tiny_text_hud
  pos = [0, sh(1)]
  color = greenColorGrid
  margin = [0,0,0,sh(1)]
}

local roundIndicator = @() {
  pos = [sh(4), sh(18)]
  halign = ALIGN_CENTER
  watch = [sightAngle, fwdAngle, fcsState.IsTargetSelected, fcsState.TargetFwdDir]
  children = [
    background
    drawShipIcon([sh(8), sh(8)], [0, sh(18)], greenColorGrid, fwdAngle)
    fcsState.IsTargetSelected.value ? drawShipIcon([sh(14), sh(14)], [0, sh(1)], Color(255, 128, 32, 255), fcsState.TargetFwdDir) : null
    fcsState.IsTargetSelected.value ? targetSpeed : null
  ]
}

local root = @() {
  watch = [fcsState.IsForestallVisible, radar.state.IsRadarVisible]
  children = [
    !radar.state.IsRadarVisible.value ? compassComponent : null
    fcsState.IsForestallVisible.value ? compassMarks : null
    roundIndicator
  ]
}

return @() {
  watch = [fcsState.IsVisible]
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = [sw(100), sh(100)]
  children = fcsState.IsVisible.value ? root : null
}