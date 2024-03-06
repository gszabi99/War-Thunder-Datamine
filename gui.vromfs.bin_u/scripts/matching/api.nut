from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import disable_network

let { matching_call, matching_listen_notify, matching_notify, matching_listen_rpc, matching_send_response } = require("matching.api")
let { eventbus_subscribe, eventbus_subscribe_onehit } = require("eventbus")
let { OPERATION_COMPLETE, is_matching_error, matching_error_string } = require("matching.errors")
let { replace } = require("%sqstd/string.nut")
let { get_last_session_debug_info } = require("%scripts/matchingRooms/sessionDebugInfo.nut")


 /*
 module with low-level matching server interface

 matchingRpcSubscribe - set handler for server-side rpc or notification
 matchingApiFunc - call remote function by name and set callback for answer
 matchingApiNotify - call remote function without callback
*/

function matching_subscribe(evtName, handler) {
  assert(type(evtName)=="string")
  let handlertype = type(handler)
  assert(handler == null || handlertype == "function")
  let is_rpc_call = handlertype == "function" && handler.getfuncinfos().parameters.len() > 2
  if (is_rpc_call) {
    //log("RPC:", evtName)
    matching_listen_rpc(evtName)
    eventbus_subscribe(evtName, function(evt) {
      //log("LISTEN RPC:", evtName, evt, handler.getfuncinfos().parameters)
      let sendResp = function(resp_obj) {
        matching_send_response(evt, resp_obj)
      }
      handler(evt?.request, sendResp)
    })
  }
  else {
    matching_listen_notify(evtName)
    eventbus_subscribe(evtName, function(evt) {
      //log("LISTEN NOTIFY: ", evtName, evt)
      handler(evt)
    })
  }
}

function matching_rpc_call(cmd, params = null, cb = null) {
  assert(type(cmd)=="string")
  assert(params == null || type(params)=="table")
  assert(cb == null || type(cb) == "function")
  let res = matching_call(cmd, params)
  //log("RPC CALL:", cmd, params)
  if (cb == null)
    return
  if (res?.reqId != null)
    eventbus_subscribe_onehit($"{cmd}.{res.reqId}", cb)
  else
    cb(res)
}

function translateMatchingParams(params) {
  if (params == null)
    return params
  foreach (key, value in params) {
    if (type(value) == "string") {
      if (key == "userId" || key == "roomId") {
        params[key] = value.tointeger()
      }
    }
  }
  return params
}

/*
  translate old API functions into new ones
  TODO: remove them by search&replace
*/
function matchingApiFunc(name, cb, params = null) {
  log($"send matching request: {name}")
  matching_rpc_call(name, translateMatchingParams(params), @(resp) cb?(resp))
}

function matchingApiNotify(name, params = null) {
  log($"send matching notify: {name}")
  matching_notify(name, translateMatchingParams(params))
}


function checkMatchingError(params, showError = true) {
  if (params.error == OPERATION_COMPLETE)
    return true

  if (!showError || disable_network())
    return false

  let errorId = getTblValue("error_id", params) || matching_error_string(params.error)
  local text = loc("".concat("matching/", replace(errorId, ".", "_")))
  if ("error_message" in params)
    text = "".concat(text, "\n<B>", params.error_message, "</B>")

  let id = "sessionLobby_error"

  let options = { saved = true, checkDuplicateId = true, cancel_fn = function() {} }
  options["debug_string"] <- get_last_session_debug_info()

  scene_msg_box(id, null, text, [["ok", function() {} ]], "ok", options)
  return false
}

/**
requestOptions:
  - showError (defaultValue = true) - show error by checkMatchingError function if it is
**/

function request_matching(functionName, onSuccess = null, onError = null, params = null, requestOptions = null) {
  let showError = getTblValue("showError", requestOptions, true)

  let callback = function(response) {
                     if (!checkMatchingError(response, showError)) {
                       if (onError != null)
                         onError(response)
                     }
                     else if (onSuccess != null)
                      onSuccess(response)
                   }

  matchingApiFunc(functionName, callback, params)
}

return {
  matchingApiFunc
  matchingApiNotify
  request_matching
  checkMatchingError
  isMatchingError = is_matching_error
  matchingErrorString = matching_error_string
  matchingRpcSubscribe = matching_subscribe
}
