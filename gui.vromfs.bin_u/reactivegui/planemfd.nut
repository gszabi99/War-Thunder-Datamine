local radarComponent = require("radarComponent.nut")
local function planeMFD() {
  return [
    radarComponent.mkRadarForMfd(radarComponent.state.radarPosSize.value.x, radarComponent.state.radarPosSize.value.y)
  ]
}

local Root = function() {
  local children = planeMFD()

  return {
    watch = [radarComponent.state.MfdRadarEnabled, radarComponent.state.MfdRadarColor, radarComponent.state.radarPosSize]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = radarComponent.state.MfdRadarEnabled ? children : null
  }
}


return Root