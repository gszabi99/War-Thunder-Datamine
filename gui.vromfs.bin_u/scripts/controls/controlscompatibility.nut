from "%scripts/dagui_natives.nut" import get_axis_name
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let ControlsPreset = require("%scripts/controls/controlsPreset.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")
let { commitControls } = require("%scripts/controls/controlsManager.nut")

// DEPRECATED
// Interface of ControlsPreset and ControlsManager for controls.nut
// TODO: Rewrite controls with new ControlsPreset and ControlsManager classes


function getShortcuts(list, preset = null) {
  if (preset == null)
    preset = getCurControlsPreset()

  let result = []
  foreach (name in list) {
    let eventData = []

    let hotkey = preset.getHotkey(name)
    foreach (shortcut in hotkey) {
      local shortcutData = { dev = [], btn = [] }
      foreach (button in shortcut) {
        shortcutData.dev.append(button.deviceId)
        shortcutData.btn.append(button.buttonId)
      }
      eventData.append(shortcutData)
    }
    result.append(eventData)
  }
  return result
}


function setShortcutsAndSaveControls(shortcutList, nameList) {
  let preset = getCurControlsPreset()
  foreach (i, name in nameList) {
    let hotkey = []
    foreach (shortcut in shortcutList[i]) {
      let shortcutData = []

      let numButtons = min(shortcut.dev.len(), shortcut.btn.len())
      for (local j = 0; j < numButtons; j++)
        shortcutData.append({
          deviceId = shortcut.dev[j]
          buttonId = shortcut.btn[j]
        })

      hotkey.append(shortcutData)
    }
    preset.setHotkey(name, hotkey)
  }
  commitControls()
}


let joystick_params_template = {
  getAxis = function(idx) {
    let curPreset = getCurControlsPreset()
    let name = get_axis_name(idx)
    return name != null ? curPreset.getAxis(name) : curPreset.getDefaultAxis()
  }

  getMouseAxis = function(idx) {
    if (idx < 0)
      return ""

    let curPreset = getCurControlsPreset()
    foreach (axisName, axis in curPreset.axes)
      if (getTblValue("mouseAxisId", axis, -1) == idx)
        return axisName

    return ""
  }

  setMouseAxis = function(idx, name) {
    if (idx < 0)
      return

    let curPreset = getCurControlsPreset()
    foreach (_axisName, axis in curPreset.axes)
      if (getTblValue("mouseAxisId", axis, -1) == idx)
        axis["mouseAxisId"] <- -1

    if (name == "")
      return

    let axis = curPreset.getAxis(name)
    axis.mouseAxisId <- idx
  }

  resetAxis = function(idx) {
    let curPreset = getCurControlsPreset()
    let name = get_axis_name(idx)
    if (name != null)
      curPreset.resetAxis(name)
    commitControls()
  }

  bindAxis = function(idx, realAxisIdx) {
    let name = get_axis_name(idx)
    let axis = getCurControlsPreset().getAxis(name)
    axis.axisId = realAxisIdx
    commitControls()
  }

  setFrom = function(params) {
    u.extend(this, params)
  }
}
u.extend(joystick_params_template, ControlsPreset.getDefaultParams())


function JoystickParams() {
  return u.copy(joystick_params_template)
}

function joystickGetCurSettings() {
  let result = JoystickParams()
  result.setFrom(getCurControlsPreset().params)
  return result
}

function joystickSetCurSettings(other) {
  let params = getCurControlsPreset().params
  foreach (name, value in other)
    if (!u.isFunction(value) && params?[name] != value)
      params[name] <- value
}

return {
  setShortcutsAndSaveControls
  joystickSetCurSettings
  joystickGetCurSettings
  getShortcuts
}