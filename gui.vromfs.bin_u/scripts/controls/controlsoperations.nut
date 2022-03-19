local Flags = {
  NONE = 0,
  WITHOUT_MODIFIERS = 1
}

local replaceAxes = function(ctrlGroup, replacements, flags = Flags.NONE) {
  local isUpdated = false
  local groupAxes = []
  foreach (item in ::shortcutsList)
    if ((item.checkGroup & ctrlGroup) && item.type == CONTROL_TYPE.AXIS)
      groupAxes.append(item.id)

  local controls = ::g_controls_manager.getCurPreset()
  foreach (axisName, axis in controls.axes) {
    if (groupAxes.indexof(axisName) == null || axis?.axisId == null)
      continue
    if (flags & Flags.WITHOUT_MODIFIERS) {
      local modifiers = controls.hotkeys?[axisName] ?? []
      if (modifiers.len() != 0)
        continue
    }
    local replacement = replacements?[axis.axisId]
    if (replacement != null) {
      axis.axisId = replacement
      isUpdated = true
    }
  }
  ::g_controls_manager.commitControls()
  return isUpdated
}

local swapGamepadSticks = function(ctrlGroup, flags = Flags.NONE) {
  local replacements = {
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
