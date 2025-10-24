from "%rGui/globals/ui_library.nut" import *

let { getShortcut } = require("%rGui/hints/shortcuts.nut")
let colors = require("%rGui/style/colors.nut")
let { getFontName } = require("fonts")

let hintTags = {
  shortcut = getShortcut
  text = function(config, override) {
    let { font = Fonts.medium_text_hud, scale = 1 } = override
    return {
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

function getSlice(slice, override, addChild = []) {
  if ("shortcut" in slice)
    return hintTags.shortcut(slice.shortcut, override, addChild)
  if ("text" in slice)
    return hintTags.text(slice, override)

  return null
}

function getHintBySlices(slices, override, addChild = []) {
  let children = slices.map(@(slice) getSlice(slice, override, addChild))
    .filter(@(slice) slice != null)
  if (children.len() == 0)
    return null

  return {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children
  }
}

return getHintBySlices
