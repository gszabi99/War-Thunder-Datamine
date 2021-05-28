local {
  createPushContext,
  deletePushContext,
  subscribeWithContext,
  unsubscribeFromContext,
  setNotificationDispatcher
} = require("sony.webapi")

local activeSubscriptions = persist("activeSubscriptions", @() ::Watched({}))

local wasDispatcherSet = false;
local function dispatchPushNotification(notification) {
  local pushContextId = notification?.key
  if (pushContextId != null)
    activeSubscriptions.value?[pushContextId](notification)
}

local function subscribe(service, pushContextId, dataType, extdDataKey, notify) {
  if (!wasDispatcherSet) {
    setNotificationDispatcher(dispatchPushNotification)
    wasDispatcherSet = true
  }

  if (activeSubscriptions.value?[pushContextId] == null)
    subscribeWithContext(service, pushContextId, dataType, extdDataKey)

  activeSubscriptions.update(@(v) v[pushContextId] <- notify)
}

local function unsubscribe(pushContextId) {
  unsubscribeFromContext(pushContextId)
  activeSubscriptions.update(@(v) delete v[pushContextId])
}


return {
  subscribe
  unsubscribe
  createPushContext
  deletePushContext
}

