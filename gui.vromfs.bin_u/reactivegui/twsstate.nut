from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")
let { interop } = require("%rGui/globals/interop.nut")

let rwrSetting = require("%rGui/rwrSetting.nut")

let warningSystemState = {
  RwrBlkName = Watched(""),

  CurrentTime = Watched(0.0),

  IsTwsActivated = Watched(false),
  IsTwsDamaged = Watched(false),
  CollapsedIcon = Watched(false), 
  LastTargetAge = Watched(1.0),

  IsMlwsLwsHudVisible = Watched(false),
  MlwsLwsSignalHoldTimeInv = Watched(0.0),

  mlwsTargets = [],
  mlwsTargetsTriggers = Watched(0),
  mlwsTargetsAgeMin = Watched(1000.0),

  lwsTargets = [],
  lwsTargetsTriggers = Watched(0),
  lwsTargetsAgeMin = Watched(1000.0),

  rwrTargets = [],
  rwrTargetsOrder = [],
  rwrTargetsPresence = [],
  rwrTargetsTriggers = Watched(0),
  rwrTargetsPresenceTriggers = Watched(0),
  rwrTrackingTargetAgeMin = Watched(1000.0),
  rwrLaunchingTargetAgeMin = Watched(1000.0),
  RwrSignalHoldTimeInv = Watched(0.0),
  RwrNewTargetHoldTimeInv = Watched(1000000.0),
  IsRwrHudVisible = Watched(false)
}

interop.clearMlwsTargets <- function() {
  local needUpdateTargets = false
  for (local i = 0; i < warningSystemState.mlwsTargets.len(); ++i) {
    if (warningSystemState.mlwsTargets[i] != null) {
      warningSystemState.mlwsTargets[i] = null
      needUpdateTargets = true
    }
  }
  if (needUpdateTargets) {
    warningSystemState.mlwsTargetsAgeMin.set(1000.0)
    warningSystemState.mlwsTargetsTriggers.trigger()
  }
}

interop.clearLwsTargets <- function() {
  local needUpdateTargets = false
  for (local i = 0; i < warningSystemState.lwsTargets.len(); ++i) {
    if (warningSystemState.lwsTargets[i] != null) {
      warningSystemState.lwsTargets[i] = null
      needUpdateTargets = true
    }
  }
  if (needUpdateTargets) {
    warningSystemState.lwsTargetsAgeMin.set(1000.0)
    warningSystemState.lwsTargetsTriggers.trigger()
  }
}

interop.updateMlwsTarget <- function(index, x, y, _age0, age, enemy, _track, _launch, sector, _group_id, range_rel, _priority = null, _elev = null) {
  if (index >= warningSystemState.mlwsTargets.len())
    warningSystemState.mlwsTargets.resize(index + 1)
  warningSystemState.mlwsTargets[index] = {
    x = x,
    y = y,
    age = age,
    enemy = enemy,
    sector = sector,
    rangeRel = range_rel
  }
  warningSystemState.mlwsTargetsAgeMin.set(min(warningSystemState.mlwsTargetsAgeMin.get(), age))
  warningSystemState.mlwsTargetsTriggers.trigger()
}

interop.updateLwsTarget <- function(index, x, y, _age0, age, enemy, _track, _launch, sector, _group_id = null, _range_rel = null, _priority = null, _elev = null) {
  if (index >= warningSystemState.lwsTargets.len())
   warningSystemState.lwsTargets.resize(index + 1)
  warningSystemState.lwsTargets[index] = {
    x = x,
    y = y,
    age = age,
    enemy = enemy,
    sector = sector
  }
  warningSystemState.lwsTargetsAgeMin.set(min(warningSystemState.lwsTargetsAgeMin.get(), age))
  warningSystemState.lwsTargetsTriggers.trigger()
}

interopGen({
  stateTable = warningSystemState
  prefix = "tws"
  postfix = "Update"
})

