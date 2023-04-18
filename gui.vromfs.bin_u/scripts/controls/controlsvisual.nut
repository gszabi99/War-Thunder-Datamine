//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

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
  let joyParams = ::JoystickParams()
  joyParams.setFrom(::joystick_get_cur_settings())
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

return {
  getLocalizedShortcutName
  getAxisTextOrAxisName
}