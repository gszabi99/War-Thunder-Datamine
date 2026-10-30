import "%rGui/interopGen.nut" as interopGet
from "%rGui/shipStateConsts.nut" import gunState
from "%sqstd/math.nut" import fabs
from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/weaponConsts.nut" import *

let { interop } = require("%rGui/globals/interop.nut")

let shellHitDamageEvents = {
  hitEventsCount = Watched(0)
  critEventCount = Watched(0)
  armorBlockedEventCount = Watched(0)
  pierceThroughCount = Watched(0)
  crewKilled = Watched(0)
}

let gunStatesFirstRow = []
let gunStatesSecondRow = []
let torpedoStates = []
let torpedoStatesTrigger = Watched(0)

let shipState = {
  speed = Watched(0)
  steering = Watched(0.0)
  buoyancy = Watched(1.0)
  curRelativeHealth = Watched(1.0)
  maxHealth = Watched(1.0)
  fire = Watched(false)
  portSideMachine = Watched(-1)
  sideboardSideMachine = Watched(-1)
  stopping = Watched(false)

  fwdAngle = Watched(0)
  sightAngle = Watched(0)
  fov = Watched(0)

  obstacleIsNear = Watched(false)
  distanceToObstacle = Watched(-1)
  obstacleAngle = Watched(0)
  timeToDeath = Watched(-1)

  
  enginesCount = Watched(0)
  brokenEnginesCount = Watched(0)
  enginesInCooldown = Watched(false)

  steeringGearsCount = Watched(0)
  brokenSteeringGearsCount = Watched(0)

  torpedosCount = Watched(0)
  brokenTorpedosCount = Watched(0)

  artilleryType = Watched(TRIGGER_GROUP_PRIMARY)
  artilleryCount = Watched(0)
  brokenArtilleryCount = Watched(0)

  transmissionCount = Watched(0)
  brokenTransmissionCount = Watched(0)
  transmissionsInCooldown = Watched(false)

  blockMoveControl = Watched(false)

  aiGunnersState = Watched(0)
  hasAiGunners = Watched(false)

  waterDist = Watched(0)
  bottomDist = Watched(-1)
  buoyancyEx = Watched(0)
  depthLevel = Watched(0)
  wishDist = Watched(0)
  periscopeDepthCtrl = Watched(0)
  maxControlDepth = Watched(0)

  gunStatesFirstNumber = Watched(0)
  gunStatesSecondNumber = Watched(0)
  gunStatesFirstRow
  gunStatesSecondRow
  torpedoStates
  torpedoStatesTrigger
  shellHitDamageEvents
  heroCoverPartsRelHp = mkWatched(persist, "shipHeroCoverPartsRelHp", [])
  isCoverDestroyed = Watched(false)
  reloadingGunsFirstRow = Watched(0)
  reloadingGunsSecondRow = Watched(0)
  showReloadedSignalFirstRow = Watched(false)
  showReloadedSignalSecondRow = Watched(false)
  burningParts = Watched({})
  periscopeCanBeEnabled = Watched(false)
  magneticFuseSensitivity = Watched(0.0)
  fuseMode = Watched(0)
}

function isDiff(time1, time2) {
  return fabs(time1 - time2) >= 0.02
}

function isGunActive(gun) {
  return !gun.isAimerInDeadZone && (gun.state == gunState.NORMAL || gun.state == gunState.OVERHEAT) && gun.bulletsCount > 0
}

function isActiveAndReloading(gun) {
  return isGunActive(gun) && gun.gunProgress < 1
}

