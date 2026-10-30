from "%scripts/clientState/localProfileDeprecated.nut" import loadLocalByAccount, saveLocalByAccount
from "%scripts/time.nut" import secondsToMilliseconds, minutesToSeconds
from "%sqstd/platform.nut" import isSony, isXbox
from "%scripts/popups/popups.nut" import addPopup
from "%scripts/controls/controlsPresets.nut" import getControlsPresetFilename
from "%scripts/controls/isDeviceConnected.nut" import isDeviceConnected
from "%scripts/controls/controlsTypeUtils.nut" import applyJoyPresetXchange
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%appGlobals/login/loginState.nut" import hasFullLoginState
from "debug" import getstackinfos
from "%scripts/dagui_library.nut" import *

const hotasPS4DevId = "044F:B67B"
const hotasXONEDevId = "044F:B68C"

function unreachable() {
  let info = getstackinfos(2) 
  let id = "".concat((info?.src ?? "?"), ":", (info?.line ?? "?"), " (", (info?.func ?? "?"), ")")
  let msg = $"Entered unreachable code: {id}"
  script_net_assert_once(id, msg)
}

let hotasControlImageFileName = isXbox ? "t-flight-hotas-one" : "t-flight-hotas-4"

function askHotasPresetChange() {
  if ((!isSony && !isXbox) || loadLocalByAccount("wnd/detectThrustmasterHotas", false))
    return

  saveLocalByAccount("wnd/detectThrustmasterHotas", true)

  let questionLocId =
    isSony ? "msgbox/controller_hotas4_found" :
    isXbox ? "msgbox/controller_hotas_one_found" :
    unreachable()

  let mainAction = function() {
    let presetName =
      isSony ? "thrustmaster_hotas4" :
      isXbox ? "xboxone_thrustmaster_hotas_one" :
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

return freeze({
  hotasControlImagePath = $"!ui/images/joystick/{hotasControlImageFileName}?P1"

  checkJoystickThustmasterHotas = function(changePreset = true) {
    let deviceId =
      isSony ? hotasPS4DevId :
      isXbox ? hotasXONEDevId :
      null

    if (deviceId == null || !hasFullLoginState.get())
      return false

    if (!isDeviceConnected(deviceId))
      return false

    return changePreset ? askHotasPresetChange() : true
  }
})