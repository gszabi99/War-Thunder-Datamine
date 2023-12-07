from "%scripts/dagui_library.nut" import *

let { get_time_msec } = require("dagor.time")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")
let { wwGetOperationId } = require("worldwar")
let { WwOperationModel } = require("model/wwOperationModel.nut")
let { g_ww_unit_type } = require("%scripts/worldWar/model/wwUnitType.nut")

::g_operations <- {
  operationStatusById = {}

  UPDATE_REFRESH_DELAY = 1000

  lastUpdateTime = 0
  isUpdateRequired = false
}

/******************* Public ********************/

::g_operations.forcedFullUpdate <- function forcedFullUpdate() {
  this.isUpdateRequired = true
  this.fullUpdate()
}

::g_operations.fullUpdate <- function fullUpdate() {
  if (!this.isUpdateRequired)
    return

  let curTime = get_time_msec()
  if (curTime - this.lastUpdateTime < this.UPDATE_REFRESH_DELAY)
    return

  this.getCurrentOperation().update()

  this.lastUpdateTime = curTime
  this.isUpdateRequired = false
}

::g_operations.getArmiesByStatus <- function getArmiesByStatus(status) {
  return this.getCurrentOperation().armies.getArmiesByStatus(status)
}

::g_operations.getArmiesCache <- function getArmiesCache() {
  return this.getCurrentOperation().armies.armiesByStatusCache
}

::g_operations.getAirArmiesNumberByGroupIdx <- function getAirArmiesNumberByGroupIdx(groupIdx,
  overrideUnitType) {
  local armyCount = 0
  foreach (wwArmyByStatus in this.getArmiesCache())
    foreach (wwArmyByGroup in wwArmyByStatus)
      foreach (wwArmy in wwArmyByGroup)
        if (wwArmy.getArmyGroupIdx() == groupIdx
          && !(wwArmy.getArmyFlags() & EAF_NO_AIR_LIMIT_ACCOUNTING)
            && g_ww_unit_type.isAir(wwArmy.getUnitType())
              && wwArmy.getOverrideUnitType() == overrideUnitType)
          armyCount++

  return armyCount
}

::g_operations.getAllOperationUnitsBySide <- function getAllOperationUnitsBySide(side) {
  let operationUnits = {}
  let blk = DataBlock()
  ::ww_get_sides_info(blk)

  let sidesBlk = blk?["sides"]
  if (sidesBlk == null)
    return operationUnits

  let sideBlk = sidesBlk?[side.tostring()]
  if (sideBlk == null)
    return operationUnits

  foreach (unitName in sideBlk.unitsEverSeen % "item")
    if (getAircraftByName(unitName))
      operationUnits[unitName] <- 0

  return operationUnits
}

/***************** Private ********************/

::g_operations.getCurrentOperation <- function getCurrentOperation() {
  let operationId = wwGetOperationId()
  if (!(operationId in this.operationStatusById))
    this.operationStatusById[operationId] <- WwOperationModel()

  return this.operationStatusById[operationId]
}

/************* onEvent Handlers ***************/

::g_operations.onEventWWFirstLoadOperation <- function onEventWWFirstLoadOperation(_params) {
  this.isUpdateRequired = true
}

::g_operations.onEventWWLoadOperation <- function onEventWWLoadOperation(_params) {
  this.forcedFullUpdate()
}

::g_operations.onEventWWArmyPathTrackerStatus <- function onEventWWArmyPathTrackerStatus(params) {
  let armyName = getTblValue("army", params)
  this.getCurrentOperation().armies.updateArmyStatus(armyName)
}

subscribe_handler(::g_operations, ::g_listener_priority.DEFAULT_HANDLER)