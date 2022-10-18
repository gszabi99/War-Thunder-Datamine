from "dagor.workcycle" import clearTimer, setTimeout
let { TIME_DAY_IN_SECONDS, buildDateStr } = require("%scripts/time.nut")
let timeBase = require("%scripts/timeLoc.nut")
let { addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { shopPromoteUnits } = require("%scripts/shop/shopUnitsInfo.nut")

let promoteUnits = persist("promoteUnits", @() ::Watched({}))
let clearPromUnitListCache = @() promoteUnits({})

let function updatePromoteUnits() {
  let activPromUnits = {}

  clearTimer(updatePromoteUnits)
  activPromUnits.clear()

  if (shopPromoteUnits.len() == 0)
    return

  let currentTime = ::get_charserver_time_sec()
  local nextChangeTime = null

  foreach(promoteUnit in shopPromoteUnits){
    let {unit, timeStart, timeEnd} = promoteUnit

    if(::isUnitBought(unit) || currentTime > timeEnd)
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

  if(!::u.isEqual(activPromUnits, promoteUnits.value))
    promoteUnits(activPromUnits)
}

let function isPromUnit(unit) {
  return promoteUnits.value?[unit.name].isActive ?? false
}

let function fillPromUnitInfo(holderObj, unit){
  if(!isPromUnit(unit))
    return
  SecondsUpdater(holderObj, function(obj, params){
    if (!holderObj?.isValid())
      return

    let isProm = isPromUnit(unit)
    let remTimeBuyObj = ::showBtn("aircraft-remainingTimeBuyInfo", isProm, holderObj)
    if(!isProm)
      return

    let t = promoteUnits.value[unit.name].timeEnd
    let loc = t < TIME_DAY_IN_SECONDS
      ? ::loc("mainmenu/timeForBuyVehicle", { time = timeBase.hoursToString(t) })
      : ::loc("mainmenu/dataRemaningTime", { time = buildDateStr(t) })
    let remTimeBuyText = ::colorize("goodTextColor", loc)
    remTimeBuyObj.setValue(remTimeBuyText)
  })
}

promoteUnits.subscribe(function(_) {
  ::broadcastEvent("PromoteUnitsChanged")
})

addListenersWithoutEnv({
  ProfileUpdated = @(p) updatePromoteUnits()
  SignOut = @(_) clearPromUnitListCache()
}, CONFIG_VALIDATION)

return {
  fillPromUnitInfo
  promoteUnits
}