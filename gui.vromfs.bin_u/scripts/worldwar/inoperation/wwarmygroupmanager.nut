//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { request_nick_by_uid_batch } = require("%scripts/matching/requests.nut")

local armyManagersNames = {}
local currentOperationID = 0

let function updateArmyManagersNames(namesByUids) {
  foreach (uid, name in namesByUids)
    armyManagersNames[uid.tointeger()] <- { name = name }
}

let function updateArmyManagers(armyGroups) {
  foreach (group in armyGroups)
    group.updateManagerStat(armyManagersNames)
}

let function updateManagers() {
  let operationID = ::ww_get_operation_id()
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
      ::ww_event("ArmyManagersInfoUpdated")
    })
  else {
    updateArmyManagers(armyGroups)
    ::ww_event("ArmyManagersInfoUpdated")
  }
}

return {
  updateManagers
}
