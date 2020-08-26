local { secondsToMilliseconds, minutesToSeconds } = require("scripts/time.nut")

local hotasPS4DevId = "044F:B67B"
local hotasXONEDevId = "044F:B68C"

local function askHotasPresetChange()
{
  if (!::is_ps4_or_xbox || ::loadLocalByAccount("wnd/detectThrustmasterHotas", false))
    return

  local preset = ::g_controls_presets.getCurrentPreset()
  local is_ps4_non_gamepad_preset = ::is_platform_ps4
    && preset.name.indexof("dualshock4") == null
    && preset.name.indexof("default") == null
  local is_xboxone_non_gamepad_preset = ::is_platform_xboxone
    && preset.name.indexof("xboxone_ma") == null
    && preset.name.indexof("xboxone_simulator") == null

  ::saveLocalByAccount("wnd/detectThrustmasterHotas", true)

  if (is_ps4_non_gamepad_preset && is_xboxone_non_gamepad_preset)
    return

  local questionLocId =
    ::is_platform_ps4 ? "msgbox/controller_hotas4_found" :
    ::is_platform_xboxone ? "msgbox/controller_hotas_one_found" :
    ::unreachable()

  local mainAction = function() {
    local presetName =
      ::is_platform_ps4 ? "thrustmaster_hotas4" :
      ::is_platform_xboxone ? "xboxone_thrustmaster_hotas_one" :
      ::unreachable()
    ::apply_joy_preset_xchange(::g_controls_presets.getControlsPresetFilename(presetName))
  }

  ::g_popups.add(
    null,
    ::loc(questionLocId),
    mainAction,
    [{
      id = "yes",
      text = ::loc("msgbox/btn_yes"),
      func = mainAction
    },
    { id = "no",
      text = ::loc("msgbox/btn_no")
    }],
    null,
    null,
    secondsToMilliseconds(minutesToSeconds(10))
  )
}

return {
  checkJoystickThustmasterHotas = function(changePreset = true) {
    local deviceId =
      ::is_platform_ps4 ? hotasPS4DevId :
      ::is_platform_xboxone ? hotasXONEDevId :
      null

    if (deviceId == null || !::g_login.isLoggedIn())
      return false

    if (!::is_device_connected(deviceId))
      return false

    return changePreset ? askHotasPresetChange() : true
  }
}