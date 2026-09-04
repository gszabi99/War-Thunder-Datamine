from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "gameplayBinding" import isInFlight
from "mission" import get_mission_time
from "%scripts/dagui_natives.nut" import periodic_task_unregister, periodic_task_register_ex
from "%scripts/dagui_library.nut" import *
from "%globalScripts/periodicTaskConsts.nut" import *

local refreshBoostersTask = -1
local boostersTaskUpdateFlightTime = -1

function removeRefreshBoostersTask() {
  if (refreshBoostersTask >= 0)
    periodic_task_unregister(refreshBoostersTask)
  refreshBoostersTask = -1
}

function onBoosterExpiredInFlight(_dt = 0) {
  removeRefreshBoostersTask()
  if (isInFlight())
    broadcastEvent("RequestUpdateGamercards")
}


function registerBoosterUpdateTimer(boostersList) {
  if (!isInFlight())
    return

  let curFlightTime = get_mission_time()
  local nextExpireTime = -1
  foreach (booster in boostersList) {
    let expireTime = booster.getExpireFlightTime()
    if (expireTime <= curFlightTime)
      continue
    if (nextExpireTime < 0 || expireTime < nextExpireTime)
      nextExpireTime = expireTime
  }

  if (nextExpireTime < 0)
    return

  let nextUpdateTime = nextExpireTime.tointeger() + 1
  if (refreshBoostersTask >= 0 && nextUpdateTime >= boostersTaskUpdateFlightTime)
    return

  removeRefreshBoostersTask()

  boostersTaskUpdateFlightTime = nextUpdateTime
  refreshBoostersTask = periodic_task_register_ex({},
    onBoosterExpiredInFlight,
    boostersTaskUpdateFlightTime - curFlightTime,
    EPTF_IN_FLIGHT,
    EPTT_BEST_EFFORT,
    false 
  )
}

addListenersWithoutEnv({
  function LoadingStateChange(_) {
    if (!isInFlight())
      removeRefreshBoostersTask()
  }
})

return {
  registerBoosterUpdateTimer
}