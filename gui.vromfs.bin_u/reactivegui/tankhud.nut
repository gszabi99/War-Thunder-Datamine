local radarComponent = require("radarComponent.nut")
local aamAim = require("rocketAamAim.nut")

local greenColor = Color(10, 202, 10, 250)
local getColor = @() greenColor

local style = {}

style.aamAim <- class {
  color = greenColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * 2.0
}


local Root = function() {
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = [
      radarComponent.radar(false)
      aamAim(style.aamAim, getColor)
    ]
  }
}


return Root
