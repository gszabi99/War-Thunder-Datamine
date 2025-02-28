from "%scripts/dagui_natives.nut" import get_axis_index
from "%scripts/dagui_library.nut" import *

let { joystickGetCurSettings, getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")

function getLocalizedShortcutName(shortcutId) {
  return loc($"hotkeys/{shortcutId}")
}

let axisModifiers = ["_rangeMin", "_rangeMax"]

let getFirstShortcutText = @(shortcutId) ::get_shortcut_text({
  shortcuts = getShortcuts([ shortcutId ])
  shortcutId = 0
  cantBeEmpty = false
  colored = false
})

let getLocaliazedPS4ControlName = @(text) loc($"xinp/{text}", "")

function remapAxisName(preset, axisId) {
  let text = preset.getAxisName(axisId)
  if (text == null)
    return "?"

  if (text.indexof("Axis ") == 0) //"Axis 1" in "Axis" and "1"
    return "".concat(loc("composite/axis"), text.slice("Axis ".len()))
  else if (text.indexof("Axis") == 0) //"Axis1" in "Axis" and "1"
    return "".concat(loc("composite/axis"), text.slice("Axis".len()))

  local locText = getLocaliazedPS4ControlName(text)
  if (locText != "")
    return locText

  locText = loc($"joystick/{text}", "")
  if (locText != "")
    return locText

  locText = loc($"key/{text}", "")
  if (locText != "")
    return locText

  return text
}

function getAxisTextOrAxisName(shortcutId) {
  let comma = loc("ui/comma")
  let shortcuts = []
  let joyParams = joystickGetCurSettings()
  let axis = joyParams.getAxis(get_axis_index(shortcutId))
  if (axis.axisId >= 0)
    shortcuts.append(remapAxisName(getCurControlsPreset(), axis.axisId))

  local activateText = getFirstShortcutText(shortcutId)
  if (activateText != "")
    activateText = $"{activateText} + "
  let modifyText = comma.join(
    axisModifiers.map(@(mod) getFirstShortcutText($"{shortcutId}{mod}")), true)
  shortcuts.append($"{activateText}{modifyText}")
  let text = comma.join(shortcuts, true)
  return text != "" ? text : loc($"controls/{shortcutId}")
}

function getSeparatedControlLocId(text) {
  local txt = text
  local index_txt = ""

  if (txt.indexof("Button ") == 0) //"Button 1" in "Button" and "1"
    index_txt = "".concat(" ", txt.slice("Button ".len()))
  else if (txt.indexof("Button") == 0) //"Button1" in "Button" and "1"
    index_txt = "".concat(" ", txt.slice("Button".len()))

  if (index_txt != "")
    txt = $"{loc("key/Button")}{index_txt}"

  return txt
}

function getLocalizedXinpControlName(text, deviceId) {
  if (deviceId != STD_KEYBOARD_DEVICE_ID)
    return getLocaliazedPS4ControlName(text)
  return ""
}

function getLocTextControlName(text) {
  let locText = loc($"key/{text}", "")
  if (locText != "")
    return locText

  return getSeparatedControlLocId(text)
}

function getLocalizedControlName(preset, deviceId, buttonId) {
  let text = preset.getButtonName(deviceId, buttonId)
  let locText = getLocalizedXinpControlName(text, deviceId)
  if (locText != "")
    return locText

  return getLocTextControlName(text)
}

function getShortLocalizedControlName(preset, deviceId, buttonId) {
  let text = preset.getButtonName(deviceId, buttonId)
  local locText = getLocalizedXinpControlName(text, deviceId)
  if (locText != "")
    return locText

  locText = loc($"key/{text}/short", "")
  if (locText != "")
    return locText

  return getLocTextControlName(text)
}

return {
  getLocalizedShortcutName
  getAxisTextOrAxisName
  getLocaliazedPS4ControlName
  getLocalizedControlName
  getShortLocalizedControlName
  remapAxisName
}