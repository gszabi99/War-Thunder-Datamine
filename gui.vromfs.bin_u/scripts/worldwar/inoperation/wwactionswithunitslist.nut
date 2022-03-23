let wwOperationUnitsGroups = require("%scripts/worldWar/inOperation/wwOperationUnitsGroups.nut")

let function loadUnitsFromBlk(blk, aiUnitsBlk = null)
{
  if (!blk)
    return []

  let units = []
  for (local i = 0; i < blk.blockCount(); i++)
  {
    let unitBlk = blk.getBlock(i)
    let unit    = ::WwUnit(unitBlk)

    if (unit.isValid())
      units.append(unit)

    if (aiUnitsBlk)
    {
      let aiUnitData = ::getTblValue(unitBlk.getBlockName(), aiUnitsBlk)
      if (aiUnitData)
      {
        let aiUnit = ::WwUnit(unitBlk)
        aiUnit.setCount(getTblValue("count", aiUnitData, -1))
        aiUnit.setForceControlledByAI(true)
        units.append(aiUnit)
      }
    }
  }
  return units
}

let function loadUnitsFromNameCountTbl(tbl)
{
  if (::u.isEmpty(tbl))
    return []

  let units = []
  let loadingBlk = ::DataBlock()
  foreach(name, count in tbl)
  {
    loadingBlk["name"] = name
    loadingBlk["count"] = count

    let unit = ::WwUnit(loadingBlk)
    if (unit.isValid())
      units.append(unit)
  }

  return units
}

let function loadWWUnitsFromUnitsArray(unitsArray)
{
  if (::u.isEmpty(unitsArray))
    return []

  let units = []
  let loadingBlk = ::DataBlock()
  foreach(unit in unitsArray)
  {
    loadingBlk["name"] = unit.name
    loadingBlk["count"] = 1

    let wwUnit = ::WwUnit(loadingBlk)
    if (wwUnit.isValid())
      units.append(wwUnit)
  }

  return units
}

let function getFakeUnitsArray(blk)
{
  if (!blk?.fakeInfantry)
    return []

  let resArray = []
  let loadingBlk = ::DataBlock()
  loadingBlk.changeBlockName("fake_infantry")
  loadingBlk.count <- blk.fakeInfantry
  let fakeUnit = ::WwUnit(loadingBlk)
  if (fakeUnit.isValid())
    resArray.append(fakeUnit)

  return resArray
}

let function unitsCount(units = [])
{
  local res = 0
  foreach (wwUnit in units)
    res += wwUnit.count
  return res
}

local function getUnitsListViewParams(wwUnits, params = {}, needSort = true)
{
  if (needSort)
    wwUnits.sort(::g_world_war.sortUnitsBySortCodeAndCount)
  wwUnits = wwUnits.map(@(wwUnit) wwUnit.getShortStringView(params))
  return wwOperationUnitsGroups.overrideUnitsViewParamsByGroups(wwUnits)
}

let function getMaxFlyTime(unit) {
  if (!unit?.isAir() && !unit?.isHelicopter())
    return 0

  let maxFlyTime = unit.getUnitWpCostBlk().maxFlightTimeMinutes ??
    ::g_world_war.getWWConfigurableValue("defaultMaxFlightTimeMinutes", 0)
  return (maxFlyTime * 60 / ::ww_get_speedup_factor()).tointeger()
}

return {
  loadUnitsFromBlk
  loadUnitsFromNameCountTbl
  loadWWUnitsFromUnitsArray
  getFakeUnitsArray
  unitsCount
  getUnitsListViewParams = ::kwarg(getUnitsListViewParams)
  getMaxFlyTime
}