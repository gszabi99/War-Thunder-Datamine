from "%scripts/dagui_library.nut" import *
let { APP_ID } = require("app")
let { debug } = require("dagor.debug")
let { eventbus_subscribe } = require("eventbus")
let { shortValue, shortKeyValue } = require("%appGlobals/charClientUtils.nut")
//#strict

/*
Usage:
  local client = CharClientEvent(name, nativeClient)
  client.request("action1")                // send action
  client.request("action1", {foo = bar})   // send action with parameters
  registerHandler("action1", function(result))  // accept result

Multiple handlers for one action:
  client.request("action2:foo")
  registerHandler("action2:foo", function(result))
  registerHandler("action2:bar", function(result))

Handler parameters in context:
  client.request("action3", {...}, {foo = bar})
  registerHandler("action3", function(result, context) { local foo = context?.foo })

External custom executors:
  client.request("action4", {...}, { executeBefore = "foo", executeAfter = "bar" })
  registerHandler("action4", function(result))
  registerExecutor("foo", function(result))
  registerExecutor("bar", function(result))

Handler and executor behavior should depend only on result from server and context.
Script reload can occur between request and handler.
*/

let mkRegister = @(list, listName) function(id, action) {
  if (id in list) {
    assert(false, $"{id} is already registered to {listName}")
    return
  }
  let nargs = action.getfuncinfos().parameters.len() - 1
  assert(nargs == 1 || nargs == 2, $"action {id} has wrong number of parameters. Should be 1 or 2")
  list[id] <- action
}

function charClientEvent(name, client) {
  let event = $"charclient.{name}"
  let handlers = {} //main action callback
  let executors = {} //external callback
  let doRequest = @(params, context) client.requestEventBus(params, event, context)

  local function request(handler, params, context, isExternal) {
    params = clone params
    let func = $"{name}.{handler} request"
    if (!isExternal)
      assert(handler in handlers, $"{func}: Unknown handler '{handler}'")
    debug($"{func} {shortValue(params)}{shortValue(context)}")

    let sepIdx = handler.indexof(":")
    params.action <- sepIdx == null ? handler : handler.slice(sepIdx)
    if (sepIdx != null) {
      context = clone (context ?? {})
      context["$handlerId"] <- handler
    }

    params.headers <- clone (params?.headers ?? {})
    let { headers } = params
    if ("appid" not in headers)
      headers.appid <- APP_ID

    if ("token" not in headers && "userid" not in headers)
      params.add_token <- true

    doRequest(params, context)
  }

  function call(table, key, result, context, label, msg) {
    let callback = table?[key]
    if (callback == null)
      return

    let nargs = callback.getfuncinfos().parameters.len() - 1
    let output = (nargs == 1) ? callback(result) : callback(result, context)
    if (output == null)
      debug($"{label} {msg}")
    else
      debug($"{label} {msg}: {shortKeyValue(output)}")
  }

  local function process(r) {
    local result = clone r
    if ("$action" not in result) {
      assert(false, @()$"{name} process: No '$action' in result")
      return
    }
    let action  = result.$rawdelete("$action")
    let context = result?.$rawdelete("$context")
    let handler = ("$handlerId" in context) ? context.$rawdelete("$handlerId") : action
    let label   = $"{name}.{handler}"

    // check any error answer from server
    let response = result?.response
    let success  = response?.success ?? true

    if (!success || "error" in result) {
      if (!success && "error" in response) {
        result = response  // {success = false, error = ..., ...}
      }
      else {
        local err = "unknown error"
        if ("error" in result)
          err = result.error
        else if ("error" in response)
          err = response.error
        result = { success = false, error = err }
      }

      debug($"{label} error: {shortKeyValue(result.error)}")
    }

    call(executors, context?.executeBefore, result, context, label, $"executeBefore({context?.executeBefore})")
    call(handlers, handler, result, context, label, "completed")
    call(executors, context?.executeAfter, result, context, label, $"executeAfter({context?.executeAfter})")
  }

  debug($"Init CharClientEvent {name}")
  eventbus_subscribe(event, process)

  eventbus_subscribe($"charClientEvent.{name}.request", @(msg) request(msg.handler, msg?.params ?? {}, msg?.context, true))

  return {
    request = @(handler, params = {}, context = null) request(handler, params, context, false)
    registerHandler = mkRegister(handlers, $"{name}.handlers")
    registerExecutor = mkRegister(executors, $"{name}.executors")
  }
}

return charClientEvent

