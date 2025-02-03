from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")

let hintTags = require("hintTags.nut")

let hintsCache = {}

let createHintContent = function(text, override) {
  let { rows = [] } = cross_call.getHintConfig(text)

  return {
    size = [SIZE_TO_CONTENT, SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    valign = ALIGN_CENTER

    children = rows.map(@(hint) hintTags(hint.slices, override))
  }
}

let getHintContent = function(hintString, override = {}) {
  if (hintString in hintsCache)
    return hintsCache.hintString

  return createHintContent(hintString, override)
}

return getHintContent