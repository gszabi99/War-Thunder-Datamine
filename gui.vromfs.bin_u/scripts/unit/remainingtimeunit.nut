from "%scripts/dagui_library.nut" import *
from "dagor.workcycle" import clearTimer, setTimeout, deferOnce
let u = require("%sqStdLibs/helpers/u.nut")
let { TIME_DAY_IN_SECONDS, buildDateStr } = require("%scripts/time.nut")
let { hoursToString } = require("%appGlobals/timeLoc.nut")
let { broadcastEvent, addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shopPromoteUnits } = require("%scripts/shop/shopUnitsInfo.nut")
let { get_charserver_time_sec } = require("chard")
let { isUnitBought } = require("%scripts/unit/unitShopInfo.nut")

let promoteUnits = mkWatched(persist, "promoteUnits", {})
let clearPromUnitListCache = @() promoteUnits.set({})

function updatePromoteUnits() {
  let activPromUnits = {}

  clearTimer(updatePromoteUnits)
  activPromUnits.clear()

  if (shopPromoteUnits.get().len() == 0)
    return

  let currentTime = get_charserver_time_sec()
  local nextChangeTime = null

  foreach (promoteUnit in shopPromoteUnits.get()) {
    let { unit, timeStart, timeEnd } = promoteUnit

    if (isUnitBought(unit) || currentTime > timeEnd)
      continue

    let nextTime = timeStart > currentTime
      ? timeStart
      : timeEnd

    nextChangeTime = min(nextChangeTime ?? nextTime, nextTime)
    activPromUnits[unit.name] <- promoteUnit.__merge({
      isActive = timeStart <= currentTime && timeEnd > currentTime
    })
  }
  if (nextChangeTime != null && nextChangeTime > currentTime)
    setTimeout(nextChangeTime - currentTime, updatePromoteUnits)

  if (!u.isEqual(activPromUnits, promoteUnits.get()))
    promoteUnits.set(activPromUnits)
}

function isPromUnit(unitName) {
  return promoteUnits.get()?[unitName].isActive ?? false
}

function fillPromUnitInfo(holderObj, unit, needShowExpiredMessage) {
  if (!holderObj?.isValid())
    return false

  if (shopPromoteUnits.get()?[unit.name] == null || (!isPromUnit(unit.name) && !needShowExpiredMessage)) {
    showObjById("aircraft-remainingTimeBuyInfo", false, holderObj)
    return false
  }

  let timeEnd = shopPromoteUnits.get()[unit.name].timeEnd
  let t = timeEnd - get_charserver_time_sec()

  let color = (t > 0) ? "goodTextColor" : "redMenuButtonColor"

  let tillDateLocKey = unit?.endResearchDate ? "mainmenu/vehicleResearchTillDate"
    : "mainmenu/dataRemaningTime"
  let expireTimeLocKey = unit?.endResearchDate ? "mainmenu/vehicleExpireTimeForResearch"
    : "mainmenu/timeForBuyVehicle"

  let locStr = (t <= 0)
    ? loc("mainmenu/dataExpiredTime", { time = buildDateStr(timeEnd) })
    : t < TIME_DAY_IN_SECONDS
      ? loc(expireTimeLocKey, { time = hoursToString(t / 3600.0, true, true) })
      : loc(tillDateLocKey, { time = buildDateStr(timeEnd) })

  let remTimeBuyText = colorize(color, locStr)
  let remTimeBuyObj = showObjById("aircraft-remainingTimeBuyInfo", true, holderObj)
  remTimeBuyObj.setValue(remTimeBuyText)
  return true
}

shopPromoteUnits.subscribe(@(_) deferOnce(updatePromoteUnits))

promoteUnits.subscribe(function(_) {
  broadcastEvent("PromoteUnitsChanged")
})

addListenersWithoutEnv({
  ProfileUpdated = @(_p) updatePromoteUnits()
  SignOut = @(_) clearPromUnitListCache()
}, CONFIG_VALIDATION)

return {
  fillPromUnitInfo
  promoteUnits
  isPromUnit
}