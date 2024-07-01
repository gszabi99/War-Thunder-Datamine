from "%sqDagui/daguiNativeApi.nut" import *

let { check_obj } = require("%sqDagui/daguiUtil.nut")

const TIME_INTERVAL_SWITCH_OFF = 1000000.0

let DaguiSceneTimers = class {

  timersList = null
  updaterObj = null
  updateInterval = 1.0
  curTime = null

  constructor(updateInterval_, persistentDataUid = null) {
    this.timersList = persistentDataUid != null ? persist($"DaguiSceneTimers_{persistentDataUid}_timerList", @() []) : []
    this.curTime = persistentDataUid != null ? persist($"DaguiSceneTimers_{persistentDataUid}_curTime", @() {v = 0.0}) : {v = 0.0}
    this.updateInterval = updateInterval_
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function addTimer(time, action) {
    let timer = {
      time = time + this.curTime.v
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
    timer.time = time + this.curTime.v
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
    this.curTime.v = 0.0
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function onUpdate(_obj, dt) {
    this.curTime.v += dt
    foreach (timer in this.timersList) {
      if (timer.time > this.curTime.v)
        break

      timer.action()
      this.removeTimer(timer)
    }
  }

  function sortTimers() {
    this.timersList.sort(@(a, b) a.time <=> b.time)
  }

  function setObjTimeInterval(obj, interval) {
     obj.timer_interval_msec = (1000 * interval).tointeger().tostring()
  }
}

return DaguiSceneTimers