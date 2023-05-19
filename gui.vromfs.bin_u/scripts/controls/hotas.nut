//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { secondsToMilliseconds, minutesToSeconds } = require("%scripts/time.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")

let hotasPS4DevId = "044F:B67B"
let hotasXONEDevId = "044F:B68C"

let hotasControlImageFileName = isPlatformXboxOne ? "t-flight-hotas-one" : "t-flight-hotas-4"

let function askHotasPresetChange() {
  if ((!isPlatformSony && !isPlatformXboxOne) || ::loadLocalByAccount("wnd/detectThrustmasterHotas", false))
    return

  ::saveLocalByAccount("wnd/detectThrustmasterHotas", true)

  let questionLocId =
    isPlatformSony ? "msgbox/controller_hotas4_found" :
    isPlatformXboxOne ? "msgbox/controller_hotas_one_found" :
    ::unreachable()

  let mainAction = function() {
    let presetName =
      isPlatformSony ? "thrustmaster_hotas4" :
      isPlatformXboxOne ? "xboxone_thrustmaster_hotas_one" :
      ::unreachable()
    ::apply_joy_preset_xchange(::g_controls_presets.getControlsPresetFilename(presetName))
  }

  ::g_popups.add(
    null,
    loc(questionLocId),
    mainAction,
    [{
      id = "yes",
      text = loc("msgbox/btn_yes"),
      func = mainAction
    },
    { id = "no",
      text = loc("msgbox/btn_no")
    }],
    null,
    null,
    secondsToMilliseconds(minutesToSeconds(10))
  )
}

return {
  hotasControlImagePath = $"!ui/images/joystick/{hotasControlImageFileName}?P1"

  checkJoystickThustmasterHotas = function(changePreset = true) {
    let deviceId =
      isPlatformSony ? hotasPS4DevId :
      isPlatformXboxOne ? hotasXONEDevId :
      null

    if (deviceId == null || !::g_login.isLoggedIn())
      return false

    if (!::is_device_connected(deviceId))
      return false

    return changePreset ? askHotasPresetChange() : true
  }
}