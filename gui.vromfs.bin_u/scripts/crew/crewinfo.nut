from "%scripts/dagui_library.nut" import *
let { get_charserver_time_sec } = require("chard")
let { get_warpoints_blk } = require("blkGetters")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")

local isCrewUnlockErrorShowed = false

function getCrewUnlockTime(crew) {
  let lockTime = crew?.lockedTillSec ?? 0
  if (lockTime <= 0)
    return 0

  local timeLeft = lockTime - get_charserver_time_sec()
  if (timeLeft <= 0)
    return 0

  let { lockTimeMaxLimitSec = timeLeft } = get_warpoints_blk()
  if (timeLeft > lockTimeMaxLimitSec) {
    log($"crew.lockedTillSec {lockTime}")
    log($"get_charserver_time_sec() {get_charserver_time_sec()}")
    if (!isCrewUnlockErrorShowed)
      debugTableData(::g_crews_list.getCrewsList())
    assert(isCrewUnlockErrorShowed, "Too big locked crew wait time")
    isCrewUnlockErrorShowed = true
    timeLeft = lockTimeMaxLimitSec
  }

  return timeLeft
}

let isCrewLockedByPrevBattle = @(crew) isInMenu() && ((crew?.lockedTillSec ?? 0) > 0)

function getCrewByAir(air) {
  foreach (country in ::g_crews_list.getCrewsList())
    if (country.country == air.shopCountry)
      foreach (crew in country.crews)
        if (("aircraft" in crew) && crew.aircraft == air.name)
          return crew
  return null
}

return {
  getCrewUnlockTime
  isCrewLockedByPrevBattle
  getCrewByAir
}
