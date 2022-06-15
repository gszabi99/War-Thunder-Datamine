 /*
 module with low-level matching server interface

 matching_rpc_subscribe - set handler for server-side rpc or notification
 matching_api_func - call remote function by name and set callback for answer
 matching_api_notify - call remote function without callback
*/

let _matching = {
  function translate_matching_params(params)
  {
    if (params == null)
      return params
    foreach(key, value in params)
    {
      if (typeof value == "string")
      {
        switch (key)
        {
          case "userId":
          case "roomId":
            params[key] = value.tointeger()
        }
      }
    }
    return params
  }
}

/*
  translate old API functions into new ones
  TODO: remove them by search&replace
*/
::matching_api_func <- function matching_api_func(name, cb, params = null)
{
  ::dagor.debug("send matching request: " + name)
  matching.rpc_call(name, _matching.translate_matching_params(params),
    function (resp)
    {
      if (cb)
        cb(resp)
    })
}

::matching_api_notify <- function matching_api_notify(name, params = null)
{
  ::dagor.debug("send matching notify: " + name)
  matching.notify(name, _matching.translate_matching_params(params))
}

::is_matching_error <- function is_matching_error(code)
{
  if ("matching" in getroottable())
    return ::matching.is_matching_error(code)
  return false
}

::matching_error_string <- function matching_error_string(code)
{
  if ("matching" in getroottable())
    return ::matching.error_string(code)
  return false
}

::matching_rpc_subscribe <- function matching_rpc_subscribe(name, cb)
{
  if ("matching" in getroottable())
    ::matching.subscribe(name, cb)
}

