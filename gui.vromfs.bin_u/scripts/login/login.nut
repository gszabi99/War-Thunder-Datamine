from "%scripts/dagui_library.nut" import *
from "%scripts/login/loginConsts.nut" import LOGIN_STATE

let LoginProcess = require("loginProcess.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { bqSendLoginState } = require("%scripts/bigQuery/bigQueryClient.nut")
let { bitMaskToSstring } = require("%scripts/debugTools/dbgEnum.nut")
let { registerPersistentDataFromRoot, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")

::g_login <- {
  [PERSISTENT_DATA_PARAMS] = ["curState", "curLoginProcess"]

  curState = LOGIN_STATE.NOT_LOGGED_IN
  curLoginProcess = null
  loginProcessClass = LoginProcess //this is really bad class. It has a cyclic dependency with g_login and is hard to change the order in it for other project

  onAuthorizeChanged = function() {}
  onLoggedInChanged  = function() {}
  loadLoginHandler   = function() {}
  initConfigs        = function(cb) { cb() }
  afterScriptsReload = function() {}

  function onProfileReceived() {
    this.addState(LOGIN_STATE.PROFILE_RECEIVED | LOGIN_STATE.CONFIGS_RECEIVED)

    broadcastEvent("ProfileReceived")
  }

  function bigQueryOnLogin() {
    local params = platformId
    if (::getSystemConfigOption("launcher/bg_update", true))
      params = " ".concat(params, "bg_update")
    let data = { params = params }

    let hangarBlk = ::getSystemConfigOption("hangarBlk", "")
    if(hangarBlk != "")
      data.hangarBlk <- hangarBlk

    sendBqEvent("CLIENT_LOGIN_2", "login", data)
  }
}

::g_login.init <- function init() {
  registerPersistentDataFromRoot("g_login")
  subscribe_handler(this, ::g_listener_priority.CONFIG_VALIDATION)
}

::g_login.isAuthorized <- function isAuthorized() {
  return (this.curState & LOGIN_STATE.AUTHORIZED) != 0
}

::g_login.isReadyToFullLoad <- function isReadyToFullLoad() {
  return this.hasState(LOGIN_STATE.AUTHORIZED | LOGIN_STATE.ONLINE_BINARIES_INITED)
}

::g_login.isLoggedIn <- function isLoggedIn() {
  return (this.curState & LOGIN_STATE.LOGGED_IN) == LOGIN_STATE.LOGGED_IN
}

::g_login.isProfileReceived <- function isProfileReceived() {
  return (this.curState & LOGIN_STATE.PROFILE_RECEIVED) != 0
}

::g_login.hasState <- function hasState(state) {
  return (this.curState & state) == state
}

::g_login.startLoginProcess <- function startLoginProcess(shouldCheckScriptsReload = false) {
  if (this.curLoginProcess && this.curLoginProcess.isValid())
    return
  this.curLoginProcess = this.loginProcessClass(shouldCheckScriptsReload)
}

::g_login.setState <- function setState(newState) {
  if (this.curState == newState)
    return

  let wasState      = this.curState
  let wasAuthorized = this.isAuthorized()
  let wasLoggedIn   = this.isLoggedIn()

  this.curState = newState

  if (wasAuthorized != this.isAuthorized())
    this.onAuthorizeChanged()
  if (wasLoggedIn != this.isLoggedIn())
    this.onLoggedInChanged()

  broadcastEvent("LoginStateChanged")

  bqSendLoginState(
  {
    "was"  : wasState,
    "new"  : newState,
    "auth" : this.isAuthorized(),
    "login" : this.isLoggedIn()
  })
}

::g_login.addState <- function addState(statePart) {
  this.setState(this.curState | statePart)
}

::g_login.removeState <- function removeState(statePart) {
  this.setState(this.curState & ~statePart)
}

::g_login.destroyLoginProgress <- function destroyLoginProgress() {
  if (this.curLoginProcess)
    this.curLoginProcess.destroy()
  this.curLoginProcess = null
}

::g_login.reset <- function reset() {
  this.destroyLoginProgress()
  this.setState(LOGIN_STATE.NOT_LOGGED_IN)
}

::g_login.onEventScriptsReloaded <- function onEventScriptsReloaded(_p) {
  if (!this.isLoggedIn() && this.isAuthorized())
    this.startLoginProcess(true)
  this.afterScriptsReload()
}

::g_login.getStateDebugStr <- function getStateDebugStr(state = null) {
  state = state ?? this.curState
  return state == 0 ? "0" : bitMaskToSstring(LOGIN_STATE, state)
}

::g_login.debugState <- function debugState(shouldShowNotSetBits = false) {
  let debugLog = dlog // warning disable: -forbidden-function
  if (shouldShowNotSetBits)
    return debugLog($"not set loginState = {this.getStateDebugStr(LOGIN_STATE.LOGGED_IN & ~this.curState)}") // warning disable: -forbidden-function
  return debugLog($"loginState = {this.getStateDebugStr()}") // warning disable: -forbidden-function
}

::is_logged_in <- function is_logged_in() { //used from code
  return ::g_login.isLoggedIn()
}

::cross_call_api.login <- ::g_login
