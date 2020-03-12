::g_operations <- {
  operationStatusById = {}

  UPDATE_REFRESH_DELAY = 1000

  lastUpdateTime = 0
  isUpdateRequired = false
}

/******************* Public ********************/

g_operations.forcedFullUpdate <- function forcedFullUpdate()
{
  isUpdateRequired = true
  fullUpdate()
}

g_operations.fullUpdate <- function fullUpdate()
{
  if (!isUpdateRequired)
    return

  local curTime = ::dagor.getCurTime()
  if (curTime - lastUpdateTime < UPDATE_REFRESH_DELAY)
    return

  getCurrentOperation().update()

  lastUpdateTime = curTime
  isUpdateRequired = false
}

g_operations.getArmiesByStatus <- function getArmiesByStatus(status)
{
  return getCurrentOperation().armies.getArmiesByStatus(status)
}

g_operations.getArmiesCache <- function getArmiesCache()
{
  return getCurrentOperation().armies.armiesByStatusCache
}

g_operations.getAirArmiesNumberByGroupIdx <- function getAirArmiesNumberByGroupIdx(groupIdx)
{
  local armyCount = 0
  foreach (wwArmyByStatus in getArmiesCache())
    foreach (wwArmyByGroup in wwArmyByStatus)
      foreach (wwArmy in wwArmyByGroup)
        if (wwArmy.getArmyGroupIdx() == groupIdx &&
            !(wwArmy.getArmyFlags() & EAF_NO_AIR_LIMIT_ACCOUNTING) &&
            ::g_ww_unit_type.isAir(wwArmy.getUnitType()))
          armyCount++

  return armyCount
}

g_operations.getAllOperationUnitsBySide <- function getAllOperationUnitsBySide(side)
{
  local operationUnits = {}
  local blk = ::DataBlock()
  ::ww_get_sides_info(blk)

  local sidesBlk = blk?["sides"]
  if (sidesBlk == null)
    return operationUnits

  local sideBlk = sidesBlk?[side.tostring()]
  if (sideBlk == null)
    return operationUnits

  foreach (unitName in sideBlk.unitsEverSeen % "item")
    if (::getAircraftByName(unitName))
      operationUnits[unitName] <- 0

  return operationUnits
}

/***************** Private ********************/

g_operations.getCurrentOperation <- function getCurrentOperation()
{
  local operationId = ::ww_get_operation_id()
  if (!(operationId in operationStatusById))
    operationStatusById[operationId] <- ::WwOperationModel()

  return operationStatusById[operationId]
}

/************* onEvent Handlers ***************/

g_operations.onEventWWFirstLoadOperation <- function onEventWWFirstLoadOperation(params)
{
  isUpdateRequired = true
}

g_operations.onEventWWLoadOperation <- function onEventWWLoadOperation(params)
{
  forcedFullUpdate()
}

g_operations.onEventWWArmyPathTrackerStatus <- function onEventWWArmyPathTrackerStatus(params)
{
  local armyName = ::getTblValue("army", params)
  getCurrentOperation().armies.updateArmyStatus(armyName)
}

::subscribe_handler(::g_operations, ::g_listener_priority.DEFAULT_HANDLER)