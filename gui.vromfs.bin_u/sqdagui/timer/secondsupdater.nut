local u = require("sqStdLibs/helpers/u.nut")
::g_script_reloader.loadOnce("sqDagui/daguiUtil.nut")  //!!FIX ME: better to make this modules too

local SecondsUpdater = class
{
  timer = 0.0
  updateFunc = null
  params = null
  nestObj = null
  timerObj = null
  destroyTimerObjOnFinish = false

  function getUpdaterByNestObj(_nestObj)
  {
    local userData = _nestObj.getUserData()
    if (u.isSecondsUpdater(userData))
      return userData

    local _timerObj = _nestObj.findObject(getTimerObjIdByNestObj(_nestObj))
    if (_timerObj == null)
      return null

    userData = _timerObj.getUserData()
    if (u.isSecondsUpdater(userData))
      return userData

    return null
  }

  constructor(_nestObj, _updateFunc, useNestAsTimerObj = true, _params = {})
  {
    if (!_updateFunc)
      return ::dagor.assertf(false, "Error: no updateFunc in seconds updater.")

    nestObj    = _nestObj
    updateFunc = _updateFunc
    params     = _params
    local lastUpdaterByNestObject = getUpdaterByNestObj(_nestObj)
    if (lastUpdaterByNestObject != null)
      lastUpdaterByNestObject.remove()

    if (updateFunc(nestObj, params))
      return

    timerObj = useNestAsTimerObj ? nestObj : createTimerObj(nestObj)
    if (!timerObj)
      return

    destroyTimerObjOnFinish = !useNestAsTimerObj
    timerObj.timer_handler_func = "onUpdate"
    timerObj.timer_interval_msec = "1000"
    timerObj.setUserData(this)
  }

  function createTimerObj(_nestObj)
  {
    local blkText = "dummy {id:t = '" + getTimerObjIdByNestObj(_nestObj) + "' behavior:t = 'Timer' }"
    _nestObj.getScene().appendWithBlk(_nestObj, blkText, null)
    local index = _nestObj.childrenCount() - 1
    local resObj = index >= 0 ? _nestObj.getChild(index) : null
    if (resObj?.tag == "dummy")
      return resObj
    return null
  }

  function onUpdate(obj, dt)
  {
    if (updateFunc(nestObj, params))
      remove()
  }

  function remove()
  {
    if (!::check_obj(timerObj))
      return

    timerObj.setUserData(null)
    if (destroyTimerObjOnFinish)
      timerObj.getScene().destroyElement(timerObj)
  }

  function getTimerObjIdByNestObj(_nestObj)
  {
    return "seconds_updater_" + (_nestObj?.id ?? "")
  }
}

u.registerClass("SecondsUpdater", SecondsUpdater)

return SecondsUpdater