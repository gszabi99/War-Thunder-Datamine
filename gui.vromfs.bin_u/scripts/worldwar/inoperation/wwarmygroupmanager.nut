local { request_nick_by_uid_batch } = require("scripts/matching/requests.nut")

local armyManagersNames = {}
local currentOperationID = 0

local function updateArmyManagersNames(namesByUids) {
  foreach(uid, name in namesByUids)
    armyManagersNames[uid.tointeger()] <- { name = name }
}

local function updateArmyManagers(armyGroups) {
  foreach(group in armyGroups)
    group.updateManagerStat(armyManagersNames)
}

function updateManagers() {
  local operationID = ::ww_get_operation_id()
  if(operationID != currentOperationID) {
    currentOperationID = operationID
    armyManagersNames = {}
  }

  local armyGroups = ::g_world_war.armyGroups
  local reqUids = []
  foreach(group in armyGroups)
    reqUids.extend(group.getUidsForNickRequest(armyManagersNames))

  if (reqUids.len() > 0)
    request_nick_by_uid_batch(reqUids, function(resp) {
      local namesByUids = resp?.result
      if (namesByUids == null)
        return

      updateArmyManagersNames(namesByUids)
      updateArmyManagers(armyGroups)
      ::ww_event("ArmyManagersInfoUpdated")
    })
  else
  {
    updateArmyManagers(armyGroups)
    ::ww_event("ArmyManagersInfoUpdated")
  }
}

return {
  updateManagers = updateManagers
}
