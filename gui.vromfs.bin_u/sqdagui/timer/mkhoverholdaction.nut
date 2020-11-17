local DaguiSceneTimers = require("daguiSceneTimers.nut")

const REPAY_TIME = 0.5

local function mkHoverHoldAction(timerObj, repayTime = REPAY_TIME) {
  local timers = DaguiSceneTimers(0.1)
  timers.setUpdaterObj(timerObj)
  local allObjs = {}

  local function hoverHoldAction(processObj, cb) {
    allObjs = allObjs.filter(@(_, o) o.isValid())

    local isHovered = processObj.isHovered()
    local existObj = allObjs.findindex(@(_, o) o.isEqual(processObj))
    if ((existObj != null) == isHovered)
      return

    if (existObj) {
      timers.removeTimer(allObjs[existObj])
      delete allObjs[existObj]
      return
    }

    allObjs[processObj] <- timers.addTimer(repayTime,
      function () {
        if (processObj not in allObjs)
          return
        delete allObjs[processObj]
        if (processObj.isValid() && processObj.isHovered())
          cb(processObj)
      }
    ).weakref()
  }

  return hoverHoldAction
}

return mkHoverHoldAction
