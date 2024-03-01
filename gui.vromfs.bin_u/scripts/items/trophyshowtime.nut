from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType
from "%scripts/mainConsts.nut" import SEEN
from "dagor.workcycle" import setTimeout, clearTimer

let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.ITEMS_SHOP)
let { TIME_DAY_IN_SECONDS, TIME_WEEK_IN_SECONDS } = require("%scripts/time.nut")
let { get_charserver_time_sec } = require("chard")
let { checkItemsMaskFeatures, invalidateShopVisibleSeenIds, getShopList
} = require("%scripts/items/itemsManager.nut")

local trophies = []

let onShowTimer = @() broadcastEvent("UpdateTrophiesVisibility")

function resetShowTimer() {
  clearTimer(onShowTimer)

  let curTime = get_charserver_time_sec()
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

function onAlarmTimer() {
  invalidateShopVisibleSeenIds()
  seenList.onListChanged()
  broadcastEvent("UpdateTrophyUnseenIcons")
}

function resetAlarmTimer() {
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

function clearTimers() {
  clearTimer(onShowTimer)
  clearTimer(onAlarmTimer)
}

function resetTimers() {
  resetShowTimer()
  resetAlarmTimer()
}

function updateTrophyList() {
  let typeMask = checkItemsMaskFeatures(itemType.TROPHY)
  trophies = getShopList(typeMask, @(i) i.beginDate != null)

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