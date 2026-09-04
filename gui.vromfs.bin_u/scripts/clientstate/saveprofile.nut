from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "chard" import save_profile, save_common_local_settings
from "math" import ceil
from "dagor.time" import get_time_msec
from "%scripts/dagui_natives.nut" import periodic_task_unregister, periodic_task_register
from "%scripts/dagui_library.nut" import *

let { is_in_loading_screen } = require("%scripts/sqDagui/framework/baseGuiHandlerManager.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")

let SAVE_TIMEOUT = isPlatformSony ? 300000 : 60000
const MIN_SAVE_TIMEOUT = 5000
const MIN_SAVE_TIMEOUT_NOT_LOGGED = 1000
local nextAllowedSaveTime = 0
let saveTask = persist("saveTask", @() { value = -1 })
local isSaveDelayed = false

let lg = @(txt) log($"SAVE_PROFILE: {txt}")

function clearSaveTask() {
  periodic_task_unregister(saveTask.value)
  saveTask.value = -1
}
if (saveTask.value != -1)
  clearSaveTask()

function startSaveTimer(timeout) {
  let timeToUpdate = get_time_msec() + timeout
  if (saveTask.value >= 0) {
    if (nextAllowedSaveTime <= timeToUpdate)
      return
    clearSaveTask()
  }

  lg($"Schedule profile save after {timeout / 1000} sec")
  nextAllowedSaveTime = timeToUpdate
  let wasProfileReceived = isProfileReceived.get()
  saveTask.value = periodic_task_register({},
    function(_) {
      clearSaveTask()
      if (wasProfileReceived != isProfileReceived.get()) {
        lg($"Ignore profile save because of logged in status changed")
        return
      }
      if (is_in_loading_screen()) {
        lg($"Delay profile save because of in loading")
        isSaveDelayed = true
        return
      }

      lg($"Save profile")
      if (wasProfileReceived)
        save_profile(false)
      else
        save_common_local_settings()
    },
    ceil(0.001 * timeout).tointeger())
}

function forceSaveProfile() {
  startSaveTimer(isProfileReceived.get() ? MIN_SAVE_TIMEOUT : MIN_SAVE_TIMEOUT_NOT_LOGGED)
}

function saveProfile() {
  startSaveTimer(SAVE_TIMEOUT)
}

addListenersWithoutEnv({
  LoadingStateChange = function(_) {
    if (isSaveDelayed)
      forceSaveProfile()
    isSaveDelayed = false
  }
})

return {
  saveProfile
  forceSaveProfile
}