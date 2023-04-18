//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { ceil } = require("math")
let { get_time_msec } = require("dagor.time")

let SAVE_TIMEOUT = isPlatformSony ? 300000 : 60000
let MIN_SAVE_TIMEOUT = 5000
let MIN_SAVE_TIMEOUT_NOT_LOGGED = 1000
local nextAllowedSaveTime = 0
let saveTask = persist("saveTask", @() { value = -1 })
local isSaveDelayed = false

let lg = @(txt) log($"SAVE_PROFILE: {txt}")

let function clearSaveTask() {
  ::periodic_task_unregister(saveTask.value)
  saveTask.value = -1
}
if (saveTask.value != -1)
  clearSaveTask()

let function startSaveTimer(timeout) {
  let timeToUpdate = get_time_msec() + timeout
  if (saveTask.value >= 0) {
    if (nextAllowedSaveTime <= timeToUpdate)
      return
    clearSaveTask()
  }

  lg($"Schedule profile save after {timeout / 1000} sec")
  nextAllowedSaveTime = timeToUpdate
  let isProfileReceived = ::g_login.isProfileReceived()
  saveTask.value = ::periodic_task_register({},
    function(_) {
      clearSaveTask()
      if (isProfileReceived != ::g_login.isProfileReceived()) {
        lg($"Ignore profile save because of logged in status changed")
        return
      }
      if (::handlersManager.isInLoading) {
        lg($"Delay profile save because of in loading")
        isSaveDelayed = true
        return
      }

      lg($"Save profile")
      if (isProfileReceived)
        ::save_profile(false)
      else
        ::save_common_local_settings()
    },
    ceil(0.001 * timeout).tointeger())
}

let function forceSaveProfile() {
  startSaveTimer(::g_login.isProfileReceived() ? MIN_SAVE_TIMEOUT : MIN_SAVE_TIMEOUT_NOT_LOGGED)
}

let function saveProfile() {
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