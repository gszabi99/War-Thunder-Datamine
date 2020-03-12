/*

 g_delayed_actions.add(callback, delay)

 run callback no earlier than call time plus interval specified in 'delay' argument

 if 'delay' is set to zero, action will be called in current or next frame

*/

::g_delayed_actions <-
{
  delayedActionsList = []
  instantActionsList = []
  runInstantActionsTaskId = null
  runDelayedActionsTaskId = null

  function add(action, delay_ms = 0)
  {
    addDelayedAction(action, delay_ms)
  }

  function runDelayedActions(...)
  {
    local curTime = ::dagor.getCurTime()
    local callActions = []

    // actions is sorted by call time from last to first
    for (local i = delayedActionsList.len() - 1; i >= 0; --i)
    {
      local elem = delayedActionsList[i]
      if (elem.time <= curTime)
      {
        callActions.append(elem.action)
        delayedActionsList.pop()
      }
      else
        break
    }

    foreach (action in callActions)
      action()

    if (delayedActionsList.len() == 0 && runDelayedActionsTaskId != null)
    {
      ::periodic_task_unregister(runDelayedActionsTaskId)
      runDelayedActionsTaskId = null
    }
  }

  function runInstantActions(...)
  {
    local actions = instantActionsList
    instantActionsList = []

    foreach (action in actions)
      action()

    if (instantActionsList.len() == 0 && runInstantActionsTaskId != null)
    {
      ::periodic_task_unregister(runInstantActionsTaskId)
      runInstantActionsTaskId = null
    }
  }

  function addDelayedAction(action, delay_ms)
  {
    if (delay_ms > 0)
    {
      local callTime = ::dagor.getCurTime() + delay_ms
      delayedActionsList.append({action = action, time = callTime})
      delayedActionsList.sort(function (a, b)
      {
        return (b.time - a.time).tointeger()
      })

      if (runDelayedActionsTaskId == null)
      {
        runDelayedActionsTaskId = ::periodic_task_register(this, runDelayedActions, 1)
      }
    }
    else
    {
      instantActionsList.append(action)
      if (runInstantActionsTaskId == null)
      {
        runInstantActionsTaskId = ::periodic_task_register_ex(this,
                                                                 runInstantActions, 1,
                                                               ::EPTF_EXECUTE_IMMEDIATELY,
                                                               ::EPTT_BEST_EFFORT, true)
      }
    }
  }

  function test()
  {
    local curTime = ::dagor.getCurTime()
    for (local i = 0; i < 100; ++i)
    {
      local rndDelay = math.rnd() % 10

      add((@(i, rndDelay, curTime) function() {
            dagor.debug(::format("[%d] %d run action with delay %d seconds", curTime, i, rndDelay))
          })(i, rndDelay, curTime),
      rndDelay * 1000)
    }
  }
}
