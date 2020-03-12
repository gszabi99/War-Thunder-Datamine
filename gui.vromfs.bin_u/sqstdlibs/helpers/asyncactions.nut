//call actions one by one by action callback.
//each action must be a callable object or function with a single parameter - callback on finish
local callAsyncActionsList = null
callAsyncActionsList = function(actionsList) {
  if (!actionsList.len())
    return

  local action = actionsList.remove(0)
  action(@(...) callAsyncActionsList(actionsList))
}

return {
  callAsyncActionsList = callAsyncActionsList
}