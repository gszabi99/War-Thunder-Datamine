from "%scripts/dagui_library.nut" import *
from "%scripts/login/loginConsts.nut" import LOGIN_STATE

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let LoginProcess = require("loginProcess.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { bqSendLoginState } = require("%scripts/bigQuery/bigQueryClient.nut")
let { bitMaskToSstring } = require("%scripts/debugTools/dbgEnum.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { getSystemConfigOption } = require("%globalScripts/systemConfig.nut")
let { registerRespondent } = require("scriptRespondent")

local g_login
let loginState = persist("loginState", @() {curState = LOGIN_STATE.NOT_LOGGED_IN, curLoginProcess = null})

g_login = {

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
    if (getSystemConfigOption("launcher/bg_update", true))
      params = " ".concat(params, "bg_update")
    let data = { params = params }

    let hangarBlk = getSystemConfigOption("hangarBlk", "")
    if(hangarBlk != "")
      data.hangarBlk <- hangarBlk

    sendBqEvent("CLIENT_LOGIN_2", "login", data)
  }
}

g_login.isAuthorized <- function isAuthorized() {
  return (loginState.curState & LOGIN_STATE.AUTHORIZED) != 0
}

g_login.isReadyToFullLoad <- function isReadyToFullLoad() {
  return this.hasState(LOGIN_STATE.AUTHORIZED | LOGIN_STATE.ONLINE_BINARIES_INITED)
}

g_login.isLoggedIn <- function isLoggedIn() {
  return (loginState.curState & LOGIN_STATE.LOGGED_IN) == LOGIN_STATE.LOGGED_IN
}

g_login.isProfileReceived <- function isProfileReceived() {
  return (loginState.curState & LOGIN_STATE.PROFILE_RECEIVED) != 0
}

g_login.hasState <- function hasState(state) {
  return (loginState.curState & state) == state
}

g_login.startLoginProcess <- function startLoginProcess(shouldCheckScriptsReload = false) {
  if (loginState.curLoginProcess?.isValid() ?? false)
    return
  loginState.curLoginProcess = this.loginProcessClass(shouldCheckScriptsReload)
}

g_login.setState <- function setState(newState) {
  if (loginState.curState == newState)
    return

  let wasState      = loginState.curState
  let wasAuthorized = this.isAuthorized()
  let wasLoggedIn   = this.isLoggedIn()

  loginState.curState = newState

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

g_login.addState <- function addState(statePart) {
  this.setState(loginState.curState | statePart)
}

g_login.removeState <- function removeState(statePart) {
  this.setState(loginState.curState & ~statePart)
}

g_login.destroyLoginProgress <- function destroyLoginProgress() {
  if (loginState.curLoginProcess)
    loginState.curLoginProcess.destroy()
  loginState.curLoginProcess = null
}

g_login.reset <- function reset() {
  this.destroyLoginProgress()
  this.setState(LOGIN_STATE.NOT_LOGGED_IN)
}

g_login.onEventScriptsReloaded <- function onEventScriptsReloaded(_p) {
  if (!this.isLoggedIn() && this.isAuthorized())
    this.startLoginProcess(true)
  this.afterScriptsReload()
}

g_login.getStateDebugStr <- function getStateDebugStr(state = null) {
  state = state ?? loginState.curState
  return state == 0 ? "0" : bitMaskToSstring(LOGIN_STATE, state)
}

g_login.debugState <- function debugState(shouldShowNotSetBits = false) {
  let debugLog = dlog // warning disable: -forbidden-function
  if (shouldShowNotSetBits)
    return debugLog($"not set loginState = {this.getStateDebugStr(LOGIN_STATE.LOGGED_IN & ~loginState.curState)}") // warning disable: -forbidden-function
  return debugLog($"loginState = {this.getStateDebugStr()}") // warning disable: -forbidden-function
}

g_login.init <- function init() {
  subscribe_handler(this, g_listener_priority.CONFIG_VALIDATION)
}

registerRespondent("is_logged_in", function is_logged_in() {
  return g_login.isLoggedIn()
})

::cross_call_api.login <- g_login

::g_login <- g_login

return {
  g_login
}