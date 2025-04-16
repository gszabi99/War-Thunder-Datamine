from "%scripts/dagui_natives.nut" import get_axis_index
from "%scripts/dagui_library.nut" import *

let { joystickGetCurSettings, getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")
let { stripTags } = require("%sqstd/string.nut")

function getLocalizedShortcutName(shortcutId) {
  return loc($"hotkeys/{shortcutId}")
}

let axisModifiers = ["_rangeMin", "_rangeMax"]

let getLocaliazedPS4ControlName = @(text) loc($"xinp/{text}", "")

function getLocalizedXinpControlName(text, deviceId) {
  if (deviceId != STD_KEYBOARD_DEVICE_ID)
    return getLocaliazedPS4ControlName(text)
  return ""
}

function getSeparatedControlLocId(text) {
  local txt = text
  local index_txt = ""

  if (txt.indexof("Button ") == 0) 
    index_txt = "".concat(" ", txt.slice("Button ".len()))
  else if (txt.indexof("Button") == 0) 
    index_txt = "".concat(" ", txt.slice("Button".len()))

  if (index_txt != "")
    txt = $"{loc("key/Button")}{index_txt}"

  return txt
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

function addHotkeyTxt(hotkeyTxt, baseTxt = "", colored = true) {
  hotkeyTxt = colored ? colorize("hotkeyColor", hotkeyTxt) : hotkeyTxt
  return loc("ui/comma").join([ baseTxt, hotkeyTxt ], true)
}

let getShortcutText = kwarg(function getShortcutText(shortcuts,
  shortcutId, cantBeEmpty = true, strip_tags = false, preset = null, colored = true) {
  if (!(shortcutId in shortcuts))
    return ""

  preset = preset || getCurControlsPreset()
  local data = ""
  for (local i = 0; i < shortcuts[shortcutId].len(); i++) {
    let textArr = []
    let sc = shortcuts[shortcutId][i]

    for (local j = 0; j < sc.dev.len(); j++)
      textArr.append(getLocalizedControlName(preset, sc.dev[j], sc.btn[j]))

    if (textArr.len() == 0)
      continue

    let text = " + ".join(textArr)
    data = addHotkeyTxt(strip_tags ? stripTags(text) : text, data, colored)
  }

  if (cantBeEmpty && data == "")
    data = "---"

  return data
})

let getFirstShortcutText = @(shortcutId) getShortcutText({
  shortcuts = getShortcuts([ shortcutId ])
  shortcutId = 0
  cantBeEmpty = false
  colored = false
})

function remapAxisName(preset, axisId) {
  let text = preset.getAxisName(axisId)
  if (text == null)
    return "?"

  if (text.indexof("Axis ") == 0) 
    return "".concat(loc("composite/axis"), text.slice("Axis ".len()))
  else if (text.indexof("Axis") == 0) 
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
  getShortcutText
  addHotkeyTxt
}