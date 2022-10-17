let { canLogout, startLogout } = require("%scripts/login/logout.nut")
let exitGame = require("%scripts/utils/exitGame.nut")

const MATCHING_CONNECT_TIMEOUT = 30

enum REASON_DOMAIN {
  MATCHING = "matching"
  CHAR = "char"
  AUTH = "auth"
}

::g_matching_connect <- {
  progressBox = null

  //callbacks for single connect request
  onConnectCb = null
  onDisconnectCb = null
}

g_matching_connect.onConnect <- function onConnect()
{
  destroyProgressBox()
  if (onConnectCb) onConnectCb()
  resetCallbacks()

  //matching not save player info on diconnect (lobby, squad, queue)
  ::broadcastEvent("MatchingConnect")
}

g_matching_connect.onDisconnect <- function onDisconnect()
{
  //we still trying to reconnect after this event
  ::broadcastEvent("MatchingDisconnect")
}

g_matching_connect.onFailToReconnect <- function onFailToReconnect()
{
  destroyProgressBox()
  if (onDisconnectCb) onDisconnectCb()
  resetCallbacks()
}

g_matching_connect.connect <- function connect(successCb = null, errorCb = null, needProgressBox = true)
{
  if (::is_online_available())
  {
    if (successCb) successCb()
    return
  }

  onConnectCb = successCb
  onDisconnectCb = errorCb

  if (needProgressBox)
  {
    let cancelFunc = function()
    {
      ::scene_msg_box("no_online_warning", null, ::loc("mainmenu/noOnlineWarning"),
        [["ok", function() { ::g_matching_connect.onDisconnect() }]],
        "ok")
    }
    showProgressBox(cancelFunc)
  }
}

g_matching_connect.resetCallbacks <- function resetCallbacks()
{
  onConnectCb = null
  onDisconnectCb = null
}

g_matching_connect.showProgressBox <- function showProgressBox(cancelFunc = null)
{
  if (::checkObj(progressBox))
    return
  progressBox = ::scene_msg_box("matching_connect_progressbox",
                                null,
                                ::loc("yn1/connecting_msg"),
                                [["cancel", cancelFunc ?? function(){}]],
                                "cancel",
                                { waitAnim = true,
                                  delayedButtons = MATCHING_CONNECT_TIMEOUT
                                })
}

g_matching_connect.destroyProgressBox <- function destroyProgressBox()
{
  if(::checkObj(progressBox))
  {
    progressBox.getScene().destroyElement(progressBox)
    ::broadcastEvent("ModalWndDestroy")
  }
  progressBox = null
}

// special handlers for char errors that require more complex actions than
// showing message box and logout
g_matching_connect.checkSpecialCharErrors <- function checkSpecialCharErrors(errorCode)
{
  if (errorCode == ::ERRCODE_EMPTY_NICK)
  {
    if (::is_vendor_tencent())
    {
      ::change_nickname(::Callback(
                          function() {
                            connect(onConnectCb, onDisconnectCb)
                          },
                          this
                        )
                       )
      return true
    }
  }
  return false
}

g_matching_connect.logoutWithMsgBox <- function logoutWithMsgBox(reason, message, reasonDomain, forceExit = false)
{
  if (reasonDomain == REASON_DOMAIN.CHAR)
    if (checkSpecialCharErrors(reason))
      return

  onFailToReconnect()

  local needExit = forceExit
  if (!needExit) //logout
  {
    let handler = ::handlersManager.getActiveBaseHandler()
    if (!("isDelayedLogoutOnDisconnect" in handler)
        || !handler.isDelayedLogoutOnDisconnect())
      needExit = !doLogout()
  }

  let btnName = needExit ? "exit" : "ok"
  let msgCb = needExit ? exitGame : function() {}

  ::error_message_box("yn1/connect_error", reason,
    [[ btnName, msgCb]], btnName,
    { saved = true, cancel_fn = msgCb}, message)
}

g_matching_connect.exitWithMsgBox <- function exitWithMsgBox(reason, message, reasonDomain)
{
  logoutWithMsgBox(reason, message, reasonDomain, true)
}

g_matching_connect.doLogout <- function doLogout()
{
  if (!canLogout())
    return false

  startLogout()
  return true
}
