local interopGen = require("interopGen.nut")

local warningSystemState = {
  IsMlwsLwsHudVisible = Watched(false),
  LastTargetAge = Watched(1.0),
  CurrentTime = Watched(0.0),
  mlwsTargets = [],
  mlwsTargetsTriggers = Watched(0),
  MlwsLwsSignalHoldTimeInv = Watched(0.0),
  lwsTargets = [],
  lwsTargetsTriggers = Watched(0)

  rwrTargets = [],
  rwrTargetsTriggers = Watched(0),
  rwrTrackingTargetAgeMin = 1000.0,
  RwrSignalHoldTimeInv = Watched(0.0),
  IsRwrHudVisible = Watched(false)

  IsTwsActivated = Watched(false)

  CollapsedIcon = Watched(false) //for designer switch from Icon (true) to collapsed Tws
}

::interop.clearMlwsTargets <- function() {
  local needUpdateTargets = false
  for(local i = 0; i < warningSystemState.mlwsTargets.len(); ++i) {
    if (warningSystemState.mlwsTargets[i] != null) {
      warningSystemState.mlwsTargets[i] = null
      needUpdateTargets = true
    }
  }
  if (needUpdateTargets) {
    warningSystemState.mlwsTargetsTriggers.trigger()
  }
}

::interop.clearLwsTargets <- function() {
  local needUpdateTargets = false
  for(local i = 0; i < warningSystemState.lwsTargets.len(); ++i) {
    if (warningSystemState.lwsTargets[i] != null) {
      warningSystemState.lwsTargets[i] = null
      needUpdateTargets = true
    }
  }
  if (needUpdateTargets) {
    warningSystemState.lwsTargetsTriggers.trigger()
  }
}

::interop.updateMlwsTarget <- function(index, x, y, age, enemy, track) {
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

::interop.updateLwsTarget <- function(index, x, y, age, enemy, track) {
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

::interop.clearRwrTargets <- function() {
  local needUpdateTargets = false
  for(local i = 0; i < warningSystemState.rwrTargets.len(); ++i) {
    if (warningSystemState.rwrTargets[i] != null) {
      warningSystemState.rwrTargets[i] = null
      needUpdateTargets = true
    }
  }

  if (needUpdateTargets) {
    warningSystemState.rwrTrackingTargetAgeMin = 1000.0
    warningSystemState.rwrTargetsTriggers.trigger()
  }
}

::interop.updateRwrTarget <- function(index, x, y, age, enemy, track) {
  if (index >= warningSystemState.rwrTargets.len())
    warningSystemState.rwrTargets.resize(index + 1)
  warningSystemState.rwrTargets[index] = {
    x = x,
    y = y,
    age = age,
    track = track,
    enemy = enemy
  }
  warningSystemState.rwrTargetsTriggers.trigger()
  if (track)
    warningSystemState.rwrTrackingTargetAgeMin = min(warningSystemState.rwrTrackingTargetAgeMin, age)
}

return warningSystemState