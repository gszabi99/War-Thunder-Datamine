local { isPlatformSony } = require("scripts/clientState/platform.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local SAVE_TIMEOUT = isPlatformSony ? 300000 : 60000
local MIN_SAVE_TIMEOUT = 5000
local MIN_SAVE_TIMEOUT_NOT_LOGGED = 1000
local nextAllowedSaveTime = 0
local saveTask = persist("saveTask", @() { value = -1 })
local isSaveDelayed = false

local log = @(txt) dagor.debug($"SAVE_PROFILE: {txt}")

local function clearSaveTask() {
  ::periodic_task_unregister(saveTask.value)
  saveTask.value = -1
}
if (saveTask.value != -1)
  clearSaveTask()

local function startSaveTimer(timeout) {
  local timeToUpdate = ::dagor.getCurTime() + timeout
  if (saveTask.value >= 0) {
    if (nextAllowedSaveTime <= timeToUpdate)
      return
    clearSaveTask()
  }

  log($"Schedule profile save after {timeout / 1000} sec")
  nextAllowedSaveTime = timeToUpdate
  local isProfileReceived = ::g_login.isProfileReceived()
  saveTask.value = ::periodic_task_register({},
    function(_) {
      clearSaveTask()
      if (isProfileReceived != ::g_login.isProfileReceived()) {
        log($"Ignore profile save because of logged in status changed")
        return
      }
      if (::handlersManager.isInLoading) {
        log($"Delay profile save because of in loading")
        isSaveDelayed = true
        return
      }

      log($"Save profile")
      if (isProfileReceived)
        ::save_profile(false)
      else
        ::save_common_local_settings()
    },
    ::ceil(0.001 * timeout).tointeger())
}

local function forceSaveProfile() {
  startSaveTimer(::g_login.isProfileReceived() ? MIN_SAVE_TIMEOUT : MIN_SAVE_TIMEOUT_NOT_LOGGED)
}

local function saveProfile() {
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