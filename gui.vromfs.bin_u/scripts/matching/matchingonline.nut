from "%scripts/dagui_natives.nut" import is_online_available
from "%scripts/dagui_library.nut" import *

let { canLogout, startLogout } = require("%scripts/login/logout.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let logMC = log_with_prefix("[MATCHING_CONNECT] ")
let { eventbus_subscribe } = require("eventbus")
let { showErrorMessageBox } = require("%scripts/utils/errorMsgBox.nut")

const MATCHING_CONNECT_TIMEOUT = 30


let isMatchingOnline = Watched(is_online_available())

local progressBox = null


local onConnectCb = null
local onDisconnectCb = null

function onMatchingConnect() {
  destroyMsgBox(progressBox)
  progressBox = null

  onConnectCb?()
  onConnectCb = null
  onDisconnectCb = null

  
  broadcastEvent("MatchingConnect")
  isMatchingOnline(true)
}

function onMatchingDisconnect() {
  
  broadcastEvent("MatchingDisconnect")
  isMatchingOnline(false)
}

function onFailToReconnect() {
  destroyMsgBox(progressBox)
  progressBox = null

  onDisconnectCb?()
  onDisconnectCb = null
  onConnectCb = null
}

function showConnectProgress() {
  if (checkObj(progressBox))
    return

  let cancelFunc = @() scene_msg_box("no_online_warning", null,
    loc("mainmenu/noOnlineWarning"),
    [["ok", onMatchingDisconnect]], "ok")

  progressBox = scene_msg_box("matching_connect_progressbox", null,
    loc("yn1/connecting_msg"),
    [["cancel", cancelFunc]], "cancel",
    {
      waitAnim = true,
      delayedButtons = MATCHING_CONNECT_TIMEOUT
    })
}

function checkShowMatchingConnect(successCb, errorCb, needProgressBox = true) {
  if (is_online_available()) {
    successCb?()
    return
  }

  onConnectCb = successCb
  onDisconnectCb = errorCb

  if (needProgressBox)
    showConnectProgress()
}

function doLogout() {
  if (!canLogout())
    return false

  startLogout()
  return true
}

function logoutWithMsgBox(reason, message, _reasonDomain, forceExit = false) {
  onFailToReconnect()

  local needExit = forceExit
  if (!needExit) { 
    let handler = handlersManager.getActiveBaseHandler()
    if (("isDelayedLogoutOnDisconnect" not in handler)
        || !handler.isDelayedLogoutOnDisconnect())
      needExit = !doLogout()
  }

  let btnName = needExit ? "exit" : "ok"
  let msgCb = needExit ? exitGame : @() null

  showErrorMessageBox("yn1/connect_error", reason,
    [[ btnName, msgCb]], btnName,
    { saved = true, cancel_fn = msgCb }, message)
}

eventbus_subscribe("on_online_unavailable", function(_) {
  logMC("on_online_unavailable")
  onMatchingDisconnect()
})

eventbus_subscribe("on_online_available", function on_online_available(...) {
  logMC("on_online_available")
  onMatchingConnect()
})

eventbus_subscribe("logout_with_msgbox", @(params)
  logoutWithMsgBox(params.reason, params?.message, params.reasonDomain, false))

eventbus_subscribe("exit_with_msgbox", @(params)
  logoutWithMsgBox(params.reason, params?.message, params.reasonDomain, true))

return {
  isMatchingOnline
  checkShowMatchingConnect
}