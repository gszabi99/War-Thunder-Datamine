local radarComponent = require("radarComponent.nut")
local function planeMFD() {
  return [
    radarComponent.radar(true, sw(6), sh(6))
  ]
}

local Root = function() {
  local children = planeMFD()

  return {
    watch = [radarComponent.state.MfdRadarEnabled, radarComponent.state.MfdRadarColor]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = radarComponent.state.MfdRadarEnabled ? children : null
  }
}


return Root