//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

from "dagor.workcycle" import clearTimer, setTimeout
let { TIME_DAY_IN_SECONDS, buildDateStr } = require("%scripts/time.nut")
let timeBase = require("%appGlobals/timeLoc.nut")
let { addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shopPromoteUnits } = require("%scripts/shop/shopUnitsInfo.nut")

let promoteUnits = persist("promoteUnits", @() Watched({}))
let clearPromUnitListCache = @() promoteUnits({})

let function updatePromoteUnits() {
  let activPromUnits = {}

  clearTimer(updatePromoteUnits)
  activPromUnits.clear()

  if (shopPromoteUnits.value.len() == 0)
    return

  let currentTime = ::get_charserver_time_sec()
  local nextChangeTime = null

  foreach (promoteUnit in shopPromoteUnits.value) {
    let { unit, timeStart, timeEnd } = promoteUnit

    if (::isUnitBought(unit) || currentTime > timeEnd)
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

  if (!::u.isEqual(activPromUnits, promoteUnits.value))
    promoteUnits(activPromUnits)
}

let function isPromUnit(unit) {
  return promoteUnits.value?[unit.name].isActive ?? false
}

let function fillPromUnitInfo(holderObj, unit) {
  if (shopPromoteUnits.value?[unit.name] == null || !holderObj?.isValid())
    return false

  if (!isPromUnit(unit)) {
    ::showBtn("aircraft-remainingTimeBuyInfo", false, holderObj)
    return false
  }
  let timeEnd = promoteUnits.value[unit.name].timeEnd
  let t = timeEnd - ::get_charserver_time_sec()

  if (t <= 0) {
    ::showBtn("aircraft-remainingTimeBuyInfo", false, holderObj)
    return false
  }

  let locStr = t < TIME_DAY_IN_SECONDS
    ? loc("mainmenu/timeForBuyVehicle", { time = timeBase.secondsToString(t) })
    : loc("mainmenu/dataRemaningTime", { time = buildDateStr(timeEnd) })

  let remTimeBuyText = colorize("goodTextColor", locStr)
  let remTimeBuyObj = ::showBtn("aircraft-remainingTimeBuyInfo", true, holderObj)
  remTimeBuyObj.setValue(remTimeBuyText)
  return true
}

promoteUnits.subscribe(function(_) {
  ::broadcastEvent("PromoteUnitsChanged")
})

addListenersWithoutEnv({
  ProfileUpdated = @(_p) updatePromoteUnits()
  SignOut = @(_) clearPromUnitListCache()
}, CONFIG_VALIDATION)

return {
  fillPromUnitInfo
  promoteUnits
}