from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let LEADER_OPERATION_STATES = {
  OUT               = "out"
  LEADER_OPERATION  = "leaderOperation"
  ANOTHER_OPERATION = "anotherOperation"
}

let function getLeaderOperationState() {
  let leaderOperationId = ::g_squad_manager.getWwOperationId()

  return !::is_worldwar_enabled() || leaderOperationId < 0 ? LEADER_OPERATION_STATES.OUT
    : ::ww_get_operation_id() == leaderOperationId ? LEADER_OPERATION_STATES.LEADER_OPERATION
      : LEADER_OPERATION_STATES.ANOTHER_OPERATION
}

return {
  LEADER_OPERATION_STATES
  getLeaderOperationState
}
