//checked for plus_string
from "%scripts/dagui_library.nut" import *

let Flags = {
  NONE = 0,
  WITHOUT_MODIFIERS = 1
}

let replaceAxes = function(ctrlGroup, replacements, flags = Flags.NONE) {
  local isUpdated = false
  let groupAxes = []
  foreach (item in ::shortcutsList)
    if (item.type == CONTROL_TYPE.AXIS && (item.checkGroup & ctrlGroup))
      groupAxes.append(item.id)

  let controls = ::g_controls_manager.getCurPreset()
  foreach (axisName, axis in controls.axes) {
    if (groupAxes.indexof(axisName) == null || axis?.axisId == null)
      continue
    if (flags & Flags.WITHOUT_MODIFIERS) {
      let modifiers = controls.hotkeys?[axisName] ?? []
      if (modifiers.len() != 0)
        continue
    }
    let replacement = replacements?[axis.axisId]
    if (replacement != null) {
      axis.axisId = replacement
      isUpdated = true
    }
  }
  ::g_controls_manager.commitControls()
  return isUpdated
}

let swapGamepadSticks = function(ctrlGroup, flags = Flags.NONE) {
  let replacements = {
    [::AXIS.LEFTSTICK_X] = ::AXIS.RIGHTSTICK_X,
    [::AXIS.LEFTSTICK_Y] = ::AXIS.RIGHTSTICK_Y,
    [::AXIS.RIGHTSTICK_X] = ::AXIS.LEFTSTICK_X,
    [::AXIS.RIGHTSTICK_Y] = ::AXIS.LEFTSTICK_Y,
  }
  return replaceAxes(ctrlGroup, replacements, flags)
}

return {
  Flags = Flags,
  swapGamepadSticks = swapGamepadSticks
}
