from "%scripts/dagui_library.nut" import *

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")

let curSubscribeOperationId = mkWatched(persist, "curSubscribeOperationId", -1)

function unsubscribeOperationNotify(operationId, successCallback = null, errorCallback = null, requestOptions = null) {
  ::request_matching("worldwar.unsubscribe_operation_notify", successCallback,
    errorCallback, { operationId = operationId }, requestOptions)
}

function subscribeOperationNotify(operationId, successCallback = null, errorCallback = null, requestOptions = null) {
  ::request_matching("worldwar.subscribe_operation_notify", successCallback,
    errorCallback, { operationId = operationId }, requestOptions)
}

function unsubscribeCurOperation() {
  if (curSubscribeOperationId.value == -1)
    return

  unsubscribeOperationNotify(curSubscribeOperationId.value)
  curSubscribeOperationId(-1)
}

function subscribeOperationNotifyOnce(operationId, successCallback = null, errorCallback = null, requestOptions = null) {
  if (operationId == curSubscribeOperationId.value)
    return

  unsubscribeCurOperation()
  curSubscribeOperationId(operationId)
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