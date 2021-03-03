local { IsCommanderViewAimModeActive } = require("tankState.nut")

local commandeViewAimMode = function(line_style, color_func) {
  local textMark = @() line_style.__merge({
    rendObj = ROBJ_DTEXT
    color = color_func()
    text = ::loc("hud/commanderViewAimMode")
  })

  return @() {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    pos = [sw(10), sh(10)]
    size = SIZE_TO_CONTENT
    watch = IsCommanderViewAimModeActive
    children = IsCommanderViewAimModeActive.value ? [textMark] : null
  }
}

return function(line_style, color_func) {
  return {
    children = [
      commandeViewAimMode(line_style, color_func)
    ]
  }
}
