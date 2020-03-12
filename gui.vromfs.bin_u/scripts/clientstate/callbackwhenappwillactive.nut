const FREQUENCY_APP_STATE_UPDATE_SEC = 1
local refreshActiveAppTask = -1
local callbacksArray = []
local isAppActive = true

local function callIsAppActiveOrRegisterTask( dt = 0 ) { return null }
callIsAppActiveOrRegisterTask = function( dt = 0 )
{
  if ( refreshActiveAppTask >= 0 )
  {
    ::periodic_task_unregister( refreshActiveAppTask )
    refreshActiveAppTask = -1
  }

  local needUpdateTimer = false
  local isActive = ::is_app_active() && !::steam_is_overlay_active() && !::is_builtin_browser_active()
  if (isAppActive == isActive)
    needUpdateTimer = true

  if (!isActive)
    needUpdateTimer = true

  isAppActive = isActive
  if (needUpdateTimer)
  {
    refreshActiveAppTask = ::periodic_task_register(this,
      callIsAppActiveOrRegisterTask, FREQUENCY_APP_STATE_UPDATE_SEC)

    return
  }

  local list = clone callbacksArray
  callbacksArray.clear()
  foreach(cb in list)
    cb()
}

local function callbackWhenAppWillActive(cb)
{
  callbacksArray.append(cb)
  callIsAppActiveOrRegisterTask()
}


return callbackWhenAppWillActive
