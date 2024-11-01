from "%scripts/dagui_library.nut" import *

let { defer } = require("dagor.workcycle")

//!!FIX ME: replace by real threads after fix crash of datablock in sq thread
let PT_STEP_STATUS = {
  NEXT_STEP = 0  //default status
  SKIP_DELAY = 1 //for steps which do nothing no need to delay
  SUSPEND = 2
}

function startPseudoThread(actionsList, onCrash = null, step = 0) {
  let self = callee()
  defer(function() {
    local curStep = step
    while (curStep in actionsList) {
      local stepStatus = PT_STEP_STATUS.NEXT_STEP
      try {
        stepStatus = actionsList[curStep]()
      }
      catch(e) {
        log($"Crash in pseudo thread step = {curStep}, status = {stepStatus}")
        if (onCrash) {
          onCrash()
          return
        }
      }

      if (stepStatus != PT_STEP_STATUS.SUSPEND)
        curStep++

      if (stepStatus == PT_STEP_STATUS.SKIP_DELAY)
        continue

      if (curStep in actionsList)
        self(actionsList, onCrash, curStep)
      break
    }
  })
}

return {
  PT_STEP_STATUS
  startPseudoThread
}