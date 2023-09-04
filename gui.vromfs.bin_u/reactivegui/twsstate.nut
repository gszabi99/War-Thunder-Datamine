from "%rGui/globals/ui_library.nut" import *

let interopGen = require("interopGen.nut")
let { interop } = require("%rGui/globals/interop.nut")

let u = require("%sqStdLibs/helpers/u.nut")

let rwrSetting = require("rwrSetting.nut")

let warningSystemState = {
  CurrentTime = Watched(0.0),
  LastTargetAge = Watched(1.0),

  IsMlwsLwsHudVisible = Watched(false),

  mlwsTargets = [],
  mlwsTargetsTriggers = Watched(0),
  MlwsLwsSignalHoldTimeInv = Watched(0.0),

  lwsTargets = [],
  lwsTargetsTriggers = Watched(0)

  rwrTargets = [],
  rwrTargetsPresence = [],
  rwrTargetsTriggers = Watched(0),
  rwrTargetsPresenceTriggers = Watched(0),
  rwrTrackingTargetAgeMin = 1000.0,
  RwrSignalHoldTimeInv = Watched(0.0),
  RwrNewTargetHoldTimeInv = Watched(1000000.0),
  IsRwrHudVisible = Watched(false)
  rwrTargetsUsed = [],
  rwrTargetsUnused = [],
  rwrLastTargetsBlinkTick = 0,
  rwrBlinkableTargetsPresence = false,

  IsTwsActivated = Watched(false),
  CollapsedIcon = Watched(false) //for designer switch from Icon (true) to collapsed Tws
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
    warningSystemState.lwsTargetsTriggers.trigger()
  }
}

interop.updateMlwsTarget <- function(index, x, y, _age0, age, enemy, _track, _launch, sector, _group_id = null) {
  if (index >= warningSystemState.mlwsTargets.len())
    warningSystemState.mlwsTargets.resize(index + 1)
  warningSystemState.mlwsTargets[index] = {
    x = x,
    y = y,
    age = age,
    enemy = enemy,
    sector = sector
  }
  warningSystemState.mlwsTargetsTriggers.trigger()
}

interop.updateLwsTarget <- function(index, x, y, _age0, age, enemy, _track, _launch, sector, _group_id = null) {
  if (index >= warningSystemState.lwsTargets.len())
   warningSystemState.lwsTargets.resize(index + 1)
  warningSystemState.lwsTargets[index] = {
    x = x,
    y = y,
    age = age,
    enemy = enemy,
    sector = sector
  }
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
    warningSystemState.rwrTrackingTargetAgeMin = 1000.0
    warningSystemState.rwrBlinkableTargetsPresence = false
    warningSystemState.rwrTargetsTriggers.trigger()
  }

  local needUpdateTargetsPresence = false
  if (warningSystemState.rwrTargetsPresence.len() != rwrSetting.value.presence.len()) {
    warningSystemState.rwrTargetsPresence.resize(rwrSetting.value.presence.len())
    for (local i = 0; i < warningSystemState.rwrTargetsPresence.len(); ++i) {
      warningSystemState.rwrTargetsPresence[i] = {
        presents = false,
        age = 0.0
      }
    }
    needUpdateTargetsPresence = true
  }
  else {
    for (local i = 0; i < warningSystemState.rwrTargetsPresence.len(); ++i) {
      if (warningSystemState.rwrTargetsPresence[i].presents) {
        warningSystemState.rwrTargetsPresence[i].presents = false
        needUpdateTargetsPresence = true
      }
    }
  }

  if (needUpdateTargetsPresence) {
    warningSystemState.rwrTargetsPresenceTriggers.trigger()
  }
}

interop.updateRwrTarget <- function(index, x, y, age0, age, enemy, track, launch, sector, group_id = null) {

  local showDirection = true
  local targetGroupId = null // indicated as abstract source
  if (group_id != null && group_id >= 0 && group_id < rwrSetting.value.directionMap.len()) {
    let directionGroupId = rwrSetting.value.directionMap[group_id] // identified ?
    if (directionGroupId == null) {
      if (rwrSetting.value.direction.len() > 0)  // identification is available
        targetGroupId = -1 // indicated as unknown
    }
    else if (directionGroupId == -1)
      showDirection = false
    else
      targetGroupId = directionGroupId // indicated as indentified
  }
  else {
    if (rwrSetting.value.direction.len() > 0)
      targetGroupId = -1
  }
  if (index >= warningSystemState.rwrTargets.len())
    warningSystemState.rwrTargets.resize(index + 1)
  let rwrTarget = warningSystemState.rwrTargets[index]
  warningSystemState.rwrTargets[index] = {
    valid = showDirection,
    show = rwrTarget != null ? rwrTarget.show : true,
    x = x,
    y = y,
    age0 = age0,
    age = age,
    track = track,
    launch = launch,
    enemy = enemy,
    sector = sector,
    groupId = targetGroupId
  }

  warningSystemState.rwrTargetsTriggers.trigger()
  if (track)
    warningSystemState.rwrTrackingTargetAgeMin = min(warningSystemState.rwrTrackingTargetAgeMin, age)
  warningSystemState.rwrBlinkableTargetsPresence = warningSystemState.rwrBlinkableTargetsPresence || (sector > 2.0 || (targetGroupId != null && targetGroupId >= 0))

  let groupsId = group_id != null && group_id >= 0 && group_id < rwrSetting.value.presenceMap.len() ? rwrSetting.value.presenceMap[group_id] : rwrSetting.value.presenceDefault
  if (groupsId != null) {
    for (local j = 0; j < groupsId.len(); ++j) {
      let presenceGroupId = groupsId[j]
      let presence = rwrSetting.value.presence[presenceGroupId]
      local presents = true
      if (!track && !launch && !presence.search)
        presents = false
      if (track && !presence.track)
        presents = false
      if (launch && !presence.launch)
        presents = false
      local targetPresence = warningSystemState.rwrTargetsPresence[presenceGroupId]
      targetPresence.presents = presents
      targetPresence.age = age
    }
    warningSystemState.rwrTargetsPresenceTriggers.trigger()
  }
}

