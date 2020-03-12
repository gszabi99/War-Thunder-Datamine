local wwOperationUnitsGroups = require("scripts/worldWar/inOperation/wwOperationUnitsGroups.nut")

local function loadUnitsFromBlk(blk, aiUnitsBlk = null)
{
  if (!blk)
    return []

  local units = []
  for (local i = 0; i < blk.blockCount(); i++)
  {
    local unitBlk = blk.getBlock(i)
    local unit    = ::WwUnit(unitBlk)

    if (unit.isValid())
      units.append(unit)

    if (aiUnitsBlk)
    {
      local aiUnitData = ::getTblValue(unitBlk.getBlockName(), aiUnitsBlk)
      if (aiUnitData)
      {
        local aiUnit = ::WwUnit(unitBlk)
        aiUnit.setCount(getTblValue("count", aiUnitData, -1))
        aiUnit.setForceControlledByAI(true)
        units.append(aiUnit)
      }
    }
  }
  return units
}

local function loadUnitsFromNameCountTbl(tbl)
{
  if (::u.isEmpty(tbl))
    return []

  local units = []
  local loadingBlk = ::DataBlock()
  foreach(name, count in tbl)
  {
    loadingBlk["name"] = name
    loadingBlk["count"] = count

    local unit = ::WwUnit(loadingBlk)
    if (unit.isValid())
      units.append(unit)
  }

  return units
}

local function loadWWUnitsFromUnitsArray(unitsArray)
{
  if (::u.isEmpty(unitsArray))
    return []

  local units = []
  local loadingBlk = ::DataBlock()
  foreach(unit in unitsArray)
  {
    loadingBlk["name"] = unit.name
    loadingBlk["count"] = 1

    local wwUnit = ::WwUnit(loadingBlk)
    if (wwUnit.isValid())
      units.append(wwUnit)
  }

  return units
}

local function getFakeUnitsArray(blk)
{
  if (!blk?.fakeInfantry)
    return []

  local resArray = []
  local loadingBlk = ::DataBlock()
  loadingBlk.changeBlockName("fake_infantry")
  loadingBlk.count <- blk.fakeInfantry
  local fakeUnit = ::WwUnit(loadingBlk)
  if (fakeUnit.isValid())
    resArray.append(fakeUnit)

  return resArray
}

local function unitsCount(units = [])
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

local function getUnitMarkUp(name, unit, group, overrideParams = {}) {
  local params = {
    status = "owned"
    inactive = true
    isLocalState = false
    needMultiLineName = true
    tooltipParams = { showLocalState = false }
    tooltipId = ::g_tooltip_type.UNIT_GROUP.getTooltipId(group)
  }.__update(overrideParams)

  if (group != null)
    unit = {
      name = name
      nameLoc = overrideParams?.nameLoc ?? ""
      image = ::image_for_air(unit)
      isFakeUnit = true
    }

  return ::build_aircraft_item(name, unit, params)
}

local function getMaxFlyTime(unit) {
  if (!unit?.isAir())
    return 0

  local maxFlyTime = unit.getUnitWpCostBlk().maxFlightTimeMinutes ??
    ::g_world_war.getWWConfigurableValue("defaultMaxFlightTimeMinutes", 0)
  return (maxFlyTime * 60 / ::ww_get_speedup_factor()).tointeger()
}

return {
  loadUnitsFromBlk = loadUnitsFromBlk
  loadUnitsFromNameCountTbl = loadUnitsFromNameCountTbl
  loadWWUnitsFromUnitsArray = loadWWUnitsFromUnitsArray
  getFakeUnitsArray = getFakeUnitsArray
  unitsCount = unitsCount
  getUnitsListViewParams = ::kwarg(getUnitsListViewParams)
  getUnitMarkUp = getUnitMarkUp
  getMaxFlyTime = getMaxFlyTime
}