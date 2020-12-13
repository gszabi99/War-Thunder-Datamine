local { secondsToMilliseconds, minutesToSeconds } = require("scripts/time.nut")
local { isPlatformSony, isPlatformPS4, isPlatformXboxOne } = require("scripts/clientState/platform.nut")

local hotasPS4DevId = "044F:B67B"
local hotasXONEDevId = "044F:B68C"

local function askHotasPresetChange()
{
  if ((!isPlatformSony && !isPlatformXboxOne) || ::loadLocalByAccount("wnd/detectThrustmasterHotas", false))
    return

  local preset = ::g_controls_presets.getCurrentPreset()
  local is_ps4_non_gamepad_preset = isPlatformSony
    && preset.name.indexof("dualshock4") == null
    && preset.name.indexof("default") == null
  local is_xboxone_non_gamepad_preset = isPlatformXboxOne
    && preset.name.indexof("xboxone_ma") == null
    && preset.name.indexof("xboxone_simulator") == null

  ::saveLocalByAccount("wnd/detectThrustmasterHotas", true)

  if (is_ps4_non_gamepad_preset && is_xboxone_non_gamepad_preset)
    return

  local questionLocId =
    isPlatformSony ? "msgbox/controller_hotas4_found" :
    isPlatformXboxOne ? "msgbox/controller_hotas_one_found" :
    ::unreachable()

  local mainAction = function() {
    local presetName =
      isPlatformSony ? "thrustmaster_hotas4" :
      isPlatformXboxOne ? "xboxone_thrustmaster_hotas_one" :
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
      isPlatformPS4 ? hotasPS4DevId :
      isPlatformXboxOne ? hotasXONEDevId :
      null

    if (deviceId == null || !::g_login.isLoggedIn())
      return false

    if (!::is_device_connected(deviceId))
      return false

    return changePreset ? askHotasPresetChange() : true
  }
}
