local wwActionsWithUnitsList = require("scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")

class ::WwAirfieldFormation extends ::WwFormation
{
  unitType = ::g_ww_unit_type.AIR.code
  mapObjectName = "airfield"

  constructor(blk, airfield)
  {
    units = []
    update(blk, airfield)
  }

  function update(blk, airfield)
  {
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
