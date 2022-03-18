let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")

::WwAirfieldCooldownFormation <- class extends ::WwAirfieldFormation
{
  cooldownFinishedMillis = 0

  constructor(blk, airfield)
  {
    units = []
    update(blk, airfield)
  }

  function update(blk, airfield)
  {
    units = wwActionsWithUnitsList.loadUnitsFromBlk(blk.getBlockByName("units"))
    morale = airfield.createArmyMorale
    if ("cooldownFinishedMillis" in blk)
      cooldownFinishedMillis = blk.cooldownFinishedMillis
  }

  function clear()
  {
    base.clear()
    cooldownFinishedMillis = 0
  }

  function getCooldownTime()
  {
    return ::max(0, (cooldownFinishedMillis - ::ww_get_operation_time_millisec()))
  }

  function getCooldownText()
  {
    let cooldownTime = getCooldownTime()
    if (cooldownTime == 0)
      return ::loc("worldwar/state/ready")

    return time.secondsToString(time.millisecondsToSeconds(cooldownTime), false)
  }
}
