local shortcuts = require("shortcuts.nut")
local colors = require("reactiveGui/style/colors.nut")

local hintTags = {
  shortcut = function(config, override){
    return shortcuts(config, override)
  }

  text = function(config, override){
    return {
      rendObj = ROBJ_DTEXT
      color = colors.menu.commonTextColor
      font = Fonts.medium_text_hud
      text = config.text
    }.__update(override)
  }
}

local getSlice = function(slice, override)
{
  if("shortcut" in slice)
    return hintTags.shortcut(slice.shortcut, override)
  if("text" in slice)
    return hintTags.text(slice, override)

  return null
}

local getHintBySlices = function(slices, override)
{
  return {
    size = [SIZE_TO_CONTENT, SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER

    children = slices.map(@(slice) getSlice(slice, override))
  }
}

return getHintBySlices


