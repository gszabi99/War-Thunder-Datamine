from "dagor.workcycle" import setTimeout, clearTimer
let { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local trophies = []

let notify = @() ::broadcastEvent("UpdateTrophiesVisibility")

let function resetTimer() {
  clearTimer(notify)

  let curTime = ::get_charserver_time_sec()
  let nextTime = trophies
    .map(@(v) curTime < v.beginDate ? v.beginDate
            : curTime < v.endDate   ? v.endDate
            : 0)
    .filter(@(v) v > 0)
    .reduce(@(acc, v) v < acc ? v : acc)

  if (nextTime == null)
    return

  setTimeout(nextTime - curTime + 2, notify)
}

let function updateTrophyList() {
  let typeMask = ::ItemsManager.checkItemsMaskFeatures(itemType.TROPHY)
  trophies = ::ItemsManager.getShopList(typeMask, @(i) i.beginDate != null)

  if (trophies.len() == 0) {
    clearTimer(notify)
    return
  }

  resetTimer()
}

addListenersWithoutEnv({
  SignOut = @(_) clearTimer(notify)
  ItemsShopUpdate = @(_) updateTrophyList()
  UpdateTrophiesVisibility = @(_) resetTimer()
})