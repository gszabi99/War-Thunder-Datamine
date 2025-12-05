from "%rGui/globals/ui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")
let cross_call = require("%rGui/globals/cross_call.nut")
let hintTags = require("%rGui/hints/hintTags.nut")

let hintsCache = {}

function createHintContent(text, override, addChildren = []) {
  let { skipDeviceIds = {} } = override
  let { rows = [] } = cross_call.getHintConfig(text, { skipDeviceIds })

  let children = rows.map(@(hint) hintTags(hint.slices, override, addChildren))
    .filter(@(hint) hint != null)

  if (children.len() == 0)
    return null

  return {
    flow = FLOW_VERTICAL
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children
  }
}

function getHintContent(hintString, override = {}, addChildren = []) {
  let cacheString = override.reduce(@(res, val, key) $"{res}{key}{val};", hintString)
  if (cacheString in hintsCache)
    return hintsCache[cacheString]

  let hint = createHintContent(hintString, override, addChildren)
  hintsCache[cacheString] <- hint
  return hint
}

eventbus_subscribe("controlsChanged", @(_) hintsCache.clear())

return getHintContent