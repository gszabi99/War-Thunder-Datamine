from "%scripts/dagui_library.nut" import *

let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { WwFormation } = require("wwArmy.nut")
let { WwArmyOwner } = require("%scripts/worldWar/inOperation/model/wwArmyOwner.nut")

let WwAirfieldFormation = class (WwFormation) {
  constructor(blk, airfield) {
    this.units = []
    this.update(blk, airfield)
  }

  function update(blk, airfield) {
    this.mapObjectName = airfield.airfieldType.objName
    this.unitType = airfield.airfieldType.unitType.code
    this.owner = WwArmyOwner(blk.getBlockByName("owner"))
    this.units = wwActionsWithUnitsList.loadUnitsFromBlk(blk.getBlockByName("units"))
    this.morale = airfield.createArmyMorale
  }

  function clear() {
    base.clear()
  }

  function isValid() {
    return this.owner && this.owner.isValid();
  }

  function getGroupUnitType() {
    return this.unitType
  }
}

return {WwAirfieldFormation}