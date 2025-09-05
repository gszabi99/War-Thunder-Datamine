from "%rGui/globals/ui_library.nut" import *

let { IsCommanderViewAimModeActive } = require("%rGui/hud/tankState.nut")
let { IsSightLocked } = require("%rGui/hud/targetTrackerState.nut")

let drawMark = @(state_var, text, pos, line_style, colorWatched) function() {

  let res = { watch = state_var }

  if (!state_var.value)
    return res

  let textMark = @() line_style.__merge({
    rendObj = ROBJ_TEXT
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
      drawMark(IsCommanderViewAimModeActive, loc("hud/commanderViewAimMode"), [sw(10), sh(10)], line_style, colorWatched)
      drawMark(IsSightLocked, loc("hud/autoTargetTracking"), [sw(10), sh(12)], line_style, colorWatched)
    ]
  }
}
