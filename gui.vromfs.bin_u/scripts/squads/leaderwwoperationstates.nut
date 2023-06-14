//checked for plus_string
from "%scripts/dagui_library.nut" import *

let LEADER_OPERATION_STATES = {
  OUT               = "out"
  LEADER_OPERATION  = "leaderOperation"
  ANOTHER_OPERATION = "anotherOperation"
}

let function getLeaderOperationState() {
  let leaderOperationId = ::g_squad_manager.getWwOperationId()

  return !::is_worldwar_enabled() || !::g_squad_manager.isInSquad() || leaderOperationId < 0
    ? LEADER_OPERATION_STATES.OUT : ::ww_get_operation_id() == leaderOperationId
      ? LEADER_OPERATION_STATES.LEADER_OPERATION : LEADER_OPERATION_STATES.ANOTHER_OPERATION
}

let getSquadLeaderOperation = @() !::is_worldwar_enabled() || !::g_squad_manager.isInSquad() ? null
  : ::g_ww_global_status_actions.getOperationById(::g_squad_manager.getWwOperationId())

return {
  LEADER_OPERATION_STATES
  getLeaderOperationState
  getSquadLeaderOperation
}
