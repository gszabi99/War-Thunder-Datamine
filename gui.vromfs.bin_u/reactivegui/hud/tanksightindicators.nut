local { IsCommanderViewAimModeActive } = require("tankState.nut")
local { IsSightLocked } = require("reactiveGui/hud/targetTrackerState.nut")

local drawMark = @(state_var, text, pos, line_style, colorWatched) function() {

  local res = { watch = state_var }

  if (!state_var.value)
    return res

  local textMark = @() line_style.__merge({
    rendObj = ROBJ_DTEXT
    watch = colorWatched
    color = colorWatched.value
    text = text
  })

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    pos = pos
    size = SIZE_TO_CONTENT
    watch = state_var
    children = textMark
  })
}

return function(line_style, colorWatched) {
  return {
    children = [
      drawMark(IsCommanderViewAimModeActive, ::loc("hud/commanderViewAimMode"), [sw(10), sh(10)], line_style, colorWatched)
      drawMark(IsSightLocked, ::loc("hud/autoTargetTracking"), [sw(10), sh(12)], line_style, colorWatched)
    ]
  }
}
