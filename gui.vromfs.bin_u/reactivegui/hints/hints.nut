local hintTags = require("hintTags.nut")

local hintsCache = {}

local createHintContent = function(text, override)
{
  local config = ::cross_call.getHintConfig(text)

  return {
    size = [SIZE_TO_CONTENT, SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    valign = ALIGN_CENTER

    children = config.rows.map(@(hint) hintTags(hint.slices, override))
  }
}

local getHintContent = function(hintString, override = {}) {
  if (hintString in hintsCache)
    return hintsCache.hintString

  return createHintContent(hintString, override)
}

return getHintContent