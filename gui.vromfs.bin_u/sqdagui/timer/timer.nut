from "%sqDagui/daguiNativeApi.nut" import *

let Callback = require("%sqStdLibs/helpers/callback.nut").Callback
let { check_obj } = require("%sqDagui/daguiUtil.nut")

let Timer = class {
  onTimeOut   = null
  cycled      = false
  isDelayed   = false
  guiScene    = null
  timerGuiObj = null

  static timeNowPID = dagui_propid_add_name_id("timer-timenow")

  constructor(parentObj, delay, onTimeOut_, handler = null, cycled_ = false, isDelayed_ = false) {
    if (!onTimeOut_)
      return assert(false, "Error: no onTimeOut in Timer.")

    this.onTimeOut = handler ? Callback(onTimeOut_, handler) : onTimeOut_
    this.cycled    = cycled_
    this.isDelayed = isDelayed_

    this.guiScene = parentObj.getScene()
    this.timerGuiObj = this.guiScene.createElement(parentObj, "timer", this)
    this.timerGuiObj.timer_handler_func = "onUpdate"
    this.timerGuiObj.timer_interval_msec = (delay * 1000.0).tointeger().tostring()
    this.timerGuiObj.setUserData(this)
  }

  function onUpdate(_obj, _dt) {
    this.performAction()

    if (!this.cycled)
      this.destroy()
  }

  function performAction() {
    if (!this.isDelayed)
      this.onTimeOut()
    else
      this.guiScene.performDelayed(this, (@(onTimeOut) function() { onTimeOut() })(this.onTimeOut)) 
  }

  function setDelay(newDelay) {
    if (check_obj(this.timerGuiObj)) {
      this.timerGuiObj.timer_interval_msec = (newDelay * 1000.0).tointeger().tostring()
      this.timerGuiObj.setIntProp(this.timeNowPID, 0)
    }
  }

  function setCb(onTimeOut_) {
    this.onTimeOut = onTimeOut_
  }

  function destroy() {
    if (check_obj(this.timerGuiObj)) {
      this.timerGuiObj.setUserData(null)
      this.guiScene.destroyElement(this.timerGuiObj)
    }
  }

  function isValid() {
    return check_obj(this.timerGuiObj)
  }
}
return {Timer}