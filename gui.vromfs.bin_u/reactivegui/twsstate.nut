local interopGen = require("daRg/helpers/interopGen.nut")

local warningSystemState = {
  IsTwsHudVisible = Watched(false),
  LastTargetAge = Watched(0.0),
  CurrentTime = Watched(0.0),
  mlwsTargets = [],
  mlwsTargetsTriggers = Watched(0),
  SignalHoldTimeInv = Watched(0.0),
  lwsTargets = [],
  lwsTargetsTriggers = Watched(0)
}

::interop.clearMlwsTargets <- function() {
  local needUpdateTargets = false
  for(local i = 0; i < warningSystemState.mlwsTargets.len(); ++i)
  {
    if (warningSystemState.mlwsTargets[i] != null)
    {
      warningSystemState.mlwsTargets[i] = null
      needUpdateTargets = true
    }
  }
  if (needUpdateTargets)
  {
    warningSystemState.mlwsTargetsTriggers.trigger()
  }
}

::interop.clearLwsTargets <- function() {
  local needUpdateTargets = false
  for(local i = 0; i < warningSystemState.lwsTargets.len(); ++i)
  {
    if (warningSystemState.lwsTargets[i] != null)
    {
      warningSystemState.lwsTargets[i] = null
      needUpdateTargets = true
    }
  }
  if (needUpdateTargets)
  {
    warningSystemState.lwsTargetsTriggers.trigger()
  }
}

::interop.updateMlwsTarget <- function(index, x, y, age, enemy) {
  if (index >= warningSystemState.mlwsTargets.len())
    warningSystemState.mlwsTargets.resize(index + 1)
  warningSystemState.mlwsTargets[index] = {
    x = x,
    y = y,
    age = age,
    enemy = enemy
  }
  warningSystemState.mlwsTargetsTriggers.trigger()
}

::interop.updateLwsTarget <- function(index, x, y, age, enemy) {
  if (index >= warningSystemState.lwsTargets.len())
   warningSystemState.lwsTargets.resize(index + 1)
  warningSystemState.lwsTargets[index] = {
    x = x,
    y = y,
    age = age,
    enemy = enemy
  }
  warningSystemState.lwsTargetsTriggers.trigger()
}

interopGen({
  stateTable = warningSystemState
  prefix = "tws"
  postfix = "Update"
})

return warningSystemState