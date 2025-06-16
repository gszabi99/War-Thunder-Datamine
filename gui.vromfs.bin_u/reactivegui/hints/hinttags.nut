from "%rGui/globals/ui_library.nut" import *

let { getShortcut } = require("shortcuts.nut")
let colors = require("%rGui/style/colors.nut")

let hintTags = {
  shortcut = getShortcut
  text = function(config, override) {
    return {
      size = [SIZE_TO_CONTENT, SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      children = config.text.map(@(text) {
        rendObj = ROBJ_TEXT
        color = colors.menu.commonTextColor
        font = Fonts.medium_text_hud
        text = text.textValue
      }.__update(override))
    }
  }
}

let getSlice = function(slice, override) {
  if ("shortcut" in slice)
    return hintTags.shortcut(slice.shortcut, override)
  if ("text" in slice)
    return hintTags.text(slice, override)

  return null
}

let getHintBySlices = function(slices, override) {
  return {
    size = [SIZE_TO_CONTENT, SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER

    children = slices.map(@(slice) getSlice(slice, override))
  }
}

return getHintBySlices


