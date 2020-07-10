local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local curSubscribeOperationId = persist("curSubscribeOperationId", @() ::Watched(-1))

local function unsubscribeOperationNotify(operationId, successCallback = null, errorCallback = null, requestOptions = null) {
  ::request_matching("worldwar.unsubscribe_operation_notify", successCallback,
    errorCallback, { operationId = operationId }, requestOptions)
}

local function subscribeOperationNotify(operationId, successCallback = null, errorCallback = null, requestOptions = null) {
  ::request_matching("worldwar.subscribe_operation_notify", successCallback,
    errorCallback, { operationId = operationId }, requestOptions)
}

local function unsubscribeCurOperation() {
  if (curSubscribeOperationId.value == -1)
    return

  unsubscribeOperationNotify(curSubscribeOperationId.value)
  curSubscribeOperationId(-1)
}

local function subscribeOperationNotifyOnce(operationId, successCallback = null, errorCallback = null, requestOptions = null) {
  if (operationId == curSubscribeOperationId.value)
    return

  unsubscribeCurOperation()
  curSubscribeOperationId(operationId)
  subscribeOperationNotify(operationId, successCallback, errorCallback, requestOptions)
}

subscriptions.addListenersWithoutEnv({
  WWStopWorldWar = @(p) unsubscribeCurOperation()
})

return {
  subscribeOperationNotify = subscribeOperationNotify
  unsubscribeOperationNotify = unsubscribeOperationNotify
  subscribeOperationNotifyOnce = subscribeOperationNotifyOnce
}