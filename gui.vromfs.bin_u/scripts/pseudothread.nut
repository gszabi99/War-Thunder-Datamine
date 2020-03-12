//!!FIX ME: replace by real threads after fix crash of datablock in sq thread
global enum PT_STEP_STATUS {
  NEXT_STEP = 0  //default status
  SKIP_DELAY //for steps which do nothing no need to delay
  SUSPEND
}

::start_pseudo_thread <- function start_pseudo_thread(actionsList, onCrash = null, step = 0)
{
  ::handlersManager.doDelayed(function() {
    local curStep = step
    while(curStep in actionsList)
    {
      local stepStatus = PT_STEP_STATUS.NEXT_STEP
      try {
        stepStatus = actionsList[curStep]()
      }
      catch(e)
      {
        dagor.debug("Crash in pseudo thread step = " + curStep + ", status = " + stepStatus)
        if (onCrash)
        {
          onCrash()
          return
        }
      }

      if (stepStatus != PT_STEP_STATUS.SUSPEND)
        curStep++

      if (stepStatus == PT_STEP_STATUS.SKIP_DELAY)
        continue

      if (curStep in actionsList)
        ::start_pseudo_thread(actionsList, onCrash, curStep)
      break
    }
  })
}