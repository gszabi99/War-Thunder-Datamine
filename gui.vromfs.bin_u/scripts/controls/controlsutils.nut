from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let time = require("%scripts/time.nut")
let controllerState = require("controllerState")
let { send } = require("eventbus")
let { isPlatformSony, isPlatformXboxOne, isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")
let { get_gui_option } = require("guiOptions")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

::classic_control_preset <- "classic"
::shooter_control_preset <- "shooter"
::thrustmaster_hotas_one_preset_type <- "thrustmaster_hotas_one"

::recomended_control_presets <- [
  ::classic_control_preset
  ::shooter_control_preset
]

if (isPlatformXboxOne)
  ::recomended_control_presets.append(::thrustmaster_hotas_one_preset_type)

::g_controls_utils <- {
  [PERSISTENT_DATA_PARAMS] = ["eventHandler"]
  eventHandler = null

  getControlsList = kwarg(function getControlsList(unitType = null, classType = null, unitTags = [])
  {
    local isHeaderPassed = true
    local isSectionPassed = true
    let controlsList = ::shortcutsList.filter(function(sc)
    {
      if (sc.type != CONTROL_TYPE.HEADER && sc.type != CONTROL_TYPE.SECTION)
      {
        if (isHeaderPassed && isSectionPassed && "showFunc" in sc)
          return sc.showFunc()

        return isHeaderPassed && isSectionPassed
      }

      if (sc.type == CONTROL_TYPE.HEADER) //unitType and other params below exist only in header
      {
        isHeaderPassed = sc?.unitTypes.contains(unitType) ?? true
        isSectionPassed = true // reset previous sectino setting

        if (isHeaderPassed && classType != null)
          isHeaderPassed = sc?.unitClassTypes == null || isInArray(classType, sc.unitClassTypes)

        if (isHeaderPassed)
          isHeaderPassed = (unitTags.len() == 0 && sc?.unitTag == null) || isInArray(sc?.unitTag ?? "", unitTags)
      }
      else if (sc.type == CONTROL_TYPE.SECTION)
        isSectionPassed = isHeaderPassed

      if ("showFunc" in sc)
      {
        if (sc.type == CONTROL_TYPE.HEADER && isHeaderPassed)
          isHeaderPassed = sc.showFunc()
        else if (sc.type == CONTROL_TYPE.SECTION && isSectionPassed)
          isSectionPassed = sc.showFunc()
      }

      return isHeaderPassed && isSectionPassed
    })

    return controlsList
  })

  function getMouseUsageMask()
  {
    let usage = ::g_aircraft_helpers.getOptionValue(
      ::USEROPT_MOUSE_USAGE)
    let usageNoAim = ::g_aircraft_helpers.getOptionValue(
      ::USEROPT_MOUSE_USAGE_NO_AIM)
    return (usage ? usage : 0) | (usageNoAim ? usageNoAim : 0)
  }

  function checkOptionValue(optName, checkValue)
  {
    let val = get_gui_option(optName)
    if (val != null)
      return val == checkValue
    return ::get_option(optName).value == checkValue
  }

  function isShortcutEqual(sc1, sc2) {
    if (sc1.len() != sc2.len())
      return false

    foreach(_i, sb in sc2)
      if (!::is_bind_in_shortcut(sb, sc1))
        return false
    return true
  }

  function restoreShortcuts(scList, scNames) {
    let changeList = []
    let changeNames = []
    let curScList = ::get_shortcuts(scNames)
    foreach(idx, sc in curScList)
    {
      let prevSc = scList[idx]
      if (!isShortcutMapped(prevSc))
        continue

      if (isShortcutEqual(sc, prevSc))
        continue

      changeList.append(prevSc)
      changeNames.append(scNames[idx])
    }
    if (!changeList.len())
      return

    ::set_controls_preset("")
    ::set_shortcuts(changeList, changeNames)
    ::broadcastEvent("ControlsPresetChanged")
  }

  function isShortcutMapped(shortcut) {
    foreach (button in shortcut)
      if (button && button.dev.len() >= 0)
        foreach(d in button.dev)
          if (d > 0 && d <= STD_GESTURE_DEVICE_ID)
              return true
    return false
  }
}

::g_script_reloader.registerPersistentDataFromRoot("g_controls_utils")

::on_connected_controller <- function on_connected_controller()
{
  //calls from c++ code, no event on PS4 or XBoxOne
  send("updateExtWatched", { haveXinputDevice = ::have_xinput_device() })
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

local is_keyboard_or_mouse_connected_before = false

let on_controller_event = function()
{
  if (!hasFeature("ControlsDeviceChoice") || !hasFeature("ControlsPresets"))
    return
  let is_keyboard_or_mouse_connected = controllerState.is_keyboard_connected()
    || controllerState.is_mouse_connected()
  if (is_keyboard_or_mouse_connected_before == is_keyboard_or_mouse_connected)
    return
  is_keyboard_or_mouse_connected_before = is_keyboard_or_mouse_connected;
  if (!is_keyboard_or_mouse_connected || !::isInMenu())
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

if (::g_controls_utils.eventHandler && controllerState?.remove_event_handler)
  controllerState.remove_event_handler(::g_controls_utils.eventHandler)

::g_controls_utils.eventHandler = on_controller_event
if (controllerState?.add_event_handler)
  controllerState.add_event_handler(::g_controls_utils.eventHandler)

::get_controls_preset_by_selected_type <- function get_controls_preset_by_selected_type(cType = "")
{
  let presets = isPlatformSony ? {
    [::classic_control_preset] = "default",
    [::shooter_control_preset] = "dualshock4"
  } : is_platform_xbox ? {
    [::classic_control_preset] = "xboxone_simulator",
    [::shooter_control_preset] = "xboxone_ma",
    [::thrustmaster_hotas_one_preset_type] = "xboxone_thrustmaster_hotas_one"
  } : isPlatformSteamDeck ? {
    [::classic_control_preset] = "steamdeck_simulator",
    [::shooter_control_preset] = "steamdeck_ma"
  } : {
    [::classic_control_preset] = "keyboard",
    [::shooter_control_preset] = "keyboard_shooter"
  }

  local preset = ""
  if (cType in presets) {
    preset = presets[cType]
  } else {
    ::script_net_assert_once("wrong controls type", "Passed wrong controls type")
  }

  preset = ::g_controls_presets.parsePresetName(preset)
  preset = ::g_controls_presets.getHighestVersionPreset(preset)
  return preset
}

::on_lost_controller <- function on_lost_controller() {
  send("updateExtWatched", { haveXinputDevice = ::have_xinput_device() })
  ::add_msg_box("cannot_session", loc("pl1/lostController"), [["ok", function() {}]], "ok")
}
