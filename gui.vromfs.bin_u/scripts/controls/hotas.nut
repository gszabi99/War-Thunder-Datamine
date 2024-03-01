from "%scripts/dagui_library.nut" import *
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { secondsToMilliseconds, minutesToSeconds } = require("%scripts/time.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let {getstackinfos} = require("debug")
let { addPopup } = require("%scripts/popups/popups.nut")

let hotasPS4DevId = "044F:B67B"
let hotasXONEDevId = "044F:B68C"

function unreachable() {
  let info = getstackinfos(2) // get calling function
  let id = "".concat((info?.src ?? "?"), ":", (info?.line ?? "?"), " (", (info?.func ?? "?"), ")")
  let msg = $"Entered unreachable code: {id}"
  script_net_assert_once(id, msg)
}

let hotasControlImageFileName = isPlatformXboxOne ? "t-flight-hotas-one" : "t-flight-hotas-4"

function askHotasPresetChange() {
  if ((!isPlatformSony && !isPlatformXboxOne) || loadLocalByAccount("wnd/detectThrustmasterHotas", false))
    return

  saveLocalByAccount("wnd/detectThrustmasterHotas", true)

  let questionLocId =
    isPlatformSony ? "msgbox/controller_hotas4_found" :
    isPlatformXboxOne ? "msgbox/controller_hotas_one_found" :
    unreachable()

  let mainAction = function() {
    let presetName =
      isPlatformSony ? "thrustmaster_hotas4" :
      isPlatformXboxOne ? "xboxone_thrustmaster_hotas_one" :
      unreachable()
    ::apply_joy_preset_xchange(::g_controls_presets.getControlsPresetFilename(presetName))
  }

  addPopup(
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