local radarComponent = require("radarComponent.nut")
local rwr = require("rwr.nut")

local greenColor = Color(10, 202, 10, 250)
local fontOutlineColor = Color(0, 0, 0, 235)

local getFontScale = function()
{
  return max(sh(100) / 1080, 1)
}

local style = {}

style.lineForeground <- class {
  color = greenColor
  fillColor = greenColor
  lineWidth = hdpx(1) * LINE_WIDTH
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = 40
  fontFx = FFT_GLOW
  fontScale = getFontScale()
}

local Root = function() {
  local rwrStyle = style.__merge({
    color = greenColor
  })
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = [
      radarComponent.radar(false)
      rwr(rwrStyle)
    ]
  }
}


return Root
