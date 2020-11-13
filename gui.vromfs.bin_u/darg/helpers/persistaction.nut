local actions = persist("actions", @() {})
local refreshedActionsIds = {}

local function register(actionId, action) {
  if (actionId in refreshedActionsIds) {
    ::assert(false, @() "Persist action {0} already registered".subst(actionId))
    return
  }

  local infos = action.getfuncinfos()
  local paramsNum = infos.parameters.len()
  ::assert(paramsNum >= 2, "Action {0} has lower than 1 parameter".subst(actionId))

  refreshedActionsIds[actionId] <- true
  actions[actionId] <- action
}

local function make(actionId, params) {
  ::assert(actionId in refreshedActionsIds, @() "Not registered persist action {0}".subst(actionId))

  return function(...) {
    local action = actions?[actionId]
    if (!action) //not recreated after script reload
      return
    ::assert(vargv.len() == action.getfuncinfos().parameters.len() - 2, @() "Incorrect params count on call action {0}".subst(actionId))
    return action.acall([this, params].extend(vargv))
  }
}

return {
  register = register
  make = make
}