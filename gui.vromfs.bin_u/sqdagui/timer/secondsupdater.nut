#explicit-this
#no-root-fallback

let u = require("%sqStdLibs/helpers/u.nut")
let { check_obj } = require("%sqDagui/daguiUtil.nut")
::g_script_reloader.loadOnce("%sqDagui/daguiUtil.nut")  //!!FIX ME: better to make this modules too

let class SecondsUpdater
{
  timer = 0.0
  updateFunc = null
  params = null
  nestObj = null
  timerObj = null
  destroyTimerObjOnFinish = false

  function getUpdaterByNestObj(nestObj_)
  {
    local userData = nestObj_.getUserData()
    if (u.isSecondsUpdater(userData))
      return userData

    local _timerObj = nestObj_.findObject(this.getTimerObjIdByNestObj(nestObj_))
    if (_timerObj == null)
      return null

    userData = _timerObj.getUserData()
    if (u.isSecondsUpdater(userData))
      return userData

    return null
  }

  constructor(nestObj_, updateFunc_, useNestAsTimerObj = true, params_ = {})
  {
    if (!updateFunc_)
      return assert(false, "Error: no updateFunc in seconds updater.")

    this.nestObj    = nestObj_
    this.updateFunc = updateFunc_
    this.params     = params_
    local lastUpdaterByNestObject = this.getUpdaterByNestObj(nestObj_)
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

  function createTimerObj(nestObj_)
  {
    local blkText = "".concat("dummy{id:t='", this.getTimerObjIdByNestObj(nestObj_), "' behavior:t='Timer'}")
    nestObj_.getScene().appendWithBlk(nestObj_, blkText, null)
    local index = nestObj_.childrenCount() - 1
    local resObj = index >= 0 ? nestObj_.getChild(index) : null
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
    if (!check_obj(this.timerObj))
      return

    this.timerObj.setUserData(null)
    if (this.destroyTimerObjOnFinish)
      this.timerObj.getScene().destroyElement(this.timerObj)
  }

  function getTimerObjIdByNestObj(nestObj_)
  {
    return $"seconds_updater_{nestObj_?.id ?? ""}"
  }
}

u.registerClass("SecondsUpdater", SecondsUpdater)

return SecondsUpdater