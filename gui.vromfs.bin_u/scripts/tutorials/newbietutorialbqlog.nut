from "%scripts/bqQueue/bqQueue.nut" import sendBqEvent

const NEW_USER_BQ_TABLE = "CLIENT_NEW_USER_1"

let sendSlotTutorialBqEvent = @(step, params)
  sendBqEvent(NEW_USER_BQ_TABLE, "tutorialSlot", { step }.__merge(params))

let sendModificationTutorialBqEvent = @(step, params)
  sendBqEvent(NEW_USER_BQ_TABLE, "tutorialModification", { step }.__merge(params))

return {
  sendSlotTutorialBqEvent
  sendModificationTutorialBqEvent
}
