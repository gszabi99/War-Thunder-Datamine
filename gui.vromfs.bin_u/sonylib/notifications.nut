local stubFunc = @(...) null
local {
  createPushContext = stubFunc,
  deletePushContext = stubFunc,
  subscribeWithContext = stubFunc,
  unsubscribeFromContext = stubFunc,
  setNotificationDispatcher = stubFunc
} = require_optional("sony.webapi")
local {Watched} = require("frp")
local activeSubscriptions = persist("activeSubscriptions", @() Watched({}))

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

  activeSubscriptions.mutate(@(v) v[pushContextId] <- notify)
}

local function unsubscribe(pushContextId) {
  unsubscribeFromContext(pushContextId)
  activeSubscriptions.mutate(@(v) delete v[pushContextId])
}


return {
  subscribe
  unsubscribe
  createPushContext
  deletePushContext
}

