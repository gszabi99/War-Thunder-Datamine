//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

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

::online_init_stage_finished <- function online_init_stage_finished(stage, ...) {
  if (stage in matchingStageToLoginState)
    ::g_login.addState(matchingStageToLoginState[stage])
}

let class LoginProcess {
  curProgress = LOGIN_PROGRESS.NOT_STARTED

  constructor(shouldCheckScriptsReload) {
    if (shouldCheckScriptsReload)
      this.restoreStateAfterScriptsReload()
    if (::g_login.isAuthorized())
      this.curProgress = LOGIN_PROGRESS.IN_LOGIN_WND

    ::subscribe_handler(this, ::g_listener_priority.LOGIN_PROCESS)
    this.nextStep()
  }

  function restoreStateAfterScriptsReload() {
    let curMState = ::get_online_client_cur_state()
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

      ::g_matching_connect.connect(successCb, errorCb, false)
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
      if (::g_login.isAuthorized())
        this.nextStep()
    }
    else if (this.curProgress == LOGIN_PROGRESS.INIT_ONLINE_BINARIES) {
      if (::g_login.isReadyToFullLoad())
        this.nextStep()
    }
    else if (this.curProgress == LOGIN_PROGRESS.INIT_CONFIGS) {
      if (::g_login.isLoggedIn())
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