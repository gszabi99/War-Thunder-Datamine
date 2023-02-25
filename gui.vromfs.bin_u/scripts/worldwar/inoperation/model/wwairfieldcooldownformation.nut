//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")

::WwAirfieldCooldownFormation <- class extends ::WwAirfieldFormation {
  cooldownFinishedMillis = 0

  constructor(blk, airfield) {
    this.units = []
    this.update(blk, airfield)
  }

  function update(blk, airfield) {
    this.units = wwActionsWithUnitsList.loadUnitsFromBlk(blk.getBlockByName("units"))
    this.morale = airfield.createArmyMorale
    if ("cooldownFinishedMillis" in blk)
      this.cooldownFinishedMillis = blk.cooldownFinishedMillis
  }

  function clear() {
    base.clear()
    this.cooldownFinishedMillis = 0
  }

  function getCooldownTime() {
    return max(0, (this.cooldownFinishedMillis - ::ww_get_operation_time_millisec()))
  }

  function getCooldownText() {
    let cooldownTime = this.getCooldownTime()
    if (cooldownTime == 0)
      return loc("worldwar/state/ready")

    return time.secondsToString(time.millisecondsToSeconds(cooldownTime), false)
  }
}
