from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

::web_rpc <- {
  handlers = {}

  function register_handler(func_name, handler)
  {
    this.handlers[func_name] <- handler
  }

  function handle_web_rpc_unsafe(call)
  {
    let func = call["func"]
    if (!(func in this.handlers))
      return "RPC method not found"

    log("called RPC function " + func)
    debugTableData(call)
    return this.handlers[func](call["params"])
  }
}

::handle_web_rpc <- function handle_web_rpc(call)
{
  try {
    return ::web_rpc.handle_web_rpc_unsafe(call)
  }
  catch (e)
  {
    log("web rpc failed: " + e)
    return e
  }
}

/*
 this is just example
*/
let function rpc_add(params) {
  return (params.a + params.b).tostring()
}

::web_rpc.register_handler("plus", rpc_add)
