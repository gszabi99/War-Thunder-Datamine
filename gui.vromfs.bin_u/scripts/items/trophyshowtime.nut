//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

from "dagor.workcycle" import setTimeout, clearTimer
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.ITEMS_SHOP)
let { TIME_DAY_IN_SECONDS, TIME_WEEK_IN_SECONDS } = require("%scripts/time.nut")

local trophies = []

let onShowTimer = @() ::broadcastEvent("UpdateTrophiesVisibility")

let function resetShowTimer() {
  clearTimer(onShowTimer)

  let curTime = ::get_charserver_time_sec()
  let nextTime = trophies
    .map(@(v) curTime < v.beginDate ? v.beginDate
            : curTime < v.endDate   ? v.endDate
            : 0)
    .filter(@(v) v > 0)
    .reduce(@(acc, v) v < acc ? v : acc)

  if (nextTime == null)
    return

  setTimeout(nextTime - curTime + 2, onShowTimer)
}

let function onAlarmTimer() {
  ::ItemsManager.invalidateShopVisibleSeenIds()
  seenList.onListChanged()
  ::broadcastEvent("UpdateTrophyUnseenIcons")
}

let function resetAlarmTimer() {
  clearTimer(onAlarmTimer)

  let deltaTime = trophies
    .map(function(trophy) {
      let t = trophy.getRemainingLifetime()
      if (t < 0)
        return 0

      return t > TIME_WEEK_IN_SECONDS ? t - TIME_WEEK_IN_SECONDS
           : t > TIME_DAY_IN_SECONDS  ? t - TIME_DAY_IN_SECONDS
           : 0
    })
    .filter(@(v) v > 0)
    .reduce(@(acc, v) v < acc ? v : acc)

    if (deltaTime == null)
      return

    setTimeout(deltaTime + 2, onAlarmTimer)
}

let function clearTimers() {
  clearTimer(onShowTimer)
  clearTimer(onAlarmTimer)
}

let function resetTimers() {
  resetShowTimer()
  resetAlarmTimer()
}

let function updateTrophyList() {
  let typeMask = ::ItemsManager.checkItemsMaskFeatures(itemType.TROPHY)
  trophies = ::ItemsManager.getShopList(typeMask, @(i) i.beginDate != null)

  if (trophies.len() == 0) {
    clearTimers()
    return
  }

  resetTimers()
}

addListenersWithoutEnv({
  SignOut = @(_) clearTimers()
  ItemsShopUpdate = @(_) updateTrophyList()
  UpdateTrophiesVisibility = @(_) resetShowTimer()
  UpdateTrophyUnseenIcons = @(_) resetAlarmTimer()
})