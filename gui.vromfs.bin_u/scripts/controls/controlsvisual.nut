from "%scripts/dagui_library.nut" import *

let function getLocalizedShortcutName(shortcutId) {
  return loc($"hotkeys/{shortcutId}")
}

let axisModifiers = ["_rangeMin", "_rangeMax"]

let getFirstShortcutText = @(shortcutId) ::get_shortcut_text({
  shortcuts = ::get_shortcuts([ shortcutId ])
  shortcutId = 0
  cantBeEmpty = false
  colored = false
})

let function getAxisTextOrAxisName(shortcutId) {
  let comma = loc("ui/comma")
  let shortcuts = []
  let joyParams = ::joystick_get_cur_settings()
  let axis = joyParams.getAxis(::get_axis_index(shortcutId))
  if (axis.axisId >= 0)
    shortcuts.append(::remapAxisName(::g_controls_manager.getCurPreset(), axis.axisId))

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

let getLocaliazedPS4ControlName = @(text) loc($"xinp/{text}", "")

function getLocalizedControlName(preset, deviceId, buttonId) {
  let text = preset.getButtonName(deviceId, buttonId)
  if (deviceId != STD_KEYBOARD_DEVICE_ID) {
    let locText = getLocaliazedPS4ControlName(text)
    if (locText != "")
      return locText
  }

  let locText = loc($"key/{text}", "")
  if (locText != "")
    return locText

  return getSeparatedControlLocId(text)
}

return {
  getLocalizedShortcutName
  getAxisTextOrAxisName
  getLocaliazedPS4ControlName
  getLocalizedControlName
}