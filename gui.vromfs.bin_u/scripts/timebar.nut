//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

/**
 * Some utility functions for work with timBar gui object
 */

let { fabs } = require("math")

::g_time_bar <- {
  _direction = {
    backward = {
      incSignMultiplier = -1
    }
    forward = {
      incSignMultiplier = 1
    }
  }

  /**
   * Set full period time to timeBar
   * @time_bar_obj - timeBar object
   * @period_time - time in seconds
   */
  function setPeriod(timeBarObj, periodTime, isCyclic = false) {
    let speed = periodTime ? 360.0 / periodTime : 0
    this._setSpeed(timeBarObj, speed)

    if (isCyclic) {
      timeBarObj["inc-min"] = "0.0"
      timeBarObj["inc-max"] = "360.0"
      timeBarObj["inc-is-cyclic"] = "yes"
    }
  }

  function _setSpeed(timeBarObj, speed) {
    speed = this.getDirection(timeBarObj).incSignMultiplier * fabs(speed)
    timeBarObj["inc-factor"] = speed.tostring()
  }

  function _getSpeed(timeBarObj) {
    return (timeBarObj?["inc-factor"] ?? 0).tofloat()
  }

  /**
   * Set current time to timeBar
   * @time_bar_obj - timeBar object
   * @current_time - time in seconds
   */
  function setCurrentTime(timeBarObj, currentTime) {
    let curVal = currentTime * this._getSpeed(timeBarObj)
    timeBarObj["sector-angle-2"] = curVal.tostring()
  }

  function setValue(timeBarObj, value) {
    timeBarObj["sector-angle-2"] = (360 * value).tointeger().tostring()
  }

  function getDirection(timeBarObj) {
    return this._direction[this.getDirectionName(timeBarObj)]
  }

  function getDirectionName(timeBarObj) {
    if (timeBarObj?.direction != null)
      return timeBarObj.direction
    else
      return "forward"
  }

  /**
   * Set clockwise direction of time bar.
   * @time_bar_obj - timeBar object
   */
  function setDirectionForward(timeBarObj) {
    this._setDirection(timeBarObj, "forward")
  }

  /**
   * Set counter clockwise direction of time bar.
   * @time_bar_obj - timeBar object
   */
  function setDirectionBackward(timeBarObj) {
    this._setDirection(timeBarObj, "backward")
  }

  /**
   * Toggle direction of time bar.
   * @time_bar_obj - timeBar object
   */
  function toggleDirection(timeBarObj) {
    this._setDirection(timeBarObj, this.getDirectionName(timeBarObj) == "forward" ? "backward" : "forward")
  }

  function _setDirection(timeBarObj, direction) {
    let w = this._getSpeed(timeBarObj)
    timeBarObj.direction = direction
    this._setSpeed(timeBarObj, w)
  }
}
