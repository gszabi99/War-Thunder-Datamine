from "%scripts/dagui_library.nut" import *

let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { checkMatchingError, matchingApiFunc } = require("%scripts/matching/api.nut")

let getCustomModeSaveId = @(eventName) $"queue/customEvent/{eventName}"

function getShouldEventQueueCustomMode(eventName) {
  return loadLocalAccountSettings(getCustomModeSaveId(eventName), false)
}

function setShouldEventQueueCustomMode(eventName, shouldSave) {
  return saveLocalAccountSettings(getCustomModeSaveId(eventName), shouldSave)
}

function requestLeaveQueue(queryParams, successCallback, errorCallback, needShowError = false) {
  matchingApiFunc(
    "match.leave_queue"
    function(response) {
      if (checkMatchingError(response, needShowError))
        successCallback(response)
      else
        errorCallback(response)
    }
    queryParams
  )
}

return {
  getShouldEventQueueCustomMode
  setShouldEventQueueCustomMode
  requestLeaveQueue
}
