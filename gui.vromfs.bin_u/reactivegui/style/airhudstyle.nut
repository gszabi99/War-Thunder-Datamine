let greenColor = Color(10, 202, 10, 250)
let fontOutlineColor = Color(0, 0, 0, 85)
let backgroundColor = Color(0, 0, 0, 75)
let greenColorGrid = Color(10, 202, 10, 200)
let targetSectorColor = Color(10, 40, 10, 200)
let fontOutlineFxFactor = max(48, ::hdpx(32))
let hudFontHgt = ::hdpx(::getFontDefHt("hud")) //currently equals to hdpx(20), but it doesnt that important

let blueHex = 0xFF
let greenHex = 0xFFFF
let redHex = 0xFFFFFF
let alphaHex = 0xFFFFFFFF

// some element doesn't appear clear in black => use white
let function isDarkColor(color){
  let sumOfRGB = (color & blueHex) + ((color & greenHex) >> 8) + ((color & redHex) >> 16)
  return sumOfRGB < 100
}

let function isColorOrWhite(color){
  return isDarkColor(color) ? Color(255,255,255, (color & alphaHex) >> 24) : color
}

let function fadeColor(color, transparency) {
  Color((color & redHex) >> 16, (color & greenHex) >> 8, color & blueHex, transparency)
}

return {hudFontHgt, greenColor, fontOutlineColor, backgroundColor, targetSectorColor, greenColorGrid, fontOutlineFxFactor
    isDarkColor, isColorOrWhite, redHex, greenHex, blueHex, fadeColor}