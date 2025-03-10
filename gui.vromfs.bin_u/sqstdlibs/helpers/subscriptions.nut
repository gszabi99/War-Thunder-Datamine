
let callback = require("callback.nut")

const SUBSCRIPTIONS_AMOUNT_TO_CLEAR = 50

local defaultPriority = 0

local currentBroadcastingEvents = []
local currentEventIdx = 0

local isDebugLoggingEnabled = false
local debugPrintFunc = @(...) null
local debugTimestampFunc = @(...) ""
local debugToStringFunc = @(...) ""

















let subscriptionsData = {}

let class Subscription {
  listenerPriority = 0
  listenerCallback = null

  constructor(func, env, priority) {
    this.listenerCallback = callback.make(func, env)
    this.listenerPriority = priority
  }
}

function getSubscriptionByEventName(event_name) {
  if (!(event_name in subscriptionsData))
    subscriptionsData[event_name] <- []
  return subscriptionsData[event_name]
}






function addEventListener(event_name, listener_func, listener_env = null, listener_priority = -1) {
  if (listener_priority < 0)
    listener_priority = defaultPriority

  local subscriptions = getSubscriptionByEventName(event_name)
  if (subscriptions.len() % SUBSCRIPTIONS_AMOUNT_TO_CLEAR == 0) 
                                                                
    for (local i = subscriptions.len() - 1; i >= 0; i--)
      if (!subscriptions[i].listenerCallback.isValid())
        subscriptions.remove(i)

  
  local indexToInsert
  for (indexToInsert = 0; indexToInsert < subscriptions.len(); ++indexToInsert)
    if (subscriptions[indexToInsert].listenerPriority <= listener_priority)
      break

  subscriptions.insert(indexToInsert, Subscription(listener_func, listener_env, listener_priority))
}




function removeEventListenersByEnv(event_name, listener_env) {
  local subscriptions = getSubscriptionByEventName(event_name)
  for (local i = subscriptions.len() - 1; i >= 0; --i)
    if (!subscriptions[i].listenerCallback.isValid()
      || subscriptions[i].listenerCallback.refToContext == listener_env) {
      subscriptions.remove(i)
    }
}




function removeAllListenersByEnv(listener_env) {
  foreach (event_name, _subscriptions in subscriptionsData)
    removeEventListenersByEnv(event_name, listener_env)
}




function subscribe_handler(handler, listener_priority = -1) {
  if (handler == null)
    return
  foreach (property_name, property in handler) {
    if (type(property)!="function")
      continue
    let index = property_name.indexof("onEvent")
    if (index != 0)
      continue
    let event_name = property_name.slice("onEvent".len())
    addEventListener(event_name, property, handler, listener_priority)
  }
}




function addListenersWithoutEnv(eventsList, listenerPriority = -1) {
  foreach (eventName, func in eventsList)
    addEventListener(eventName, func, null, listenerPriority)
}

function broadcast(event_name, params = {}) {
  if (isDebugLoggingEnabled)
    debugPrintFunc($"{debugTimestampFunc()} event_broadcast \"{event_name}\" {debugToStringFunc(params)}")

  currentBroadcastingEvents.append({
    eventName = event_name
    eventId = currentEventIdx++
  })

  
  local subscriptions = getSubscriptionByEventName(event_name)
  for (local i = subscriptions.len() - 1; i >= 0; --i)
    if (!subscriptions[i].listenerCallback.isValid())
      subscriptions.remove(i)

  
  local subscriptionQueue = clone subscriptions
  local queueLen = subscriptionQueue.len()
  for (local i = 0; i < queueLen; ++i)
    subscriptionQueue[i].listenerCallback(params)

  currentBroadcastingEvents.pop()
}

function setDebugLoggingParams(printFunc, timestampFunc, toStringFunc) {
  debugPrintFunc      = printFunc
  debugTimestampFunc  = timestampFunc
  debugToStringFunc   = toStringFunc
}





function debugLoggingEnable(isEnable  = null) {
  isDebugLoggingEnabled = isEnable ?? !isDebugLoggingEnabled
}

return {
  broadcastEvent = broadcast
  add_event_listener = addEventListener
  subscribe_handler
  addListenersWithoutEnv
  removeEventListenersByEnv
  removeAllListenersByEnv
  setDebugLoggingParams
  debugLoggingEnable

  
  DEFAULT = 0
  DEFAULT_HANDLER = 1
  CONFIG_VALIDATION = 2

  
  setDefaultPriority = function(priority) { defaultPriority = priority }

  
  getCurrentEventName = @() currentBroadcastingEvents.len() ? currentBroadcastingEvents.top().eventName : null 
}