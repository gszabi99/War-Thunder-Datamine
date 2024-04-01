from "%scripts/dagui_library.nut" import *
let { registerMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let RuleBase = require("%scripts/misCustomRules/ruleBase.nut")
let { initAdditionalUnits, isUnitSelected, isEventUnit, isUnitUsed } = require("%scripts/respawn/additionalUnits.nut")


let AdditionalUnits = class (RuleBase) {

  constructor() {
    base.constructor()
    initAdditionalUnits(this.getCustomRulesBlk().additionalUnits.getBlock(0))
  }

  isUnitForcedHiden = @(unitName) isEventUnit(unitName) && !isUnitSelected(unitName)

  hasCustomUnitRespawns = @() false

  isRespawnAvailable = @(unit) unit != null && !isUnitUsed(unit.name)

  function getUnitLeftRespawns(unit, teamDataBlk = null) {
    if(!isEventUnit(unit?.name))
      return base.getUnitLeftRespawns(unit, teamDataBlk)

    return isUnitUsed(unit.name) ? 0 : -1
  }
}

registerMissionRules("AdditionalUnits", AdditionalUnits)

return AdditionalUnits
