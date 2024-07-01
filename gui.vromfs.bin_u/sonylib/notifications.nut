let stubFunc = @(...) null
let {
  createPushContext = stubFunc,
  deletePushContext = stubFunc,
  subscribeWithContext = stubFunc,
  unsubscribeFromContext = stubFunc,
  GENERIC_PUSH_EVENT_NAME = ""
} = require_optional("sony.webapi")
let {eventbus_subscribe, eventbus_unsubscribe} = require("eventbus")
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
    eventbus_subscribe(GENERIC_PUSH_EVENT_NAME, dispatchPushNotification)
    wasDispatcherSet = true
  }

  if (activeSubscriptions.value?[pushContextId] == null)
    subscribeWithContext(service, pushContextId, dataType, extdDataKey)

  activeSubscriptions.mutate(@(v) v[pushContextId] <- notify)
}

function unsubscribe(pushContextId) {
  unsubscribeFromContext(pushContextId)
  activeSubscriptions.mutate(@(v) v.$rawdelete(pushContextId))

  if (activeSubscriptions.len() == 0) {
    eventbus_unsubscribe(GENERIC_PUSH_EVENT_NAME, dispatchPushNotification)
    wasDispatcherSet = false
  }
}


return {
  subscribe
  unsubscribe
  createPushContext
  deletePushContext
}

