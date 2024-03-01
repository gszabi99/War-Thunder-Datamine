//-file:plus-string
from "%scripts/dagui_library.nut" import *

 /*
 module with low-level matching server interface

 matchingRpcSubscribe - set handler for server-side rpc or notification
 matchingApiFunc - call remote function by name and set callback for answer
 matchingApiNotify - call remote function without callback
*/

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
  log("send matching request: " + name)
  ::matching.rpc_call(name, translateMatchingParams(params), @(resp) cb?(resp))
}

function matchingApiNotify(name, params = null) {
  log("send matching notify: " + name)
  ::matching.notify(name, translateMatchingParams(params))
}

function isMatchingError(code) {
  if ("matching" in getroottable())
    return ::matching.is_matching_error(code)
  return false
}

function matchingErrorString(code) {
  if ("matching" in getroottable())
    return ::matching.error_string(code)
  return false
}

function matchingRpcSubscribe(name, cb) {
  if ("matching" in getroottable())
    ::matching.subscribe(name, cb)
}

return {
  matchingApiFunc
  matchingApiNotify
  isMatchingError
  matchingErrorString
  matchingRpcSubscribe
}