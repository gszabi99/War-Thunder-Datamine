//checked for plus_string
from "%scripts/dagui_library.nut" import *
from "modules" import on_module_unload


let time = require("%scripts/time.nut")
let controllerState = require("controllerState")
let { isPlatformSony, isPlatformXboxOne, isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")
let { get_gui_option } = require("guiOptions")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { subscribe } = require("eventbus")
let { DeviceType, register_for_devices_change } = require("%xboxLib/impl/input.nut")

const CLASSIC_PRESET = "classic"
const SHOOTER_PRESET = "shooter"
const THRUSTMASTER_HOTAS_ONE_PERESET = "thrustmaster_hotas_one"

let recomendedControlPresets = [
  CLASSIC_PRESET
  SHOOTER_PRESET
]
if (isPlatformXboxOne)
  recomendedControlPresets.append(THRUSTMASTER_HOTAS_ONE_PERESET)

let presetsNamesByTypes =
  isPlatformSony ? {
    [CLASSIC_PRESET] = "default",
    [SHOOTER_PRESET] = "dualshock4"
  }
  : is_platform_xbox ? {
    [CLASSIC_PRESET] = "xboxone_simulator",
    [SHOOTER_PRESET] = "xboxone_ma",
    [THRUSTMASTER_HOTAS_ONE_PERESET] = "xboxone_thrustmaster_hotas_one"
  }
  : isPlatformSteamDeck ? {
    [CLASSIC_PRESET] = "steamdeck_simulator",
    [SHOOTER_PRESET] = "steamdeck_ma"
  }
  : {
    [CLASSIC_PRESET] = "keyboard",
    [SHOOTER_PRESET] = "keyboard_shooter"
  }

let function getMouseUsageMask() {
  let usage = ::g_aircraft_helpers.getOptionValue(::USEROPT_MOUSE_USAGE)
  let usageNoAim = ::g_aircraft_helpers.getOptionValue(::USEROPT_MOUSE_USAGE_NO_AIM)
  return (usage ?? 0) | (usageNoAim ?? 0)
}

let function checkOptionValue(optName, checkValue) {
  let val = get_gui_option(optName)
  if (val != null)
    return val == checkValue
  return ::get_option(optName).value == checkValue
}

let function getControlsList(unitType, unitTags = []) {
  local isHeaderPassed = true
  local isSectionPassed = true
  let controlsList = ::shortcutsList.filter(function(sc) {
    if (sc.type != CONTROL_TYPE.HEADER && sc.type != CONTROL_TYPE.SECTION) {
      if (isHeaderPassed && isSectionPassed && "showFunc" in sc)
        return sc.showFunc()

      return isHeaderPassed && isSectionPassed
    }

    if (sc.type == CONTROL_TYPE.HEADER) { //unitType and other params below exist only in header
      isHeaderPassed = sc?.unitTypes.contains(unitType) ?? true
      isSectionPassed = true // reset previous sectino setting

      if (isHeaderPassed)
        isHeaderPassed = unitTags.len() == 0 || sc?.unitTag == null || isInArray(sc.unitTag, unitTags)
    }
    else if (sc.type == CONTROL_TYPE.SECTION)
      isSectionPassed = isHeaderPassed

    if ("showFunc" in sc) {
      if (sc.type == CONTROL_TYPE.HEADER && isHeaderPassed)
        isHeaderPassed = sc.showFunc()
      else if (sc.type == CONTROL_TYPE.SECTION && isSectionPassed)
        isSectionPassed = sc.showFunc()
    }

    return isHeaderPassed && isSectionPassed
  })

  return controlsList
}

let function onJoystickConnected() {
  updateExtWatched({ haveXinputDevice = ::have_xinput_device() })
  if (!::isInMenu() || !hasFeature("ControlsDeviceChoice"))
    return
  let action = function() { ::gui_start_controls_type_choice() }
  let buttons = [{
      id = "change_preset",
      text = loc("msgbox/btn_yes"),
      func = action
    },
    { id = "cancel",
      text = loc("msgbox/btn_no"),
      func = null
    }]

  ::g_popups.add(
    loc("popup/newcontroller"),
    loc("popup/newcontroller/message"),
    action,
    buttons,
    null,
    null,
    time.secondsToMilliseconds(time.minutesToSeconds(10))
  )
}

local isKeyboardOrMouseConnectedBefore = false

let function onControllerEvent() {
  if (!hasFeature("ControlsDeviceChoice") || !hasFeature("ControlsPresets"))
    return
  let isKeyboardOrMouseConnected = controllerState.is_keyboard_connected()
    || controllerState.is_mouse_connected()
  if (isKeyboardOrMouseConnectedBefore == isKeyboardOrMouseConnected)
    return
  isKeyboardOrMouseConnectedBefore = isKeyboardOrMouseConnected
  if (!isKeyboardOrMouseConnected || !::isInMenu())
    return
  let action = function() { ::gui_modal_controlsWizard() }
  let buttons = [{
      id = "change_preset",
      text = loc("msgbox/btn_yes"),
      func = action
    },
    { id = "cancel",
      text = loc("msgbox/btn_no"),
      func = null
    }]

  ::g_popups.add(
    loc("popup/keyboard_or_mouse_connected"),
    loc("popup/keyboard_or_mouse_connected/message"),
    action,
    buttons,
    null,
    null,
    time.secondsToMilliseconds(time.minutesToSeconds(10))
  )
}

controllerState.add_event_handler(onControllerEvent)
on_module_unload(@(_) controllerState.remove_event_handler(onControllerEvent))

let function getControlsPresetBySelectedType(cType) {
  local preset = ""
  if (cType in presetsNamesByTypes) {
    preset = presetsNamesByTypes[cType]
  }
  else {
    ::script_net_assert_once("wrong controls type", "Passed wrong controls type")
  }

  preset = ::g_controls_presets.parsePresetName(preset)
  preset = ::g_controls_presets.getHighestVersionPreset(preset)
  return preset
}

local function onJoystickDisconnected() {
  updateExtWatched({ haveXinputDevice = ::have_xinput_device() })
  ::add_msg_box("cannot_session", loc("pl1/lostController"), [["ok", function() {}]], "ok")
}

subscribe("controls.joystickDisconnected", @(_) onJoystickDisconnected())
subscribe("controls.joystickConnected", @(_) onJoystickConnected())

local xboxInputDevicesData = persist("xboxInputDevicesData", @() { gamepads = 0, keyboards = 0, user_notified = false })

register_for_devices_change(function(device_type, count) {
  if (device_type == DeviceType.Gamepad)
    xboxInputDevicesData.gamepads = count
  if (device_type == DeviceType.Keyboard)
    xboxInputDevicesData.keyboards = count

  let shouldNotify = xboxInputDevicesData.gamepads == 0 && xboxInputDevicesData.keyboards == 0
  if (shouldNotify && !xboxInputDevicesData.user_notified) {
    xboxInputDevicesData.user_notified = true
    ::add_msg_box("no_input_devices", loc("pl1/lostController"),
      [
        ["ok", @() xboxInputDevicesData.user_notified = false]
      ], "ok")
  }
})

return {
  getControlsList
  getMouseUsageMask
  recomendedControlPresets
  checkOptionValue
  getControlsPresetBySelectedType
}