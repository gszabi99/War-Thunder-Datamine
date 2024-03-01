from "%rGui/globals/ui_library.nut" import *
let { deferOnce } = require("dagor.workcycle")
let { round_by_value } = require("%sqstd/math.nut")
let { ShotState, ShotDiscrepancy, ShotDirection } = require("%rGui/fcsState.nut")

let fcsShotState = Watched({shotState = FCSShotState.SHOT_NONE shotDiscrepancy = 0 shotDirection = 0})

let statesQueue = Watched([])
let maxStatesQueueLength = 5
let maxShownDiscrepancyValue = 1000
let maxShownDiscrepancy = 2000

let function addToQueue(shotState, shotDiscrepancy, shotDirection) {
  let discrepancy = round_by_value(shotDiscrepancy, 10)
  let direction = shotDirection
  let state = {shotState shotDiscrepancy = discrepancy shotDirection = direction}
  let queue = clone statesQueue.value

  if(queue.len() == 0 && fcsShotState.value.shotState == FCSShotState.SHOT_NONE) {
    fcsShotState(state)
    return
  }

  if(queue.len() == maxStatesQueueLength)
    queue.pop()
  queue.append(state)
  statesQueue(queue)
}

function collectShotStates() {
  if(ShotState.value == FCSShotState.SHOT_NONE)
    return
  if(ShotDiscrepancy.value > maxShownDiscrepancy)
    return
  if(ShotDiscrepancy.value > maxShownDiscrepancyValue) {
    addToQueue(ShotState.value, 0, ShotDirection.value)
    return
  }
  addToQueue(ShotState.value, ShotDiscrepancy.value, ShotDirection.value)
}

function showNewStateFromQueue() {
  if(statesQueue.value.len() == 0)
    return
  if(fcsShotState.value.shotState != FCSShotState.SHOT_NONE)
    return
  let queue = clone statesQueue.value
  let state = queue.pop()
  statesQueue(queue)
  fcsShotState(state)
}

ShotState.subscribe(@(_v) deferOnce(collectShotStates))
ShotDiscrepancy.subscribe(@(_v) deferOnce(collectShotStates))
ShotDirection.subscribe(@(_v) deferOnce(collectShotStates))

fcsShotState.subscribe(function(v) {
  if(v.shotState == FCSShotState.SHOT_NONE)
    deferOnce(showNewStateFromQueue)
})

let clearCurrentShotState = @() fcsShotState({shotState = FCSShotState.SHOT_NONE shotDiscrepancy = 0 ShotDirection = 0})

return {
  fcsShotState
  showNewStateFromQueue
  clearCurrentShotState
}
