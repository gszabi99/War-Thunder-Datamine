from "%scripts/g_listener_priority.nut" import LOGIN_PROCESS
from "%scripts/matching/matchingOnline.nut" import checkShowMatchingConnect
from "%scripts/login/loginProcessState.nut" import setCurLoginProcess, getCurLoginProcess
from "%scripts/login/loginManager.nut" import loadLoginHandler, addLoginState, onProfileReceived
from "%scripts/login/loginPseudoThreadsConfig.nut" import initLoginPseudoThreadsConfig
from "%sqStdLibs/helpers/subscriptions.nut" import subscribe_handler, addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import isReadyToFullLoad, isAuthorized, isLoginStarted,
  isProfileReceived, isLoginRequired, hasFullLoginState
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_natives.nut" import get_online_client_cur_state
from "%scripts/dagui_library.nut" import *
from "%globalScripts/onlineStageConsts.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE
from "dagor.workcycle" import deferOnce
from "%scripts/sqDagui/framework/baseGuiHandlerManager.nut" import is_in_loading_screen

enum LOGIN_PROGRESS {
  NOT_STARTED
  IN_LOGIN_WND
  INIT_ONLINE_BINARIES
  INIT_CONFIGS
  FINISHED
}

let matchingStageToLoginState = {
  [ONLINE_BINARIES_INITED] = LOGIN_STATE.ONLINE_BINARIES_INITED, 
  [HANGAR_ENTERED] = LOGIN_STATE.HANGAR_LOADED                   
}

eventbus_subscribe("online_init_stage_finished",  function(evt){
  let {stage} = evt
  if (stage in matchingStageToLoginState)
    addLoginState(matchingStageToLoginState[stage])
})

class LoginProcess {
  curProgress = LOGIN_PROGRESS.NOT_STARTED

  constructor(shouldCheckScriptsReload) {
    if (shouldCheckScriptsReload)
      this.restoreStateAfterScriptsReload()
    subscribe_handler(this, LOGIN_PROCESS)
    
    
    if (isAuthorized.get() || isLoginStarted.get() || shouldCheckScriptsReload)
      this.curProgress = LOGIN_PROGRESS.IN_LOGIN_WND

    if (shouldCheckScriptsReload)
      this.checkNextStep()
    else
      this.nextStep()
  }

  function restoreStateAfterScriptsReload() {
    let curMState = get_online_client_cur_state()
    foreach (mState, lState in matchingStageToLoginState)
      if (mState & curMState)
        addLoginState(lState)
  }

  function isValid() {
    return this.curProgress != LOGIN_PROGRESS.NOT_STARTED
        && this.curProgress < LOGIN_PROGRESS.FINISHED
  }

  function nextStep() {
    this.curProgress++

    if (this.curProgress == LOGIN_PROGRESS.IN_LOGIN_WND)
      loadLoginHandler()
    else if (this.curProgress == LOGIN_PROGRESS.INIT_ONLINE_BINARIES) {
      
      let successCb = Callback(function() {
                          addLoginState(LOGIN_STATE.MATCHING_CONNECTED)
                        }, this)
      let errorCb   = Callback(function() {
                          this.destroy()
                        }, this)

      checkShowMatchingConnect(successCb, errorCb, false)
    }
    else if (this.curProgress == LOGIN_PROGRESS.INIT_CONFIGS) {
      initLoginPseudoThreadsConfig(
        Callback(function() {
          addLoginState(LOGIN_STATE.CONFIGS_INITED)
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
      if (hasFullLoginState.get())
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

function startLoginProcess(shouldCheckScriptsReload = false) {
  if (getCurLoginProcess()?.isValid() ?? false)
    return
  setCurLoginProcess(LoginProcess(shouldCheckScriptsReload))
}

function startLoginProcessOnScriptsLoad() {
  let needStartLoginProcess = isAuthorized.get() ? !hasFullLoginState.get()
    : isLoginRequired.get() && !is_in_loading_screen()
  if (needStartLoginProcess)
    startLoginProcess(true)
}
deferOnce(startLoginProcessOnScriptsLoad)

addListenersWithoutEnv({
  function ProfileUpdated(_) {
    if (!isAuthorized.get() || isProfileReceived.get())
      return
    onProfileReceived()
  }
}, LOGIN_PROCESS)

return freeze({
  startLoginProcess
})
