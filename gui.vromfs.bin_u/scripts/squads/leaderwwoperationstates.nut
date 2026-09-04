from "worldwar" import wwGetOperationId
from "%scripts/dagui_library.nut" import *

let { g_squad_manager } = require("%scripts/squads/squadManager.nut")
let { isWorldWarEnabled } = require("%scripts/globalWorldWarScripts.nut")
let { wwGlobalStatusActions } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

let LEADER_OPERATION_STATES = {
  OUT               = "out"
  LEADER_OPERATION  = "leaderOperation"
  ANOTHER_OPERATION = "anotherOperation"
}

function getLeaderOperationState() {
  let leaderOperationId = g_squad_manager.getWwOperationId()

  return !isWorldWarEnabled() || !g_squad_manager.isInSquad() || leaderOperationId < 0
    ? LEADER_OPERATION_STATES.OUT : wwGetOperationId() == leaderOperationId
      ? LEADER_OPERATION_STATES.LEADER_OPERATION : LEADER_OPERATION_STATES.ANOTHER_OPERATION
}

let getSquadLeaderOperation = @() !isWorldWarEnabled() || !g_squad_manager.isInSquad() ? null
  : wwGlobalStatusActions.getOperationById(g_squad_manager.getWwOperationId())

return {
  LEADER_OPERATION_STATES
  getLeaderOperationState
  getSquadLeaderOperation
}
