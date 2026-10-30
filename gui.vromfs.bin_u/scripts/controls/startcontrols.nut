from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%sqstd/platform.nut" import isSony, isXbox
from "%appGlobals/clientState/platform.nut" import isPlatformShieldTv
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

const PS4_CONTROLS_MODE_ACTIVATE = "ps4ControlsAdvancedModeActivated"

function switchControlsMode(value) {
  saveLocalAccountSettings(PS4_CONTROLS_MODE_ACTIVATE, value)
}

function gui_start_advanced_controls(_ = null) {
  if (!hasFeature("ControlsAdvancedSettings"))
    return
  loadHandler(get_gui_handler("Hotkeys"))
}

function gui_start_controls_console(_ = null) {
  if (!hasFeature("ControlsAdvancedSettings"))
    return

  loadHandler(get_gui_handler("ControlsConsole"))
}

function gui_start_controls() {
  if (isSony || isXbox || isPlatformShieldTv()) {
    if (loadLocalAccountSettings(PS4_CONTROLS_MODE_ACTIVATE, true)) {
      gui_start_controls_console()
      return
    }
  }

  gui_start_advanced_controls()
}

function gui_start_controls_type_choice() {
  if (!hasFeature("ControlsDeviceChoice"))
    return

  loadHandler(get_gui_handler("ControlType"))
}

eventbus_subscribe("gui_start_advanced_controls", gui_start_advanced_controls)
eventbus_subscribe("gui_start_controls_console", gui_start_controls_console)

return freeze({
  switchControlsMode
  gui_start_controls
  gui_start_controls_type_choice
})