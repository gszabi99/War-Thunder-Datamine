//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

// DEPRECATED
// Interface of ControlsPreset and ControlsManager for controls.nut
// TODO: Rewrite controls with new ControlsPreset and ControlsManager classes


::get_shortcuts <- function get_shortcuts(list, preset = null) {
  if (preset == null)
    preset = ::g_controls_manager.getCurPreset()

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


::set_shortcuts <- function set_shortcuts(shortcutList, nameList, preset = null) {
  if (preset == null)
    preset = ::g_controls_manager.getCurPreset()

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

  if (preset == ::g_controls_manager.getCurPreset())
    ::g_controls_manager.commitControls()
}


let joystick_params_template = {
  getAxis = function(idx) {
    let curPreset = ::g_controls_manager.getCurPreset()
    let name = ::get_axis_name(idx)
    return name != null ? curPreset.getAxis(name) : curPreset.getDefaultAxis()
  }

  getMouseAxis = function(idx) {
    if (idx < 0)
      return ""

    let curPreset = ::g_controls_manager.getCurPreset()
    foreach (axisName, axis in curPreset.axes)
      if (getTblValue("mouseAxisId", axis, -1) == idx)
        return axisName

    return ""
  }

  setMouseAxis = function(idx, name) {
    if (idx < 0)
      return

    let curPreset = ::g_controls_manager.getCurPreset()
    foreach (_axisName, axis in curPreset.axes)
      if (getTblValue("mouseAxisId", axis, -1) == idx)
        axis["mouseAxisId"] <- -1

    if (name == "")
      return

    let axis = curPreset.getAxis(name)
    axis.mouseAxisId <- idx
  }

  resetAxis = function(idx) {
    let curPreset = ::g_controls_manager.getCurPreset()
    let name = ::get_axis_name(idx)
    if (name != null)
      curPreset.resetAxis(name)
    ::g_controls_manager.commitControls()
  }

  applyParams = function(_joy) {
    ::g_controls_manager.commitControls()
  }

  bindAxis = function(idx, realAxisIdx) {
    let name = ::get_axis_name(idx)
    let axis = ::g_controls_manager.getCurPreset().getAxis(name)
    axis.axisId = realAxisIdx
    ::g_controls_manager.commitControls()
  }

  setFrom = function(params) {
    ::u.extend(this, params)
  }
}
::u.extend(joystick_params_template, ::ControlsPreset.getDefaultParams())


::JoystickParams <- function JoystickParams() {
  return ::u.copy(joystick_params_template)
}


::joystick_get_cur_settings <- function joystick_get_cur_settings() {
  let result = ::JoystickParams()
  ::u.extend(result, ::g_controls_manager.getCurPreset().params)
  return result
}


::joystick_set_cur_settings <- function joystick_set_cur_settings(other) {
  let params = ::g_controls_manager.getCurPreset().params
  foreach (name, value in other)
    if (!::u.isFunction(value))
      params[name] <- value
  ::g_controls_manager.commitControls()
}


::set_controls_preset <- function set_controls_preset(presetPath) {
  if (presetPath != "")
    ::g_controls_manager.setCurPreset(::ControlsPreset(presetPath))
  else
    ::g_controls_manager.notifyPresetModified()
}

::get_controls_preset <- function get_controls_preset() {
  return ""
}

::restore_default_controls <- function restore_default_controls(_preset) {
  // Dummy. Preset loading performed by set_controls_preset later
}

::joystick_set_cur_values <- function joystick_set_cur_values(_settings) {
  // Settings already changed by JoystickParams
  ::g_controls_manager.commitControls()
}
