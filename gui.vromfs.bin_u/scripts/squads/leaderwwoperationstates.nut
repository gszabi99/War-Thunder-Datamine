from "%scripts/dagui_library.nut" import *
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { wwGetOperationId } = require("worldwar")
let { isWorldWarEnabled } = require("%scripts/globalWorldWarScripts.nut")

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
  : ::g_ww_global_status_actions.getOperationById(g_squad_manager.getWwOperationId())

return {
  LEADER_OPERATION_STATES
  getLeaderOperationState
  getSquadLeaderOperation
}
