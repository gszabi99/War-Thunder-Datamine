from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")

// Functions in this file called from C++ code

::is_last_load_controls_succeeded <- false

::load_controls <- function load_controls(blkOrPresetPath) {
  let otherPreset = ::ControlsPreset(blkOrPresetPath)
  if (otherPreset.isLoaded && otherPreset.hotkeys.len() > 0) {
    ::g_controls_manager.setCurPreset(otherPreset)
    ::is_last_load_controls_succeeded = true
  }
  else {
    log($"ControlsGlobals: Prevent setting incorrect preset: {blkOrPresetPath}")
    showInfoMsgBox($"{loc("msgbox/errorLoadingPreset")}: {blkOrPresetPath}")
    ::is_last_load_controls_succeeded = false
  }
}

function controlsFixDeviceMapping() {
  ::g_controls_manager.fixDeviceMapping()
  ::g_controls_manager.commitControls()
}

eventbus_subscribe("controls_fix_device_mapping", @(_) controlsFixDeviceMapping())
