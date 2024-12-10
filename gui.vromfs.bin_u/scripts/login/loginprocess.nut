from "%scripts/dagui_natives.nut" import get_online_client_cur_state
from "%scripts/dagui_library.nut" import *
from "%scripts/login/loginConsts.nut" import LOGIN_STATE

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { checkShowMatchingConnect } = require("%scripts/matching/matchingOnline.nut")
let { eventbus_subscribe } = require("eventbus")
let { isReadyToFullLoad, isLoggedIn, isAuthorized, isLoginStarted
} = require("%scripts/login/loginStates.nut")

enum LOGIN_PROGRESS {
  NOT_STARTED
  IN_LOGIN_WND
  INIT_ONLINE_BINARIES
  INIT_CONFIGS
  FINISHED
}

let matchingStageToLoginState = {
  [ONLINE_BINARIES_INITED] = LOGIN_STATE.ONLINE_BINARIES_INITED, // warning disable: -const-never-declared
  [HANGAR_ENTERED] = LOGIN_STATE.HANGAR_LOADED                   // warning disable: -const-never-declared
}

eventbus_subscribe("online_init_stage_finished",  function(evt){
  let {stage} = evt
  if (stage in matchingStageToLoginState)
    ::g_login.addState(matchingStageToLoginState[stage])
})

let class LoginProcess {
  curProgress = LOGIN_PROGRESS.NOT_STARTED

  constructor(shouldCheckScriptsReload) {
    if (shouldCheckScriptsReload)
      this.restoreStateAfterScriptsReload()
    if (isAuthorized.get() || isLoginStarted.get())
      this.curProgress = LOGIN_PROGRESS.IN_LOGIN_WND

    subscribe_handler(this, g_listener_priority.LOGIN_PROCESS)
    this.nextStep()
  }

  function restoreStateAfterScriptsReload() {
    let curMState = get_online_client_cur_state()
    foreach (mState, lState in matchingStageToLoginState)
      if (mState & curMState)
        ::g_login.addState(lState)
  }

  function isValid() {
    return this.curProgress != LOGIN_PROGRESS.NOT_STARTED
        && this.curProgress < LOGIN_PROGRESS.FINISHED
  }

  function nextStep() {
    this.curProgress++

    if (this.curProgress == LOGIN_PROGRESS.IN_LOGIN_WND)
      ::g_login.loadLoginHandler()
    else if (this.curProgress == LOGIN_PROGRESS.INIT_ONLINE_BINARIES) {
      //connect to matching
      let successCb = Callback(function() {
                          ::g_login.addState(LOGIN_STATE.MATCHING_CONNECTED)
                        }, this)
      let errorCb   = Callback(function() {
                          this.destroy()
                        }, this)

      checkShowMatchingConnect(successCb, errorCb, false)
    }
    else if (this.curProgress == LOGIN_PROGRESS.INIT_CONFIGS) {
      ::g_login.initConfigs(
        Callback(function() {
          ::g_login.addState(LOGIN_STATE.CONFIGS_INITED)
        },
        this))
    }

    this.checkNextStep()
  }

  function checkNextStep() {
    if (this.curProgress == LOGIN_PROGRESS.IN_LOGIN_WND) {
      if (isAuthorized.get())
        this.nextStep()
    }
    else if (this.curProgress == LOGIN_PROGRESS.INIT_ONLINE_BINARIES) {
      if (isReadyToFullLoad.get())
        this.nextStep()
    }
    else if (this.curProgress == LOGIN_PROGRESS.INIT_CONFIGS) {
      if (isLoggedIn.get())
        this.nextStep()
    }
  }

  function onEventLoginStateChanged(_p) {
    this.checkNextStep()
  }

  function destroy() {
    if (this.isValid())
      this.curProgress = LOGIN_PROGRESS.NOT_STARTED
  }
}

return LoginProcess