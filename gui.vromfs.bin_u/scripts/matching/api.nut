from "%scripts/dagui_library.nut" import *

let { matching_call, matching_listen_notify, matching_notify, matching_listen_rpc, matching_send_response } = require("matching.api")
let { eventbus_subscribe, eventbus_subscribe_onehit } = require("eventbus")
let { OPERATION_COMPLETE, is_matching_error, matching_error_string } = require("matching.errors")
let { replace } = require("%sqstd/string.nut")
let { get_last_session_debug_info } = require("%scripts/matchingRooms/sessionDebugInfo.nut")
let { disableNetwork } = require("%globalScripts/clientState/initialState.nut")


 







function matching_subscribe(evtName, handler) {
  assert(type(evtName)=="string")
  let handlertype = type(handler)
  assert(handler == null || handlertype == "function")
  let is_rpc_call = handlertype == "function" && handler.getfuncinfos().parameters.len() > 2
  if (is_rpc_call) {
    
    matching_listen_rpc(evtName)
    eventbus_subscribe(evtName, function(evt) {
      
      let sendResp = function(resp_obj) {
        matching_send_response(evt, resp_obj)
      }
      handler(evt?.request, sendResp)
    })
  }
  else {
    matching_listen_notify(evtName)
    eventbus_subscribe(evtName, function(evt) {
      
      handler(evt)
    })
  }
}

function matching_rpc_call(cmd, params = null, cb = null) {
  assert(type(cmd)=="string")
  assert(params == null || type(params)=="table")
  assert(cb == null || type(cb) == "function")
  let res = matching_call(cmd, params)
  
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

  if (!showError || disableNetwork)
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
