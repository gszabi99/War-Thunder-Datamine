let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")

::WwAirfieldFormation <- class extends ::WwFormation
{
  constructor(blk, airfield)
  {
    units = []
    update(blk, airfield)
  }

  function update(blk, airfield)
  {
    mapObjectName = airfield.airfieldType.objName
    unitType = airfield.airfieldType.unitType.code
    owner = ::WwArmyOwner(blk.getBlockByName("owner"))
    units = wwActionsWithUnitsList.loadUnitsFromBlk(blk.getBlockByName("units"))
    morale = airfield.createArmyMorale
  }

  function clear()
  {
    base.clear()
  }

  function isValid()
  {
    return owner && owner.isValid();
  }

  function getGroupUnitType()
  {
    return unitType
  }
}