function updateReloadingGunsState(oldGunState, newGunState, row) {
  if (oldGunState.state == -1)
    return
  let reloadingAlarmRow = row == 1 ? shipState.showReloadedSignalFirstRow : shipState.showReloadedSignalSecondRow
  reloadingAlarmRow.set(false)

  let isOldActiveAndReloading = isActiveAndReloading(oldGunState)
  let isNewActiveAndReloading = isActiveAndReloading(newGunState)
  if (isOldActiveAndReloading == isNewActiveAndReloading)
    return
  let reloadingRow = row == 1 ? shipState.reloadingGunsFirstRow : shipState.reloadingGunsSecondRow
  reloadingRow.set(reloadingRow.get() + (isNewActiveAndReloading ? 1 : -1))
  if (reloadingRow.get() != 0 || !isGunActive(newGunState) || oldGunState.isAimerInDeadZone)
    return
  reloadingAlarmRow.set(true)
}

interop.updateShipGunStatus <- function (index, row, state, isAimerInDeadZone, startTime, endTime, gunProgress, bulletsCount) {
  let gunStatesRow = row == 1 ? gunStatesFirstRow : gunStatesSecondRow
  while (index >= gunStatesRow.len()) {
    gunStatesRow.append(Watched(
      {state = -1, isAimerInDeadZone = false, startTime = 1, endTime = 1, gunProgress = 1, bulletsCount = 1}
    ))
  }
  if (gunStatesRow[index].get().state != state ||
      gunStatesRow[index].get().isAimerInDeadZone != isAimerInDeadZone ||
      isDiff(gunStatesRow[index].get().gunProgress, gunProgress) ||
      isDiff(gunStatesRow[index].get().startTime, startTime) ||
      isDiff(gunStatesRow[index].get().endTime, endTime) ||
      isDiff(gunStatesRow[index].get().bulletsCount, bulletsCount)){
    let oldStatus = gunStatesRow[index].get()
    let newStatus = {state, isAimerInDeadZone, startTime, endTime, gunProgress, bulletsCount}
    updateReloadingGunsState(oldStatus, newStatus, row)
    gunStatesRow[index].set(newStatus)
  }
}

interop.updateShipTorpedoStatus <- function (index, tubeCount, loadedCount,
                                             startTime, endTime, reserveLeft, reserveTotal,
                                             isOperable, isInDeadZone, isOnTargetSector, isAllowedBySelection) {
  local needUpdate = false
  while (index >= torpedoStates.len()) {
    torpedoStates.append(Watched(
      { tubeCount = 0, loadedCount = 0,
        startTime = 1, endTime = 1, reserveLeft = 0, reserveTotal = 0,
        isOperable = true, isInDeadZone = false, isOnTargetSector = true, isAllowedBySelection = true }
    ))
    needUpdate = true
  }
  let cur = torpedoStates[index].get()
  if (cur.tubeCount != tubeCount
      || cur.loadedCount != loadedCount
      || cur.reserveLeft != reserveLeft
      || cur.reserveTotal != reserveTotal
      || cur.isOperable != isOperable
      || cur.isInDeadZone != isInDeadZone
      || cur.isOnTargetSector != isOnTargetSector
      || cur.isAllowedBySelection != isAllowedBySelection
      || isDiff(cur.startTime, startTime)
      || isDiff(cur.endTime, endTime)) {
    torpedoStates[index].set({ tubeCount, loadedCount, startTime, endTime, reserveLeft, reserveTotal,
      isOperable, isInDeadZone, isOnTargetSector, isAllowedBySelection })
  }

  if (needUpdate)
    torpedoStatesTrigger.trigger()
}

interop.updateShipTorpedoLaunchersCount <- function (count) {
  if (torpedoStates.len() <= count)
    return
  torpedoStates.resize(count)
  torpedoStatesTrigger.trigger()
}

interop.updateShellHitDamageEventCounts <- function(hit, crit, blocked, pierceThrough, crew) {
  shellHitDamageEvents.hitEventsCount.set(hit)
  shellHitDamageEvents.critEventCount.set(crit)
  shellHitDamageEvents.armorBlockedEventCount.set(blocked)
  shellHitDamageEvents.pierceThroughCount.set(pierceThrough)
  shellHitDamageEvents.crewKilled.set(crew)
}


interopGet({
  stateTable = shipState
  prefix = "ship"
  postfix = "Update"
})


return shipState
