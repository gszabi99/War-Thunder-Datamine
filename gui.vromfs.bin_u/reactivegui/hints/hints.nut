from "%rGui/globals/ui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")
let cross_call = require("%rGui/globals/cross_call.nut")
let hintTags = require("hintTags.nut")

let hintsCache = {}

function createHintContent(text, override) {
  let { skipDeviceIds = {} } = override
  let { rows = [] } = cross_call.getHintConfig(text, { skipDeviceIds })

  let children = rows.map(@(hint) hintTags(hint.slices, override))
    .filter(@(hint) hint != null)
  return children.len() == 0 ? null
    : {
        size = SIZE_TO_CONTENT
        flow = FLOW_VERTICAL
        valign = ALIGN_CENTER
        children
      }
}

function getHintContent(hintString, override = {}) {
  if (hintString in hintsCache)
    return hintsCache[hintString]

  let hint = createHintContent(hintString, override)
  hintsCache[hintString] <- hint
  return hint
}

eventbus_subscribe("controlsChanged", @(_) hintsCache.clear())

return getHintContent