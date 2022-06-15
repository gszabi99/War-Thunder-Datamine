let u = require("%sqStdLibs/helpers/u.nut")
::g_script_reloader.loadOnce("%sqDagui/daguiUtil.nut")  //!!FIX ME: better to make this modules too

let class SecondsUpdater
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

    local _timerObj = _nestObj.findObject(this.getTimerObjIdByNestObj(_nestObj))
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

    this.nestObj    = _nestObj
    this.updateFunc = _updateFunc
    this.params     = _params
    local lastUpdaterByNestObject = this.getUpdaterByNestObj(_nestObj)
    if (lastUpdaterByNestObject != null)
      lastUpdaterByNestObject.remove()

    if (this.updateFunc(this.nestObj, this.params))
      return

    this.timerObj = useNestAsTimerObj ? this.nestObj : this.createTimerObj(this.nestObj)
    if (!this.timerObj)
      return

    this.destroyTimerObjOnFinish = !useNestAsTimerObj
    this.timerObj.timer_handler_func = "onUpdate"
    this.timerObj.timer_interval_msec = "1000"
    this.timerObj.setUserData(this)
  }

  function createTimerObj(_nestObj)
  {
    local blkText = "dummy {id:t = '" + this.getTimerObjIdByNestObj(_nestObj) + "' behavior:t = 'Timer' }"
    _nestObj.getScene().appendWithBlk(_nestObj, blkText, null)
    local index = _nestObj.childrenCount() - 1
    local resObj = index >= 0 ? _nestObj.getChild(index) : null
    if (resObj?.tag == "dummy")
      return resObj
    return null
  }

  function onUpdate(obj, dt)
  {
    if (this.updateFunc(this.nestObj, this.params))
      this.remove()
  }

  function remove()
  {
    if (!::check_obj(this.timerObj))
      return

    this.timerObj.setUserData(null)
    if (this.destroyTimerObjOnFinish)
      this.timerObj.getScene().destroyElement(this.timerObj)
  }

  function getTimerObjIdByNestObj(_nestObj)
  {
    return "seconds_updater_" + (_nestObj?.id ?? "")
  }
}

u.registerClass("SecondsUpdater", SecondsUpdater)

return SecondsUpdater