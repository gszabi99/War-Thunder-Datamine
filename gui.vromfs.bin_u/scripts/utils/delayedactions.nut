//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { rnd_int } = require("dagor.random")
let { get_time_msec } = require("dagor.time")

/*

 g_delayed_actions.add(callback, delay)

 run callback no earlier than call time plus interval specified in 'delay' argument

 if 'delay' is set to zero, action will be called in current or next frame

*/

local delayedActionsList = []
local instantActionsList = []
local runInstantActionsTaskId = null
local runDelayedActionsTaskId = null


let function runDelayedActions(...) {
  let curTime = get_time_msec()
  let callActions = []

  // actions is sorted by call time from last to first
  for (local i = delayedActionsList.len() - 1; i >= 0; --i) {
    let elem = delayedActionsList[i]
    if (elem.time <= curTime) {
      callActions.append(elem.action)
      delayedActionsList.pop()
    }
    else
      break
  }

  foreach (action in callActions)
    action()

  if (delayedActionsList.len() == 0 && runDelayedActionsTaskId != null) {
    ::periodic_task_unregister(runDelayedActionsTaskId)
    runDelayedActionsTaskId = null
  }
}

let function runInstantActions(...) {
  let actions = instantActionsList
  instantActionsList = []

  foreach (action in actions)
    action()

  if (instantActionsList.len() == 0 && runInstantActionsTaskId != null) {
    ::periodic_task_unregister(runInstantActionsTaskId)
    runInstantActionsTaskId = null
  }
}

let function addDelayedAction(action, delay_ms) {
  if (delay_ms > 0) {
    let callTime = get_time_msec() + delay_ms
    delayedActionsList.append({ action = action, time = callTime })
    delayedActionsList.sort(function (a, b) {
      return (b.time - a.time).tointeger()
    })

    if (runDelayedActionsTaskId == null) {
      runDelayedActionsTaskId = ::periodic_task_register(this, runDelayedActions, 1)
    }
  }
  else {
    instantActionsList.append(action)
    if (runInstantActionsTaskId == null) {
      runInstantActionsTaskId = ::periodic_task_register_ex(this,
                                                               runInstantActions, 1,
                                                             EPTF_EXECUTE_IMMEDIATELY,
                                                             EPTT_BEST_EFFORT, true)
    }
  }
}

let function add(action, delay_ms = 0) {
  addDelayedAction(action, delay_ms)
}

let function test() {
  let curTime = get_time_msec()
  for (local i = 0; i < 100; ++i) {
    let rndDelay = rnd_int(0, 9)
    let idx = i
    add(@() log(format("[%d] %d run action with delay %d seconds", curTime, idx, rndDelay)), rndDelay * 1000)
  }
}

::g_delayed_actions <- {
  add
  runDelayedActions
  runInstantActions
  addDelayedAction
  test
}
