import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
from "%scripts/matching/api.nut" import request_matching
from "%scripts/dagui_library.nut" import *

let curSubscribeOperationId = mkHardPersistWatched("worldWar.services.wwService")("curSubscribeOperationId", -1)

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

return freeze({
  subscribeOperationNotify = subscribeOperationNotify
  unsubscribeOperationNotify = unsubscribeOperationNotify
  subscribeOperationNotifyOnce = subscribeOperationNotifyOnce
})