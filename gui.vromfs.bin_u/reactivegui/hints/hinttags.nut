from "%rGui/globals/ui_library.nut" import *

let { getShortcut } = require("shortcuts.nut")
let colors = require("%rGui/style/colors.nut")
let { getFontName } = require("fonts")

let hintTags = {
  shortcut = getShortcut
  text = function(config, override) {
    let { font = Fonts.medium_text_hud, scale = 1 } = override
    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      children = config.text.map(@(text) {
        rendObj = ROBJ_TEXT
        color = colors.menu.commonTextColor
        font
        fontSize = getFontDefHt(getFontName(font)) * scale
        text = text.textValue
      }.__update(override))
    }
  }
}

function getSlice(slice, override) {
  if ("shortcut" in slice)
    return hintTags.shortcut(slice.shortcut, override)
  if ("text" in slice)
    return hintTags.text(slice, override)

  return null
}

function getHintBySlices(slices, override) {
  let children = slices.map(@(slice) getSlice(slice, override))
    .filter(@(slice) slice != null)
  return children.len() == 0 ? null
    : {
        size = SIZE_TO_CONTENT
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        children
      }
}

return getHintBySlices
