::web_rpc <- {
  handlers = {}

  function register_handler(func_name, handler)
  {
    handlers[func_name] <- handler
  }

  function handle_web_rpc_unsafe(call)
  {
    let func = call["func"]
    if (!(func in handlers))
      return "RPC method not found"

    ::dagor.debug("called RPC function " + func)
    ::debugTableData(call)
    return handlers[func](call["params"])
  }
}

::handle_web_rpc <- function handle_web_rpc(call)
{
  try {
    return web_rpc.handle_web_rpc_unsafe(call)
  }
  catch (e)
  {
    ::dagor.debug("web rpc failed: " + e)
    return e
  }
}

/*
 this is just example
*/
::rpc_add <- function rpc_add(params)
{
  return (params.a + params.b).tostring()
}

web_rpc.register_handler("plus", rpc_add)
