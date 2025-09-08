from "%scripts/dagui_library.nut" import *

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { request_matching } = require("%scripts/matching/api.nut")

let curSubscribeOperationId = mkWatched(persist, "curSubscribeOperationId", -1)

function unsubscribeOperationNotify(operationId, successCallback = null, errorCallback = null, requestOptions = null) {
  request_matching("worldwar.unsubscribe_operation_notify", successCallback,
    errorCallback, { operationId = operationId }, requestOptions)
}

function subscribeOperationNotify(operationId, successCallback = null, errorCallback = null, requestOptions = null) {
  request_matching("worldwar.subscribe_operation_notify", successCallback,
    errorCallback, { operationId = operationId }, requestOptions)
}

function unsubscribeCurOperation() {
  if (curSubscribeOperationId.get() == -1)
    return

  unsubscribeOperationNotify(curSubscribeOperationId.get())
  curSubscribeOperationId.set(-1)
}

function subscribeOperationNotifyOnce(operationId, successCallback = null, errorCallback = null, requestOptions = null) {
  if (operationId == curSubscribeOperationId.get())
    return

  unsubscribeCurOperation()
  curSubscribeOperationId.set(operationId)
  subscribeOperationNotify(operationId, successCallback, errorCallback, requestOptions)
}

subscriptions.addListenersWithoutEnv({
  WWStopWorldWar = @(_p) unsubscribeCurOperation()
})

return {
  subscribeOperationNotify = subscribeOperationNotify
  unsubscribeOperationNotify = unsubscribeOperationNotify
  subscribeOperationNotifyOnce = subscribeOperationNotifyOnce
}