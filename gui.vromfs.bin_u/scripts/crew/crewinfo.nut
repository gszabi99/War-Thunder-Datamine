local isCrewUnlockErrorShowed = false

local function getCrewUnlockTime(crew) {
  local lockTime = crew?.lockedTillSec ?? 0
  if (lockTime <= 0)
    return 0

  local timeLeft = lockTime - ::get_charserver_time_sec()
  if (timeLeft <= 0)
    return 0

  local { lockTimeMaxLimitSec = timeLeft } = ::get_warpoints_blk()
  if (timeLeft > lockTimeMaxLimitSec) {
    timeLeft = lockTimeMaxLimitSec
    ::dagor.debug("crew.lockedTillSec " + lockTime)
    ::dagor.debug("::get_charserver_time_sec() " + ::get_charserver_time_sec())
    if (!isCrewUnlockErrorShowed)
      ::debugTableData(::g_crews_list.get())
    ::dagor.assertf(isCrewUnlockErrorShowed, "Too big locked crew wait time")
    isCrewUnlockErrorShowed = true
  }

  return timeLeft
}

local getCrewUnlockTimeByUnit = @(unit) unit == null ? 0
 : getCrewUnlockTime(::getCrewByAir(unit))

return {
  getCrewUnlockTime
  getCrewUnlockTimeByUnit
}
