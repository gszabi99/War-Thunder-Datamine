from "%rGui/globals/ui_library.nut" import *
let { round } =  require("math")

local greenColor = Color(10, 202, 10, 250)
local fontOutlineColor = Color(0, 0, 0, 255)
local backgroundColor = Color(0, 0, 0, 75)
local greenColorGrid = Color(10, 202, 10, 200)
local targetSectorColor = Color(10, 40, 10, 200)
local fontOutlineFxFactor = max(70, hdpx(90))
local hudFontHgt = hdpx(getFontDefHt("hud")) 

local blueHex = 0xFF
local greenHex = 0xFF00
local redHex = 0xFF0000
local alphaHex = 0xFF000000


let isDarkColor = memoize(function(color) {
  let sumOfRGB = (color & blueHex) + ((color & greenHex) >> 8) + ((color & redHex) >> 16)
  return sumOfRGB < 100
})

let isColorOrWhite = memoize(function(color) {
  return isDarkColor(color) ? Color(255, 255, 255, (color & alphaHex) >> 24) : color
})

function fadeColor(color, transparency) {
  return Color((color & redHex) >> 16, (color & greenHex) >> 8, color & blueHex, transparency)
}

function mixColor(colorA, colorB, mixValue) {
  return Color(
    ((colorA & redHex) >> 16) * (1.0 - mixValue) + ((colorB & redHex) >> 16) * mixValue,
    ((colorA & greenHex) >> 8) * (1.0 - mixValue) + ((colorB & greenHex) >> 8) * mixValue,
    (colorA & blueHex) * (1.0 - mixValue) + (colorB & blueHex) * mixValue,
    (colorA & alphaHex) >> 24)
}

function adjustColorBrightness(color, factor, alpha = null) {
  let r = (color & redHex) >> 16
  let g = (color & greenHex) >> 8
  let b = color & blueHex

  let adjustedR = clamp(round(r * factor).tointeger(), 0, 0xFF)
  let adjustedG = clamp(round(g * factor).tointeger(), 0, 0xFF)
  let adjustedB = clamp(round(b * factor).tointeger(), 0, 0xFF)
  alpha = alpha ?? ((color & alphaHex) >> 24)

  return Color(adjustedR, adjustedG, adjustedB, alpha)
}


function relativCircle(percent, circleSize) {
  if (percent >= 0.99999999)
    return [ [VECTOR_ELLIPSE, 0, 0, circleSize * 1.3, circleSize * 1.3] ]
  else
    return [ [VECTOR_SECTOR, 0, 0, circleSize, circleSize, -90, -90 + 360 * percent] ]
}

let styleText = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = max(1.5, hdpx(1) * (LINE_WIDTH + 1.5))
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

let styleLineForeground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

return { hudFontHgt, greenColor, fontOutlineColor, backgroundColor, targetSectorColor, greenColorGrid, fontOutlineFxFactor
  isDarkColor, isColorOrWhite, redHex, greenHex, blueHex, fadeColor, styleText, styleLineForeground, mixColor, relativCircle,
  adjustColorBrightness }