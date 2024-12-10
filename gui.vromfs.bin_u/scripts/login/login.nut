from "%scripts/dagui_library.nut" import *
from "%scripts/login/loginConsts.nut" import LOGIN_STATE

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let LoginProcess = require("loginProcess.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { bqSendLoginState } = require("%scripts/bigQuery/bigQueryClient.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { getSystemConfigOption } = require("%globalScripts/systemConfig.nut")
let { registerRespondent } = require("scriptRespondent")
let { destroyLoginProgress, setCurLoginProcess, getCurLoginProcess, loginState,
  isLoggedIn, isAuthorized
} = require("%scripts/login/loginStates.nut")

local g_login

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

g_login.startLoginProcess <- function startLoginProcess(shouldCheckScriptsReload = false) {
  if (getCurLoginProcess()?.isValid() ?? false)
    return
  setCurLoginProcess(this.loginProcessClass(shouldCheckScriptsReload))
}

g_login.setState <- function setState(newState) {
  let wasState = loginState.get()
  if (wasState == newState)
    return

  let wasAuthorized = isAuthorized.get()
  let wasLoggedIn   = isLoggedIn.get()

  loginState.set(newState)

  if (wasAuthorized != isAuthorized.get())
    this.onAuthorizeChanged()
  if (wasLoggedIn != isLoggedIn.get())
    this.onLoggedInChanged()

  broadcastEvent("LoginStateChanged")

  bqSendLoginState(
  {
    "was"  : wasState,
    "new"  : newState,
    "auth" : isAuthorized.get(),
    "login" : isLoggedIn.get()
  })
}

g_login.addState <- function addState(statePart) {
  this.setState(loginState.get() | statePart)
}

g_login.removeState <- function removeState(statePart) {
  this.setState(loginState.get() & ~statePart)
}

g_login.reset <- function reset() {
  destroyLoginProgress()
  this.setState(LOGIN_STATE.NOT_LOGGED_IN)
}

g_login.onEventScriptsReloaded <- function onEventScriptsReloaded(_p) {
  if (!isLoggedIn.get() && isAuthorized.get())
    this.startLoginProcess(true)
  this.afterScriptsReload()
}

g_login.init <- function init() {
  subscribe_handler(this, g_listener_priority.CONFIG_VALIDATION)
}

registerRespondent("is_logged_in", function is_logged_in() {
  return isLoggedIn.get()
})

::cross_call_api.login <- {
  isLoggedIn = @() isLoggedIn.get()
}

::g_login <- g_login

return {
  g_login
}