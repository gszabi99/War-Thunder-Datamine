//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { OPERATION_COMPLETE } = require("matching.errors")
let { replace } = require("%sqstd/string.nut")
let { matchingApiFunc } = require("%scripts/matching/api.nut")

/**
requestOptions:
  - showError (defaultValue = true) - show error by checkMatchingError function if it is
**/
::request_matching <- function request_matching(functionName, onSuccess = null, onError = null, params = null, requestOptions = null) {
  let showError = getTblValue("showError", requestOptions, true)

  let callback = function(response) {
                     if (!::checkMatchingError(response, showError)) {
                       if (onError != null)
                         onError(response)
                     }
                     else if (onSuccess != null)
                      onSuccess(response)
                   }

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

