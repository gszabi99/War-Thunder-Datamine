from "%rGui/fcsState.nut" import ShotState, ShotDiscrepancy, ShotDirection
from "dagor.workcycle" import deferOnce
from "%sqstd/math.nut" import round_by_value
from "%rGui/globals/ui_library.nut" import *

let fcsShotState = Watched({shotState = FCSShotState.SHOT_NONE shotDiscrepancy = 0 shotDirection = 0})

let statesQueue = []
const maxStatesQueueLength = 5
const maxShownDiscrepancyValue = 1000
const maxShownDiscrepancy = 2000

function addToQueue(shotState, shotDiscrepancy, shotDirection) {
  let discrepancy = round_by_value(shotDiscrepancy, 10)
  let direction = shotDirection
  let state = {shotState shotDiscrepancy = discrepancy shotDirection = direction}

  if(statesQueue.len() == 0 && fcsShotState.get().shotState == FCSShotState.SHOT_NONE) {
    fcsShotState.set(state)
    return
  }

  if(statesQueue.len() == maxStatesQueueLength)
    statesQueue.pop()
  statesQueue.append(state)
}

function collectShotStates() {
  if(ShotState.get() == FCSShotState.SHOT_NONE)
    return
  if(ShotDiscrepancy.get() > maxShownDiscrepancy)
    return
  if(ShotDiscrepancy.get() > maxShownDiscrepancyValue) {
    addToQueue(ShotState.get(), 0, ShotDirection.get())
    return
  }
  addToQueue(ShotState.get(), ShotDiscrepancy.get(), ShotDirection.get())
}

function showNewStateFromQueue() {
  if (statesQueue.len() == 0)
    return
  if (fcsShotState.get().shotState != FCSShotState.SHOT_NONE)
    return
  let state = statesQueue.pop()
  fcsShotState.set(state)
}

ShotState.subscribe(@(_v) deferOnce(collectShotStates))
ShotDiscrepancy.subscribe(@(_v) deferOnce(collectShotStates))
ShotDirection.subscribe(@(_v) deferOnce(collectShotStates))

fcsShotState.subscribe(function(v) {
  if (v.shotState == FCSShotState.SHOT_NONE && statesQueue.len() != 0)
    deferOnce(showNewStateFromQueue)
})

let clearCurrentShotState = @() fcsShotState.set({shotState = FCSShotState.SHOT_NONE, shotDiscrepancy = 0, shotDirection = 0})

return {
  fcsShotState
  showNewStateFromQueue
  clearCurrentShotState
}
