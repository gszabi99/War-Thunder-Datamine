from "%scripts/dagui_library.nut" import *

let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { WwAirfieldFormation } = require("wwAirfieldFormation.nut")
let { wwGetOperationTimeMillisec } = require("worldwar")

let WwAirfieldCooldownFormation = class (WwAirfieldFormation) {
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
    return max(0, (this.cooldownFinishedMillis - wwGetOperationTimeMillisec()))
  }

  function getCooldownText() {
    let cooldownTime = this.getCooldownTime()
    if (cooldownTime == 0)
      return loc("worldwar/state/ready")

    return time.secondsToString(time.millisecondsToSeconds(cooldownTime), false)
  }
}

return {WwAirfieldCooldownFormation}