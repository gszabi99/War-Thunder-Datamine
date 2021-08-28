local greenColor = Color(10, 202, 10, 250)
local fontOutlineColor = Color(0, 0, 0, 85)
local backgroundColor = Color(0, 0, 0, 75)
local greenColorGrid = Color(10, 202, 10, 200)
local targetSectorColor = Color(10, 40, 10, 200)
local fontOutlineFxFactor = max(48, ::hdpx(32))
local hudFontHgt = ::hdpx(::getFontDefHt("hud")) //currently equals to hdpx(20), but it doesnt that important

local blueHex = 0xFF
local greenHex = 0xFFFF
local redHex = 0xFFFFFF
local alphaHex = 0xFFFFFFFF

// some element doesn't appear clear in black => use white
local function isDarkColor(color){
  local sumOfRGB = (color & blueHex) + ((color & greenHex) >> 8) + ((color & redHex) >> 16)
  return sumOfRGB < 100
}

local function isColorOrWhite(color){
  return isDarkColor(color) ? Color(255,255,255, (color & alphaHex) >> 24) : color
}

local function fadeColor(color, transparency) {
  Color((color & redHex) >> 16, (color & greenHex) >> 8, color & blueHex, transparency)
}

return {hudFontHgt, greenColor, fontOutlineColor, backgroundColor, targetSectorColor, greenColorGrid, fontOutlineFxFactor
    isDarkColor, isColorOrWhite, redHex, greenHex, blueHex, fadeColor}