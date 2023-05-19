//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let exitGame = require("%scripts/utils/exitGame.nut")
let { getLocalLanguage } = require("language")
let { replace } = require("%sqstd/string.nut")
let { matchingApiFunc } = require("%scripts/matching/api.nut")

let function addLineBreaks(text) {
  if (getLocalLanguage() != "HChinese")
    return text
  local resArr = []
  let total = utf8(text).charCount()
  for (local i = 0; i < total; i++) {
    let nextChar = utf8(text).slice(i, i + 1)
    if (nextChar == "\t")
      continue
    resArr.append(nextChar, (i < total - 1 ? "\t" : ""))
  }
  return "".join(resArr)
}

::punish_show_tips <- function punish_show_tips(params) {
  log("punish_show_tips")
  if ("reason" in params)
    ::showInfoMsgBox(params.reason)
}

::punish_close_client <- function punish_close_client(params) {
  log("punish_close_client")
  let message = ("reason" in params) ? addLineBreaks(params.reason) : loc("matching/hacker_kicked_notice")

  let needFlightMenu = ::is_in_flight() && !::get_is_in_flight_menu() && !::is_flight_menu_disabled()
  if (needFlightMenu)
    ::gui_start_flight_menu()

  ::scene_msg_box(
      "info_msg_box",
      null,
      message,
      [["exit", exitGame ]], "exit")
}

/**
requestOptions:
  - showError (defaultValue = true) - show error by checkMatchingError function if it is
**/
::request_matching <- function request_matching(functionName, onSuccess = null, onError = null, params = null, requestOptions = null) {
  let showError = getTblValue("showError", requestOptions, true)

  let callback = (@(onSuccess, onError, showError) function(response) {
                     if (!::checkMatchingError(response, showError)) {
                       if (onError != null)
                         onError(response)
                     }
                     else if (onSuccess != null)
                      onSuccess(response)
                   })(onSuccess, onError, showError)

  matchingApiFunc(functionName, callback, params)
}

::checkMatchingError <- function checkMatchingError(params, showError = true) {
  if (params.error == OPERATION_COMPLETE)
    return true

  if (!showError || ::disable_network())
    return false

  let errorId = getTblValue("error_id", params) || ::matching.error_string(params.error)
  local text = loc("matching/" + replace(errorId, ".", "_"))
  if ("error_message" in params)
    text = text + "\n<B>" + params.error_message + "</B>"

  let id = "sessionLobby_error"

  let options = { saved = true, checkDuplicateId = true, cancel_fn = function() {} }
  if ("LAST_SESSION_DEBUG_INFO" in getroottable())
    options["debug_string"] <- ::LAST_SESSION_DEBUG_INFO

  ::scene_msg_box(id, null, text, [["ok", function() {} ]], "ok", options)
  return false
}

