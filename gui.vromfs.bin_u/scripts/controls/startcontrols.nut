from "%scripts/dagui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isPlatformSony, isPlatformXboxOne, isPlatformShieldTv
} = require("%scripts/clientState/platform.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")

const PS4_CONTROLS_MODE_ACTIVATE = "ps4ControlsAdvancedModeActivated"

function switchControlsMode(value) {
  saveLocalAccountSettings(PS4_CONTROLS_MODE_ACTIVATE, value)
}

function gui_start_advanced_controls(_ = null) {
  if (!hasFeature("ControlsAdvancedSettings"))
    return
  loadHandler(gui_handlers.Hotkeys)
}

function gui_start_controls_console(_ = null) {
  if (!hasFeature("ControlsAdvancedSettings"))
    return

  loadHandler(gui_handlers.ControlsConsole)
}

function gui_start_controls() {
  if (isPlatformSony || isPlatformXboxOne || isPlatformShieldTv()) {
    if (loadLocalAccountSettings(PS4_CONTROLS_MODE_ACTIVATE, true)) {
      gui_start_controls_console()
      return
    }
  }

  gui_start_advanced_controls()
}

function gui_start_controls_type_choice(onlyDevicesChoice = true) {
  if (!hasFeature("ControlsDeviceChoice"))
    return

  loadHandler(gui_handlers.ControlType, { onlyDevicesChoice = onlyDevicesChoice })
}

eventbus_subscribe("gui_start_advanced_controls", gui_start_advanced_controls)
eventbus_subscribe("gui_start_controls_console", gui_start_controls_console)

return {
  switchControlsMode
  gui_start_controls
  gui_start_controls_type_choice
}