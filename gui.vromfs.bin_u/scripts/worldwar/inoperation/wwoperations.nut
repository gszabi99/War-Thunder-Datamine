from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { get_time_msec } = require("dagor.time")

::g_operations <- {
  operationStatusById = {}

  UPDATE_REFRESH_DELAY = 1000

  lastUpdateTime = 0
  isUpdateRequired = false
}

/******************* Public ********************/

::g_operations.forcedFullUpdate <- function forcedFullUpdate()
{
  this.isUpdateRequired = true
  this.fullUpdate()
}

::g_operations.fullUpdate <- function fullUpdate()
{
  if (!this.isUpdateRequired)
    return

  let curTime = get_time_msec()
  if (curTime - this.lastUpdateTime < UPDATE_REFRESH_DELAY)
    return

  this.getCurrentOperation().update()

  this.lastUpdateTime = curTime
  this.isUpdateRequired = false
}

::g_operations.getArmiesByStatus <- function getArmiesByStatus(status)
{
  return this.getCurrentOperation().armies.getArmiesByStatus(status)
}

::g_operations.getArmiesCache <- function getArmiesCache()
{
  return this.getCurrentOperation().armies.armiesByStatusCache
}

::g_operations.getAirArmiesNumberByGroupIdx <- function getAirArmiesNumberByGroupIdx(groupIdx,
  overrideUnitType)
{
  local armyCount = 0
  foreach (wwArmyByStatus in getArmiesCache())
    foreach (wwArmyByGroup in wwArmyByStatus)
      foreach (wwArmy in wwArmyByGroup)
        if (wwArmy.getArmyGroupIdx() == groupIdx
          && !(wwArmy.getArmyFlags() & EAF_NO_AIR_LIMIT_ACCOUNTING)
            && ::g_ww_unit_type.isAir(wwArmy.getUnitType())
              && wwArmy.getOverrideUnitType() == overrideUnitType)
          armyCount++

  return armyCount
}

::g_operations.getAllOperationUnitsBySide <- function getAllOperationUnitsBySide(side)
{
  let operationUnits = {}
  let blk = ::DataBlock()
  ::ww_get_sides_info(blk)

  let sidesBlk = blk?["sides"]
  if (sidesBlk == null)
    return operationUnits

  let sideBlk = sidesBlk?[side.tostring()]
  if (sideBlk == null)
    return operationUnits

  foreach (unitName in sideBlk.unitsEverSeen % "item")
    if (::getAircraftByName(unitName))
      operationUnits[unitName] <- 0

  return operationUnits
}

/***************** Private ********************/

::g_operations.getCurrentOperation <- function getCurrentOperation()
{
  let operationId = ::ww_get_operation_id()
  if (!(operationId in this.operationStatusById))
    this.operationStatusById[operationId] <- ::WwOperationModel()

  return this.operationStatusById[operationId]
}

/************* onEvent Handlers ***************/

::g_operations.onEventWWFirstLoadOperation <- function onEventWWFirstLoadOperation(_params)
{
  this.isUpdateRequired = true
}

::g_operations.onEventWWLoadOperation <- function onEventWWLoadOperation(_params)
{
  forcedFullUpdate()
}

::g_operations.onEventWWArmyPathTrackerStatus <- function onEventWWArmyPathTrackerStatus(params)
{
  let armyName = getTblValue("army", params)
  getCurrentOperation().armies.updateArmyStatus(armyName)
}

::subscribe_handler(::g_operations, ::g_listener_priority.DEFAULT_HANDLER)