interop.clearRwrTargets <- function() {
  local needUpdateTargets = false
  for (local i = 0; i < warningSystemState.rwrTargets.len(); ++i) {
    if (warningSystemState.rwrTargets[i].valid) {
      warningSystemState.rwrTargets[i].valid = false
      needUpdateTargets = true
    }
  }

  if (needUpdateTargets) {
    warningSystemState.rwrTrackingTargetAgeMin.set(1000.0)
    warningSystemState.rwrLaunchingTargetAgeMin.set(1000.0)
    warningSystemState.rwrTargetsTriggers.trigger()
  }

  local needUpdateTargetsPresence = false
  if (warningSystemState.rwrTargetsPresence.len() != rwrSetting.get().presence.len()) {
    warningSystemState.rwrTargetsPresence.resize(rwrSetting.get().presence.len())
    for (local i = 0; i < warningSystemState.rwrTargetsPresence.len(); ++i) {
      warningSystemState.rwrTargetsPresence[i] = {
        presents = false,
        age = 1000.0,
        priority = false
      }
    }
    needUpdateTargetsPresence = true
  }
  else {
    for (local i = 0; i < warningSystemState.rwrTargetsPresence.len(); ++i) {
      if (warningSystemState.rwrTargetsPresence[i].presents) {
        warningSystemState.rwrTargetsPresence[i].presents = false
        warningSystemState.rwrTargetsPresence[i].age = 1000.0
        warningSystemState.rwrTargetsPresence[i].priority = false
        needUpdateTargetsPresence = true
      }
    }
  }

  if (needUpdateTargetsPresence) {
    warningSystemState.rwrTargetsPresenceTriggers.trigger()
  }
}

interop.updateRwrTarget <- function(index, x, y, age0, age, enemy, track, launch, sector, group_id = null, range_rel = null, priority = null, elev = 0.0) {

  local showDirection = true
  local targetGroupId = null 
  if (group_id != null && group_id >= 0 && group_id < rwrSetting.get().directionMap.len()) {
    let directionGroupId = rwrSetting.get().directionMap[group_id] 
    if (directionGroupId == null) {
      if (rwrSetting.get().direction.len() > 0)  
        targetGroupId = -1 
    }
    else if (directionGroupId == -1)
      showDirection = false
    else
      targetGroupId = directionGroupId 
  }
  else {
    if (rwrSetting.get().direction.len() > 0)
      targetGroupId = -1
  }
  if (index >= warningSystemState.rwrTargets.len())
    warningSystemState.rwrTargets.resize(index + 1)
  warningSystemState.rwrTargets[index] = {
    valid = showDirection,
    show = true,
    x = x,
    y = y,
    age0 = age0,
    age = age,
    rangeRel = range_rel,
    track = track,
    launch = launch,
    enemy = enemy,
    sector = sector,
    groupId = targetGroupId,
    priority = priority,
    elev = elev
  }

  if (track)
    warningSystemState.rwrTrackingTargetAgeMin.set(min(warningSystemState.rwrTrackingTargetAgeMin.get(), age))
  if (launch)
    warningSystemState.rwrLaunchingTargetAgeMin.set(min(warningSystemState.rwrLaunchingTargetAgeMin.get(), age))

  let groupsId = group_id != null && group_id >= 0 && group_id < rwrSetting.get().presenceMap.len() ? rwrSetting.get().presenceMap[group_id] : rwrSetting.get().presenceDefault
  if (groupsId != null) {
    for (local j = 0; j < groupsId.len(); ++j) {
      let presenceGroupId = groupsId[j]
      let presence = rwrSetting.get().presence[presenceGroupId]
      local presents = true
      if (!track && !launch && !presence.search)
        presents = false
      if (track && !presence.track)
        presents = false
      if (launch && !presence.launch)
        presents = false
      local targetPresence = warningSystemState.rwrTargetsPresence[presenceGroupId]
      targetPresence.presents = targetPresence.presents || presents
      if (presents) {
        targetPresence.age = min(targetPresence.age, age)
        targetPresence.priority = targetPresence.priority || priority
      }
    }
    warningSystemState.rwrTargetsPresenceTriggers.trigger()
  }
}

interop.updateRwrTargetShow <- function(arr) {
  let rwrTargets = warningSystemState.rwrTargets
  for (local i = 0; i < arr.len() && i < rwrTargets.len(); ++i)
    if (rwrTargets[i] != null)
      rwrTargets[i].show = arr[i]
  warningSystemState.rwrTargetsTriggers.trigger()

  local rwrTargetsOrder = warningSystemState.rwrTargetsOrder
  rwrTargetsOrder.resize(rwrTargets.len())
  for (local i = 0; i < rwrTargetsOrder.len(); ++i)
    rwrTargetsOrder[i] = i
  rwrTargetsOrder.sort(@(left, right)
    rwrTargets[left].priority <=> rwrTargets[right].priority || rwrTargets[left].launch <=> rwrTargets[right].launch ||
    rwrTargets[left].track  <=> rwrTargets[right].track  || rwrTargets[right].rangeRel <=> rwrTargets[left].rangeRel)
}

return warningSystemState