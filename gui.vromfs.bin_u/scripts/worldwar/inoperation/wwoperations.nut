from "%scripts/dagui_natives.nut" import ww_get_sides_info
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { get_time_msec } = require("dagor.time")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")
let { wwGetOperationId } = require("worldwar")
let { WwOperationModel } = require("model/wwOperationModel.nut")
let { g_ww_unit_type } = require("%scripts/worldWar/model/wwUnitType.nut")
let { ArmyFlags } = require("worldwarConst")

const UPDATE_REFRESH_DELAY = 1000

let operationStatusById = {}
local lastUpdateTime = 0
local isUpdateRequired = false

function getCurrentOperation() {
  let operationId = wwGetOperationId()
  if (!(operationId in operationStatusById))
    operationStatusById[operationId] <- WwOperationModel()

  return operationStatusById[operationId]
}

function getArmiesByStatus(status) {
  return getCurrentOperation().armies.getArmiesByStatus(status)
}

function getArmiesCache() {
  return getCurrentOperation().armies.armiesByStatusCache
}

function fullUpdateCurrentOperation() {
  if (!isUpdateRequired)
    return

  let curTime = get_time_msec()
  if (curTime - lastUpdateTime < UPDATE_REFRESH_DELAY)
    return

  getCurrentOperation().update()

  lastUpdateTime = curTime
  isUpdateRequired = false
}

function forcedFullUpdateCurrentOperation() {
  isUpdateRequired = true
  fullUpdateCurrentOperation()
}

function getAirArmiesNumberByGroupIdx(groupIdx,
  overrideUnitType) {
  local armyCount = 0
  foreach (wwArmyByStatus in getArmiesCache())
    foreach (wwArmyByGroup in wwArmyByStatus)
      foreach (wwArmy in wwArmyByGroup)
        if (wwArmy.getArmyGroupIdx() == groupIdx
          && !(wwArmy.getArmyFlags() & ArmyFlags.EAF_NO_AIR_LIMIT_ACCOUNTING)
            && g_ww_unit_type.isAir(wwArmy.getUnitType())
              && wwArmy.getOverrideUnitType() == overrideUnitType)
          armyCount++

  return armyCount
}

function getAllOperationUnitsBySide(side) {
  let operationUnits = {}
  let blk = DataBlock()
  ww_get_sides_info(blk)

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

addListenersWithoutEnv({
  WWFirstLoadOperation       = @(_) isUpdateRequired = true
  WWLoadOperation            = @(_) forcedFullUpdateCurrentOperation()
  function WWArmyPathTrackerStatus(params) {
    let armyName = params?.army
    getCurrentOperation().armies.updateArmyStatus(armyName)
  }
}, g_listener_priority.DEFAULT_HANDLER)

return {
  getCurrentOperation
  getArmiesByStatus
  getArmiesCache
  fullUpdateCurrentOperation
  forcedFullUpdateCurrentOperation
  getAirArmiesNumberByGroupIdx
  getAllOperationUnitsBySide
}
