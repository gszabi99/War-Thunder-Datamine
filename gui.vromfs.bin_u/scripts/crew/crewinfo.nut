from "%scripts/dagui_library.nut" import *
let { get_charserver_time_sec } = require("chard")
let { get_warpoints_blk } = require("blkGetters")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")

local isCrewUnlockErrorShowed = false

let function getCrewUnlockTime(crew) {
  let lockTime = crew?.lockedTillSec ?? 0
  if (lockTime <= 0)
    return 0

  local timeLeft = lockTime - get_charserver_time_sec()
  if (timeLeft <= 0)
    return 0

  let { lockTimeMaxLimitSec = timeLeft } = get_warpoints_blk()
  if (timeLeft > lockTimeMaxLimitSec) {
    timeLeft = lockTimeMaxLimitSec
    log($"crew.lockedTillSec {lockTime}")
    log($"get_charserver_time_sec() {get_charserver_time_sec()}")
    if (!isCrewUnlockErrorShowed)
      debugTableData(::g_crews_list.get())
    assert(isCrewUnlockErrorShowed, "Too big locked crew wait time")
    isCrewUnlockErrorShowed = true
  }

  return timeLeft
}

let isCrewLockedByPrevBattle = @(crew) isInMenu() && ((crew?.lockedTillSec ?? 0) > 0)

return {
  getCrewUnlockTime
  isCrewLockedByPrevBattle
}
