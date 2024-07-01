from "%sqDagui/daguiNativeApi.nut" import *

let DaguiSceneTimers = require("daguiSceneTimers.nut")

const REPAY_TIME = 0.5

function mkHoverHoldAction(timerObj, repayTime = REPAY_TIME) {
  let timers = DaguiSceneTimers(0.1)
  timers.setUpdaterObj(timerObj)
  local allObjs = {}

  function hoverHoldAction(processObj, cb) {
    allObjs = allObjs.filter(@(_, o) o.isValid())

    let isHovered = processObj.isHovered()
    let existObj = allObjs.findindex(@(_, o) o.isEqual(processObj))
    if ((existObj != null) == isHovered)
      return

    if (existObj) {
      timers.removeTimer(allObjs[existObj])
      allObjs.$rawdelete(existObj)
      return
    }

    allObjs[processObj] <- timers.addTimer(repayTime,
      function () {
        if (processObj not in allObjs)
          return
        allObjs.$rawdelete(processObj)
        if (processObj.isValid() && processObj.isHovered())
          cb(processObj)
      }
    ).weakref()
  }

  return hoverHoldAction
}

return mkHoverHoldAction
