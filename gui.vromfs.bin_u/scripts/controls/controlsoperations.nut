from "%scripts/dagui_library.nut" import *
from "%scripts/controls/rawShortcuts.nut" import AXIS

let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")
let { commitControls } = require("%scripts/controls/controlsManager.nut")
let { shortcutsList } = require("%scripts/controls/shortcutsList/shortcutsList.nut")

let Flags = {
  NONE = 0,
  WITHOUT_MODIFIERS = 1
}

let replaceAxes = function(ctrlGroup, replacements, flags = Flags.NONE) {
  local isUpdated = false
  let groupAxes = []
  foreach (item in shortcutsList)
    if (item.type == CONTROL_TYPE.AXIS && (item.checkGroup & ctrlGroup))
      groupAxes.append(item.id)

  let controls = getCurControlsPreset()
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
  commitControls()
  return isUpdated
}

let swapGamepadSticks = function(ctrlGroup, flags = Flags.NONE) {
  let replacements = {
    [AXIS.LEFTSTICK_X] = AXIS.RIGHTSTICK_X,
    [AXIS.LEFTSTICK_Y] = AXIS.RIGHTSTICK_Y,
    [AXIS.RIGHTSTICK_X] = AXIS.LEFTSTICK_X,
    [AXIS.RIGHTSTICK_Y] = AXIS.LEFTSTICK_Y,
  }
  return replaceAxes(ctrlGroup, replacements, flags)
}

return {
  Flags = Flags,
  swapGamepadSticks = swapGamepadSticks
}
