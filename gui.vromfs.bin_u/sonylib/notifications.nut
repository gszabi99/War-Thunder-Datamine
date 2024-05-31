let stubFunc = @(...) null
let {
  createPushContext = stubFunc,
  deletePushContext = stubFunc,
  subscribeWithContext = stubFunc,
  unsubscribeFromContext = stubFunc,
  setNotificationDispatcher = stubFunc
} = require_optional("sony.webapi")
let {Watched} = require("frp")
let activeSubscriptions = persist("activeSubscriptions", @() Watched({}))

local wasDispatcherSet = false;
function dispatchPushNotification(notification) {
  let pushContextId = notification?.key
  if (pushContextId != null)
    activeSubscriptions.value?[pushContextId](notification)
}

function subscribe(service, pushContextId, dataType, extdDataKey, notify) {
  if (!wasDispatcherSet) {
    setNotificationDispatcher(dispatchPushNotification)
    wasDispatcherSet = true
  }

  if (activeSubscriptions.value?[pushContextId] == null)
    subscribeWithContext(service, pushContextId, dataType, extdDataKey)

  activeSubscriptions.mutate(@(v) v[pushContextId] <- notify)
}

function unsubscribe(pushContextId) {
  unsubscribeFromContext(pushContextId)
  activeSubscriptions.mutate(@(v) v.$rawdelete(pushContextId))
}


return {
  subscribe
  unsubscribe
  createPushContext
  deletePushContext
}