let function sqr(val) { return val * val }

let distSqMax = sqr(0.34)

interop.postUpdateRwrTargets <- function () {
  if (!warningSystemState.rwrBlinkableTargetsPresence) {
    warningSystemState.rwrTargetsTriggers.trigger()
    return
  }

  let tick = (warningSystemState.CurrentTime.value * 2.0).tointeger()
  if (tick == warningSystemState.rwrLastTargetsBlinkTick) {
    warningSystemState.rwrTargetsTriggers.trigger()
    return
  }
  warningSystemState.rwrLastTargetsBlinkTick = tick

  local rwrTargets = warningSystemState.rwrTargets
  local used = warningSystemState.rwrTargetsUsed
  local unused = warningSystemState.rwrTargetsUnused

  for (local i = 0; i < used.len(); ++i)
    rwrTargets[used[i]].show = false

  if (unused.len() + used.len() == 0) {
    unused.resize(rwrTargets.len())
    for (local i = 0; i < rwrTargets.len(); ++i)
      unused[i] = i
  }
  else if (unused.len() + used.len() < rwrTargets.len())
    // TO DO: use last RWR target index
    for (local i = 0; i < rwrTargets.len(); ++i)
      if (unused.indexof(i) == null && used.indexof(i) == null)
        unused.append(i)

  local free = u.copy(unused)
  local nulledUnusedCnt = 0
  for (local i = 0; i < free.len(); ++i) {
    local index = free[i]
    if (index == null)
      continue
    local rwrTarget = rwrTargets[index]
    if (!rwrTarget.valid)
      continue
    rwrTarget.show = true
    free[i] = null
    unused[i] = null
    ++nulledUnusedCnt
    used.append(index)
    if (rwrTarget.sector < 2.0) {
      for (local j = i + 1; j < free.len(); ++j) {
        let index2 = free[j]
        if (index2 == null)
          continue
        local rwrTarget2 = rwrTargets[index2]
        if (rwrTarget2.valid &&
            (rwrTarget.groupId >= 0 || rwrTarget2.groupId >= 0) &&
            sqr(rwrTarget.x - rwrTarget2.x) + sqr(rwrTarget.y - rwrTarget2.y) < distSqMax) {
          rwrTarget2.show = false
          free[j] = null
        }
      }
    }
  }

  if (nulledUnusedCnt == unused.len())
    unused.clear()
  else {
    local i = 0
    while (i < unused.len()) {
      if (unused[i] == null)
        unused.remove(i)
      else
        ++i
    }
  }

  local i = 0
  while (i < used.len()) {
    local rwrTarget = rwrTargets[used[i]]
    if (!rwrTarget.valid) {
      ++i
      continue
    }
    if (!rwrTarget.track && !rwrTarget.launch) {
      local collision = false
      for (local j = i + 1; j < used.len(); ++j) {
        local rwrTarget2 = rwrTargets[used[j]]
        if (rwrTarget2.valid &&
            (rwrTarget2.track || rwrTarget2.launch) &&
            (rwrTarget.groupId >= 0 || rwrTarget2.groupId >= 0) &&
            sqr(rwrTarget.x - rwrTarget2.x) + sqr(rwrTarget.y - rwrTarget2.y) < distSqMax) {
          collision = true
          break
        }
      }
      if (collision) {
        ++i
        continue
      }
    }
    local collision = false
    if (rwrTarget.sector < 2.0)
      for (local j = 0; j < unused.len(); ++j) {
        local rwrTarget2 = rwrTargets[unused[j]]
        if (rwrTarget2.valid &&
            (rwrTarget.groupId >= 0 || rwrTarget2.groupId >= 0) &&
            sqr(rwrTarget.x - rwrTarget2.x) + sqr(rwrTarget.y - rwrTarget2.y) < distSqMax) {
          collision = true
          break
        }
      }
    if (collision) {
      ++i
      continue
    }
    unused.append(used[i])
    used.remove(i)
  }

  warningSystemState.rwrTargetsTriggers.trigger()
}

return warningSystemState