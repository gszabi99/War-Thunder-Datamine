let time = require("%scripts/time.nut")
::WwArtilleryAmmo <- class
{
  hasArtilleryStrike = false
  strikesDone = null
  ammoCount = 0
  maxAmmoCount = 0
  maxStrikesPerAttack = 0
  nextAmmoRefillMillisec = 0
  nextStrikeTimeMillis = 0
  cooldownAfterMoveSec = 0
  strikeIntervalSec = 0

  function update(armyName, blk = null)
  {
    if (!blk)
      return

    ammoCount = blk.ammo
    nextAmmoRefillMillisec = blk.nextAmmoRefillMillisec
    updateStrike(armyName)
  }

  function updateStrike(armyName)
  {
    hasArtilleryStrike = false
    nextStrikeTimeMillis = 0
    strikesDone = null

    let strikesBlk = ::DataBlock()
    ::ww_get_artillery_strikes(strikesBlk)

    let strikeBlk = strikesBlk?.artilleryStrikes?[armyName]
    if (!strikeBlk)
      return

    hasArtilleryStrike = true
    nextStrikeTimeMillis = ::getTblValue("nextStrikeTimeMillis", strikeBlk, 0)
    strikesDone = ::getTblValue("strikesDone", strikeBlk, 0)
  }

  function getAmmoCount()
  {
    return ammoCount
  }

  function getMaxAmmoCount()
  {
    return maxAmmoCount
  }

  function getNextAmmoRefillTime()
  {
    let millisec = nextAmmoRefillMillisec - ::ww_get_operation_time_millisec()
    return time.millisecondsToSeconds(millisec).tointeger()
  }

  function getMaxStrikesPerAttack()
  {
    return ::min(maxStrikesPerAttack, maxAmmoCount)
  }

  function getCooldownAfterMoveMillisec()
  {
    return (cooldownAfterMoveSec * 1000 / ::ww_get_speedup_factor()).tointeger()
  }

  function getStrikeIntervalMillisec()
  {
    return (strikeIntervalSec * 1000 / ::ww_get_speedup_factor()).tointeger()
  }

  function getTimeToNextStrike()
  {
    if (!hasStrike())
      return 0

    let millisec = nextStrikeTimeMillis - ::ww_get_operation_time_millisec()
    return ::max(::ceil(time.millisecondsToSeconds(millisec)).tointeger(), 1)
  }

  function getTimeToCompleteStrikes()
  {
    if (!hasStrike())
      return 0

    local millisec = nextStrikeTimeMillis
    millisec += getUnusedStrikesNumber() * getStrikeIntervalMillisec()
    millisec -= ::ww_get_operation_time_millisec()

    return ::max(::ceil(time.millisecondsToSeconds(millisec)).tointeger(), 1)
  }

  function getUnusedStrikesNumber()
  {
    return hasStrike() ? getMaxStrikesPerAttack() - strikesDone - 1 : 0
  }

  function hasStrike()
  {
    return hasArtilleryStrike
  }

  function isStrikePreparing()
  {
    return hasStrike() ? strikesDone == 0 : false
  }

  function setArtilleryParams(params)
  {
    if (!params)
      return

    maxAmmoCount = ::getTblValue("maxAmmo", params, 0)
    maxStrikesPerAttack = ::getTblValue("maxStrikesPerAttack", params, 0)
    cooldownAfterMoveSec = ::getTblValue("cooldownAfterMoveSec", params, 0)
    strikeIntervalSec = ::getTblValue("strikeIntervalSec", params, 0)
  }
}
