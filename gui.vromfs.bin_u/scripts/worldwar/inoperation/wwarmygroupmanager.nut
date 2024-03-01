from "%scripts/dagui_library.nut" import *

let { request_nick_by_uid_batch } = require("%scripts/matching/requests.nut")
let { wwGetOperationId } = require("worldwar")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")

local armyManagersNames = {}
local currentOperationID = 0

function updateArmyManagersNames(namesByUids) {
  foreach (uid, name in namesByUids)
    armyManagersNames[uid.tointeger()] <- { name = name }
}

function updateArmyManagers(armyGroups) {
  foreach (group in armyGroups)
    group.updateManagerStat(armyManagersNames)
}

function updateManagers() {
  let operationID = wwGetOperationId()
  if (operationID != currentOperationID) {
    currentOperationID = operationID
    armyManagersNames = {}
  }

  let armyGroups = ::g_world_war.armyGroups
  let reqUids = []
  foreach (group in armyGroups)
    reqUids.extend(group.getUidsForNickRequest(armyManagersNames))

  if (reqUids.len() > 0)
    request_nick_by_uid_batch(reqUids, function(resp) {
      let namesByUids = resp?.result
      if (namesByUids == null)
        return

      updateArmyManagersNames(namesByUids)
      updateArmyManagers(armyGroups)
      wwEvent("ArmyManagersInfoUpdated")
    })
  else {
    updateArmyManagers(armyGroups)
    wwEvent("ArmyManagersInfoUpdated")
  }
}

return {
  updateManagers
}
