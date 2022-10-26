#no-root-fallback
#explicit-this

let { check_obj } = require("%sqDagui/daguiUtil.nut")
let { g_script_reloader, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

g_script_reloader.loadOnce("%sqDagui/daguiUtil.nut") //!!FIX ME: better to make this modules too

const TIME_INTERVAL_SWITCH_OFF = 1000000.0

local DaguiSceneTimers = class {
  [PERSISTENT_DATA_PARAMS] = ["timersList", "curTime"]

  timersList = null
  updaterObj = null
  updateInterval = 1.0
  curTime = 0.0

  constructor(updateInterval_, persistentDataUid = null) {
    this.timersList = []
    this.updateInterval = updateInterval_
    if (persistentDataUid)
      g_script_reloader.registerPersistentData($"DaguiSceneTimers_{persistentDataUid}", this, [PERSISTENT_DATA_PARAMS])
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function addTimer(time, action) {
    let timer = {
      time = time + this.curTime
      action = action
    }
    this.timersList.append(timer)
    this.sortTimers()
    return timer
  }

  function removeTimer(timer) {
    let idx = this.timersList.indexof(timer)
    if (idx != null)
      this.timersList.remove(idx)
  }

  function setTimerTime(timer, time) {
    timer.time = time + this.curTime
    this.sortTimers()
  }

  function setUpdaterObj(obj) {
    if (check_obj(this.updaterObj)) {
      this.setObjTimeInterval(this.updaterObj, TIME_INTERVAL_SWITCH_OFF)
      this.updaterObj.setUserData(null)
    }
    if (!check_obj(obj)) {
      this.updaterObj = null
      return
    }

    this.updaterObj = obj
    this.updaterObj.timer_handler_func = "onUpdate"
    this.updaterObj.setUserData(this)
    this.setObjTimeInterval(this.updaterObj, this.updateInterval)
  }

  function setUpdateInterval(timeSec) {
    this.updateInterval = timeSec
    if (check_obj(this.updaterObj))
      this.setObjTimeInterval(this.updaterObj, this.updateInterval)
  }

  function reset() {
    this.resetTimers()
    this.setUpdaterObj(null)
  }

  function resetTimers() {
    this.timersList.clear()
    this.curTime = 0.0
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function onUpdate(_obj, dt) {
    this.curTime += dt
    foreach(timer in this.timersList) {
      if (timer.time > this.curTime)
        break

      timer.action()
      this.removeTimer(timer)
    }
  }

  function sortTimers() {
    this.timersList.sort(@(a, b) a.time <=> b.time)
  }

  function setObjTimeInterval(obj, interval)
  {
     obj.timer_interval_msec = (1000 * interval).tointeger().tostring()
  }
}

return DaguiSceneTimers