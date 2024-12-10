from "%scripts/dagui_library.nut" import *


/**
 * Some utility functions for work with timBar gui object
 */

let { fabs } = require("math")

let _direction = {
  backward = {
    incSignMultiplier = -1
  }
  forward = {
    incSignMultiplier = 1
  }
  stationary = {
    incSignMultiplier = 0
  }
}

let setValue = @(timeBarObj, value) timeBarObj["sector-angle-2"] = (360 * value).tointeger().tostring()

let _getSpeed = @(timeBarObj) (timeBarObj?["inc-factor"] ?? 0).tofloat()

function setCurrentTime(timeBarObj, currentTime) {
  let curVal = currentTime * _getSpeed(timeBarObj)
  timeBarObj["sector-angle-2"] = curVal.tostring()
}

let getDirectionName = @(timeBarObj) (timeBarObj?.direction != null) ? timeBarObj.direction : "forward"

/**
 * Set current time to timeBar
 * @time_bar_obj - timeBar object
 * @current_time - time in seconds
 */

let getDirection = @(timeBarObj)_direction[getDirectionName(timeBarObj)]

function _setSpeed(timeBarObj, speed) {
  speed = getDirection(timeBarObj).incSignMultiplier * fabs(speed)
  timeBarObj["inc-factor"] = speed.tostring()
}

function _setDirection(timeBarObj, direction) {
  let w = _getSpeed(timeBarObj)
  timeBarObj.direction = direction
  _setSpeed(timeBarObj, w)
}

let pauseTimer = @(timeBarObj) _setSpeed(timeBarObj, 0)

/**
 * Set full period time to timeBar
 * @time_bar_obj - timeBar object
 * @period_time - time in seconds
 */
function setPeriod(timeBarObj, periodTime, isCyclic = false) {
  let speed = periodTime ? 360.0 / periodTime : 0
  _setSpeed(timeBarObj, speed)

  if (isCyclic) {
    timeBarObj["inc-min"] = "0.0"
    timeBarObj["inc-max"] = "360.0"
    timeBarObj["inc-is-cyclic"] = "yes"
  }
}

let setDirectionForward = @(timeBarObj) _setDirection(timeBarObj, "forward")

let setDirectionBackward = @(timeBarObj) _setDirection(timeBarObj, "backward")

let toggleDirection= @(timeBarObj)
  _setDirection(timeBarObj, getDirectionName(timeBarObj) == "forward" ? "backward" : "forward")

let g_time_bar = {
  setValue
  _getSpeed
  setCurrentTime
  getDirectionName
  getDirection
  pauseTimer
  _setSpeed
  setPeriod
  toggleDirection
  setDirectionBackward
  setDirectionForward
}

return {
  g_time_bar
}