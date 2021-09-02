local { IsCommanderViewAimModeActive } = require("tankState.nut")
local { IsSightLocked } = require("reactiveGui/hud/targetTrackerState.nut")

local drawMark = function(state_var, text, pos, line_style, color_func) {
    local textMark = @() line_style.__merge({
    rendObj = ROBJ_DTEXT
    color = color_func()
    text = text
  })

  return @() {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    pos = pos
    size = SIZE_TO_CONTENT
    watch = state_var
    children = state_var.value ? [textMark] : null
  }
}

return function(line_style, color_func) {
  return @() {
    watch = [ IsSightLocked ]
    children = [
      drawMark(IsCommanderViewAimModeActive, ::loc("hud/commanderViewAimMode"), [sw(10), sh(10)], line_style, color_func)
      drawMark(IsSightLocked, ::loc("hud/autoTargetTracking"), [sw(10), sh(12)], line_style, color_func)
    ]
  }
}
