from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%appGlobals/login/loginState.nut" import isLoggedIn
from "debug" import getstackinfos
from "%scripts/dagui_library.nut" import *

let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { secondsToMilliseconds, minutesToSeconds } = require("%scripts/time.nut")
let { isPlatformSony, isPlatformXbox } = require("%scripts/clientState/platform.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { getControlsPresetFilename } = require("%scripts/controls/controlsPresets.nut")
let { isDeviceConnected } = require("%scripts/controls/isDeviceConnected.nut")
let { applyJoyPresetXchange } = require("%scripts/controls/controlsTypeUtils.nut")

const hotasPS4DevId = "044F:B67B"
const hotasXONEDevId = "044F:B68C"

function unreachable() {
  let info = getstackinfos(2) 
  let id = "".concat((info?.src ?? "?"), ":", (info?.line ?? "?"), " (", (info?.func ?? "?"), ")")
  let msg = $"Entered unreachable code: {id}"
  script_net_assert_once(id, msg)
}

let hotasControlImageFileName = isPlatformXbox ? "t-flight-hotas-one" : "t-flight-hotas-4"

function askHotasPresetChange() {
  if ((!isPlatformSony && !isPlatformXbox) || loadLocalByAccount("wnd/detectThrustmasterHotas", false))
    return

  saveLocalByAccount("wnd/detectThrustmasterHotas", true)

  let questionLocId =
    isPlatformSony ? "msgbox/controller_hotas4_found" :
    isPlatformXbox ? "msgbox/controller_hotas_one_found" :
    unreachable()

  let mainAction = function() {
    let presetName =
      isPlatformSony ? "thrustmaster_hotas4" :
      isPlatformXbox ? "xboxone_thrustmaster_hotas_one" :
      unreachable()
    applyJoyPresetXchange(getControlsPresetFilename(presetName))
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
      isPlatformXbox ? hotasXONEDevId :
      null

    if (deviceId == null || !isLoggedIn.get())
      return false

    if (!isDeviceConnected(deviceId))
      return false

    return changePreset ? askHotasPresetChange() : true
  }
}