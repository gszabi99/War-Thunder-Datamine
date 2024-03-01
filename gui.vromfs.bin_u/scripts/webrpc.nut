from "%scripts/dagui_library.nut" import *
let { mnSubscribe, mrSubscribe } = require("%scripts/matching/serviceNotifications/mrpc.nut")
let { registerRespondent } = require("scriptRespondent")

let web_rpc = {
  handlers = {}

  function register_handler(func_name, handler) {
    this.handlers[func_name] <- handler
  }

  function handle_web_rpc_unsafe(call) {
    let func = call["func"]
    if (!(func in this.handlers))
      return "RPC method not found"

    log($"called RPC function {func}")
    debugTableData(call)
    return this.handlers[func](call["params"])
  }
}

function handleWebRpc(call) {
  try {
    return web_rpc.handle_web_rpc_unsafe(call)
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
  if (type(res) == "table")
    cb(res)
  else
    cb({ result = res })
})

/*
 this is just example
function rpc_add(params) {
  return (params.a + params.b).tostring()
}
web_rpc.register_handler("plus", rpc_add)
*/
return {web_rpc}