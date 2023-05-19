//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { canLogout, startLogout } = require("%scripts/login/logout.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let logMC = log_with_prefix("[MATCHING_CONNECT] ")
let { subscribe } = require("eventbus")

const MATCHING_CONNECT_TIMEOUT = 30

enum REASON_DOMAIN {
  MATCHING = "matching"
  CHAR = "char"
  AUTH = "auth"
}

let isMatchingOnline = Watched(::is_online_available())

local progressBox = null

// callbacks for single connect request
local onConnectCb = null
local onDisconnectCb = null

let function onMatchingConnect() {
  ::destroyMsgBox(progressBox)
  progressBox = null

  onConnectCb?()
  onConnectCb = null
  onDisconnectCb = null

  // matching not save player info on diconnect (lobby, squad, queue)
  broadcastEvent("MatchingConnect")
  isMatchingOnline(true)
}

let function onMatchingDisconnect() {
  // we're still trying to reconnect after this event
  broadcastEvent("MatchingDisconnect")
  isMatchingOnline(false)
}

let function onFailToReconnect() {
  ::destroyMsgBox(progressBox)
  progressBox = null

  onDisconnectCb?()
  onDisconnectCb = null
  onConnectCb = null
}

let function showConnectProgress() {
  if (checkObj(progressBox))
    return

  let cancelFunc = @() ::scene_msg_box("no_online_warning", null,
    loc("mainmenu/noOnlineWarning"),
    [["ok", onMatchingDisconnect]], "ok")

  progressBox = ::scene_msg_box("matching_connect_progressbox", null,
    loc("yn1/connecting_msg"),
    [["cancel", cancelFunc]], "cancel",
    {
      waitAnim = true,
      delayedButtons = MATCHING_CONNECT_TIMEOUT
    })
}

let function checkShowMatchingConnect(successCb, errorCb, needProgressBox = true) {
  if (::is_online_available()) {
    successCb?()
    return
  }

  onConnectCb = successCb
  onDisconnectCb = errorCb

  if (needProgressBox)
    showConnectProgress()
}

// special handlers for char errors that require more complex actions than
// showing message box and logout
let function checkSpecialCharErrors(errorCode) {
  if (errorCode == ::ERRCODE_EMPTY_NICK) {
    if (::is_vendor_tencent()) {
      ::change_nickname(@() checkShowMatchingConnect(onConnectCb, onDisconnectCb))
      return true
    }
  }
  return false
}

let function doLogout() {
  if (!canLogout())
    return false

  startLogout()
  return true
}

let function logoutWithMsgBox(reason, message, reasonDomain, forceExit = false) {
  if (reasonDomain == REASON_DOMAIN.CHAR)
    if (checkSpecialCharErrors(reason))
      return

  onFailToReconnect()

  local needExit = forceExit
  if (!needExit) { // logout
    let handler = ::handlersManager.getActiveBaseHandler()
    if (("isDelayedLogoutOnDisconnect" not in handler)
        || !handler.isDelayedLogoutOnDisconnect())
      needExit = !doLogout()
  }

  let btnName = needExit ? "exit" : "ok"
  let msgCb = needExit ? exitGame : @() null

  ::error_message_box("yn1/connect_error", reason,
    [[ btnName, msgCb]], btnName,
    { saved = true, cancel_fn = msgCb }, message)
}

subscribe("on_online_unavailable", function(_) {
  logMC("on_online_unavailable")
  onMatchingDisconnect()
})

// methods called from the native code
::on_online_available <- function on_online_available() {
  logMC("on_online_available")
  onMatchingConnect()
}

::logout_with_msgbox <- @(params)
  logoutWithMsgBox(params.reason, params?.message, params.reasonDomain, false)

::exit_with_msgbox <- @(params)
  logoutWithMsgBox(params.reason, params?.message, params.reasonDomain, true)

return {
  isMatchingOnline
  checkShowMatchingConnect
}