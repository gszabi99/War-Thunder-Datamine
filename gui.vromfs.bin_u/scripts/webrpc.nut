from "scriptRespondent" import registerRespondent
from "%scripts/dagui_library.nut" import *
from "types" import Table

let { mnSubscribe, mrSubscribe } = require("%scripts/matching/serviceNotifications/mrpc.nut")

let handlers = {}

function webRpcRegister(name, handler) {
  if (name in handlers)
    logerr($"Duplicate webRpc action {name}")
  handlers[name] <- handler
}

function handleUnsafe(call) {
  let func = call["func"]
  if (func not in handlers)
    return "RPC method not found"

  log($"called RPC function {func}")
  debugTableData(call)
  return handlers[func](call["params"])
}

function handleWebRpc(call) {
  try {
    return handleUnsafe(call)
  }
  catch (e) {
    log($"web rpc failed: {e}")
    return e
  }
}

registerRespondent("handle_web_rpc", handleWebRpc)

mnSubscribe("web-service", handleWebRpc)
mrSubscribe("web-service", function(params, cb) {
  let res = handleWebRpc(params)
  if (res instanceof Table)
    cb(res)
  else
    cb({ result = res })
})

return {
  webRpcRegister
}