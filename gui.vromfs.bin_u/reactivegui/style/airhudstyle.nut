local greenColor = Color(10, 202, 10, 250)
local fontOutlineColor = Color(0, 0, 0, 85)
local backgroundColor = Color(0, 0, 0, 75)
local greenColorGrid = Color(10, 202, 10, 200)
local targetSectorColor = Color(10, 40, 10, 200)
local fontOutlineFxFactor = max(48, ::hdpx(32))
local hudFontHgt = ::hdpx(::getFontDefHt("hud")) //currently equals to hdpx(20), but it doesnt that important

return {hudFontHgt, greenColor, fontOutlineColor, backgroundColor, targetSectorColor, greenColorGrid, fontOutlineFxFactor}