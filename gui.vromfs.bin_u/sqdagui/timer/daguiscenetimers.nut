global const PERSISTENT_DATA_PARAMS = "PERSISTENT_DATA_PARAMS"
::g_script_reloader.loadOnce("sqDagui/daguiUtil.nut") //!!FIX ME: better to make this modules too

const TIME_INTERVAL_SWITCH_OFF = 1000000.0

local DaguiSceneTimers = class
{
  [PERSISTENT_DATA_PARAMS] = ["timersList", "curTime"]

  timersList = null
  updaterObj = null
  updateInterval = 1.0
  curTime = 0.0

  constructor(_updateInterval, persistentDataUid = null)
  {
    timersList = []
    updateInterval = _updateInterval
    if (persistentDataUid)
      ::g_script_reloader.registerPersistentData("DaguiSceneTimers_" + persistentDataUid, this, [PERSISTENT_DATA_PARAMS])
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function addTimer(time, action)
  {
    local timer = {
      time = time + curTime
      action = action
    }
    timersList.append(timer)
    sortTimers()
    return timer
  }

  function removeTimer(timer)
  {
    local idx = timersList.indexof(timer)
    if (idx != null)
      timersList.remove(idx)
  }

  function setTimerTime(timer, time)
  {
    timer.time = time + curTime
    sortTimers()
  }

  function setUpdaterObj(obj)
  {
    if (::check_obj(updaterObj))
    {
      setObjTimeInterval(updaterObj, TIME_INTERVAL_SWITCH_OFF)
      updaterObj.setUserData(null)
    }
    if (!::check_obj(obj))
    {
      updaterObj = null
      return
    }

    updaterObj = obj
    updaterObj.timer_handler_func = "onUpdate"
    updaterObj.setUserData(this)
    setObjTimeInterval(updaterObj, updateInterval)
  }

  function setUpdateInterval(timeSec)
  {
    updateInterval = timeSec
    if (::check_obj(updaterObj))
      setObjTimeInterval(updaterObj, updateInterval)
  }

  function reset()
  {
    resetTimers()
    setUpdaterObj(null)
  }

  function resetTimers()
  {
    timersList.clear()
    curTime = 0.0
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function onUpdate(obj, dt)
  {
    curTime += dt
    foreach(timer in timersList)
    {
      if (timer.time > curTime)
        break

      timer.action()
      removeTimer(timer)
    }
  }

  function sortTimers()
  {
    timersList.sort(@(a, b) a.time <=> b.time)
  }

  function setObjTimeInterval(obj, interval)
  {
     obj.timer_interval_msec = (1000 * interval).tointeger().tostring()
  }
}

return DaguiSceneTimers