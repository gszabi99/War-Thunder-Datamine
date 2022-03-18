let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")

::WwCustomFormation <- class extends ::WwFormation
{
  constructor(blk, airfield)
  {
    units = []
    update(blk, airfield)
  }

  function update(blk, airfield)
  {
    owner = ::WwArmyOwner(blk.getBlockByName("owner"))
    morale = airfield.createArmyMorale
  }

  function clear()
  {
    base.clear()
  }

  function isValid()
  {
    return false
  }

  function getArmyGroup()
  {
    return null
  }

  function addUnits(blk)
  {
    let additionalUnits = wwActionsWithUnitsList.loadUnitsFromBlk(blk.getBlockByName("units"))
    units.extend(additionalUnits)
    units = units.reduce(function (memo, unit) {
      foreach (unitInMemo in memo)
        if (unitInMemo.name == unit.name)
        {
          unitInMemo.count += unit.count
          return memo
        }
      memo.append(unit)
      return memo
    }, [])
  }
}
