from "%scripts/dagui_library.nut" import *

from "dagor.workcycle" import clearTimer, setTimeout
let u = require("%sqStdLibs/helpers/u.nut")
let { TIME_DAY_IN_SECONDS, buildDateStr } = require("%scripts/time.nut")
let { hoursToString } = require("%appGlobals/timeLoc.nut")
let { broadcastEvent, addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shopPromoteUnits } = require("%scripts/shop/shopUnitsInfo.nut")
let { get_charserver_time_sec } = require("chard")
let { isUnitBought } = require("%scripts/unit/unitShopInfo.nut")

let promoteUnits = mkWatched(persist, "promoteUnits", {})
let clearPromUnitListCache = @() promoteUnits({})

function updatePromoteUnits() {
  let activPromUnits = {}

  clearTimer(updatePromoteUnits)
  activPromUnits.clear()

  if (shopPromoteUnits.value.len() == 0)
    return

  let currentTime = get_charserver_time_sec()
  local nextChangeTime = null

  foreach (promoteUnit in shopPromoteUnits.value) {
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

  if (!u.isEqual(activPromUnits, promoteUnits.value))
    promoteUnits(activPromUnits)
}

function isPromUnit(unitName) {
  return promoteUnits.value?[unitName].isActive ?? false
}

function fillPromUnitInfo(holderObj, unit, needShowExpiredMessage) {
  if (!holderObj?.isValid())
    return false

  if (shopPromoteUnits.value?[unit.name] == null || (!isPromUnit(unit.name) && !needShowExpiredMessage)) {
    showObjById("aircraft-remainingTimeBuyInfo", false, holderObj)
    return false
  }

  let timeEnd = shopPromoteUnits.value[unit.name].timeEnd
  let t = timeEnd - get_charserver_time_sec()

  let color = (t > 0) ? "goodTextColor" : "redMenuButtonColor"

  let locStr = (t <= 0)
    ? loc("mainmenu/dataExpiredTime", { time = buildDateStr(timeEnd) })
    : t < TIME_DAY_IN_SECONDS
      ? loc("mainmenu/timeForBuyVehicle", { time = hoursToString(t / 3600.0, true, true) })
      : loc("mainmenu/dataRemaningTime", { time = buildDateStr(timeEnd) })

  let remTimeBuyText = colorize(color, locStr)
  let remTimeBuyObj = showObjById("aircraft-remainingTimeBuyInfo", true, holderObj)
  remTimeBuyObj.setValue(remTimeBuyText)
  return true
}

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