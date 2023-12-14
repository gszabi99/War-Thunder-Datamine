from "%scripts/dagui_natives.nut" import disable_network
from "%scripts/dagui_library.nut" import *
let { OPERATION_COMPLETE } = require("matching.errors")
let { replace } = require("%sqstd/string.nut")
let { matchingApiFunc } = require("%scripts/matching/api.nut")
let { get_last_session_debug_info } = require("%scripts/matchingRooms/sessionDebugInfo.nut")

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

  if (!showError || disable_network())
    return false

  let errorId = getTblValue("error_id", params) || ::matching.error_string(params.error)
  local text = loc("".concat("matching/", replace(errorId, ".", "_")))
  if ("error_message" in params)
    text = "".concat(text, "\n<B>", params.error_message, "</B>")

  let id = "sessionLobby_error"

  let options = { saved = true, checkDuplicateId = true, cancel_fn = function() {} }
  options["debug_string"] <- get_last_session_debug_info()

  scene_msg_box(id, null, text, [["ok", function() {} ]], "ok", options)
  return false
}

