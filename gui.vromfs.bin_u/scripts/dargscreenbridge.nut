from "colorCorrector" import getRgbStrFromHsv
from "eventbus" import eventbus_subscribe
from "string" import format
from "%scripts/dagui_library.nut" import *
import "%appGlobals/style/cssColors.nut" as cssColors




let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let locText = @(text) type(text) != "string" ? "" : text.startswith("#") ? loc(text.slice(1)) : text


let resolveColorTags = @(text) "<color=".join(text.split("<color=@").map(function(part, idx) {
  if (idx == 0)
    return part
  let close = part.indexof(">") ?? part.len()
  let color = cssColors?[part.slice(0, close)]
  return "".concat(type(color) == "integer" ? format("#%08X", color) : $"@{part.slice(0, close)}", part.slice(close))
}))


let mkComboItems = @(items) (items ?? []).map(function(item) {
  let { text = null, image = null, images = null, hue = null, hues = null, rgb = null, enabled = true,
    tooltip = null, fontSize = null } = type(item) == "string" ? { text = item } : item
  return {
    text = locText(text)
    fontSize
    images = type(image) == "string" ? [{ image }] : images
    hueColor = rgb ?? (hue == null ? null : getRgbStrFromHsv(hue, item?.sat ?? 0.7, item?.val ?? 0.7))
    smallHueColor = hues?.map(@(h) { color = getRgbStrFromHsv(h, 1.0, 1.0) })
    enabled
    tooltip = locText(tooltip)
  }
})


let mkControlObj = @(handler, id) {
  id
  isValid = @() handler.isValid()
  getValue = @() handler.getControlValue(id)
  setValue = @(value) handler.setControlValue(id, value)
}


let subscribeScreenActions = @(eventName, handlerClass, actions) eventbus_subscribe(eventName, function(p) {
  let handler = handlersManager.findHandlerClassInScene(handlerClass)
  if (handler != null)
    actions?[p.action](handler, p)
})

return freeze({
  locText
  resolveColorTags
  mkComboItems
  mkControlObj
  subscribeScreenActions
})
