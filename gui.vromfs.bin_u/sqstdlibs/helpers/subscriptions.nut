
from "types" import Function
from "dagor.system" import DBGLEVEL
let callback = require("callback.nut")

const SUBSCRIPTIONS_AMOUNT_TO_CLEAR = 50

let currentBroadcastingEvents = []

local isDebugLoggingEnabled = false
local debugPrintFunc = @(...) null
local debugTimestampFunc = @(...) ""
local debugToStringFunc = @(...) ""

let subscriptionsData = {}
let purgedByEnv = {}

class Subscription {
  listenerPriority = 0
  listenerCallback = null
  isPlainFunc = false
  envDbgName = null

  constructor(func, env, priority) {
    this.isPlainFunc = env == null && func instanceof Function
    this.listenerCallback = this.isPlainFunc ? func : callback.make(func, env)
    this.listenerPriority = priority
    if (DBGLEVEL > 0 && !this.isPlainFunc)
      this.envDbgName = $"{this.listenerCallback.getContextDbgName()} {this.listenerCallback.getfuncinfos().name}"
  }
}

function getSubscriptionByEventName(event_name) {
  if (!(event_name in subscriptionsData))
    subscriptionsData[event_name] <- []
  return subscriptionsData[event_name]
}

function purge(subscriptions, idx) {
  let { envDbgName, listenerCallback } = subscriptions.remove(idx)
  if (envDbgName == null)
    return
  let key = listenerCallback.refToContext == null ? envDbgName : $"{envDbgName} (env alive)"
  purgedByEnv[key] <- (purgedByEnv?[key] ?? 0) + 1
}

function removeInvalid(subscriptions) {
  for (local i = subscriptions.len() - 1; i >= 0; --i)
    if (!subscriptions[i].isPlainFunc && !subscriptions[i].listenerCallback.isValid())
      purge(subscriptions, i)
}






function addEventListener(event_name, listener_func, listener_env = null, listener_priority = 0) {
  local subscriptions = getSubscriptionByEventName(event_name)
  if (subscriptions.len() % SUBSCRIPTIONS_AMOUNT_TO_CLEAR == 0) 
                                                                
    removeInvalid(subscriptions)

  
  local indexToInsert
  for (indexToInsert = 0; indexToInsert < subscriptions.len(); ++indexToInsert)
    if (subscriptions[indexToInsert].listenerPriority <= listener_priority)
      break

  subscriptions.insert(indexToInsert, Subscription(listener_func, listener_env, listener_priority))
}




function removeEventListenersByEnv(event_name, listener_env) {
  local subscriptions = getSubscriptionByEventName(event_name)
  for (local i = subscriptions.len() - 1; i >= 0; --i) {
    let { isPlainFunc, listenerCallback } = subscriptions[i]
    if (isPlainFunc)
      continue
    if (listenerCallback.refToContext == listener_env)
      subscriptions.remove(i)
    else if (!listenerCallback.isValid())
      purge(subscriptions, i)
  }
}




function removeAllListenersByEnv(listener_env) {
  foreach (event_name, _subscriptions in subscriptionsData)
    removeEventListenersByEnv(event_name, listener_env)
}




function subscribe_handler(handler, listener_priority = 0) {
  if (handler == null)
    return
  foreach (property_name, property in handler) {
    if (!(property instanceof Function))
      continue
    let index = property_name.indexof("onEvent")
    if (index != 0)
      continue
    let event_name = property_name.slice("onEvent".len())
    addEventListener(event_name, property, handler, listener_priority)
  }
}




function addListenersWithoutEnv(eventsList, listenerPriority = 0) {
  foreach (eventName, func in eventsList)
    addEventListener(eventName, func, null, listenerPriority)
}

function broadcast(event_name, params = {}) {
  if (isDebugLoggingEnabled)
    debugPrintFunc($"{debugTimestampFunc()} event_broadcast \"{event_name}\" {debugToStringFunc(params)}")

  currentBroadcastingEvents.append(event_name)

  local subscriptions = getSubscriptionByEventName(event_name)
  removeInvalid(subscriptions)

  
  foreach (subscription in clone subscriptions) {
    if (!subscription.isPlainFunc) {
      subscription.listenerCallback(params)
      continue
    }
    try
      subscription.listenerCallback(params)
    catch (err)
      callback.reportError(err)
  }

  currentBroadcastingEvents.pop()
}

function getSubscriptionsStats() {
  local listeners = 0
  local withEnv = 0
  local invalid = 0
  foreach (subscriptions in subscriptionsData)
    foreach (subscription in subscriptions) {
      listeners++
      if (subscription.isPlainFunc)
        continue
      withEnv++
      if (!subscription.listenerCallback.isValid())
        invalid++
    }
  return { events = subscriptionsData.len(), listeners, withEnv, invalid, purgedByEnv }
}

function setDebugLoggingParams(printFunc, timestampFunc, toStringFunc) {
  debugPrintFunc      = printFunc
  debugTimestampFunc  = timestampFunc
  debugToStringFunc   = toStringFunc
}





function debugLoggingEnable(isEnable  = null) {
  isDebugLoggingEnabled = isEnable ?? !isDebugLoggingEnabled
}

return freeze({
  broadcastEvent = broadcast
  add_event_listener = addEventListener
  subscribe_handler
  addListenersWithoutEnv
  removeEventListenersByEnv
  removeAllListenersByEnv
  setDebugLoggingParams
  debugLoggingEnable
  getSubscriptionsStats

  
  DEFAULT_HANDLER = 1
  CONFIG_VALIDATION = 2

  
  getCurrentEventName = @() currentBroadcastingEvents.len() ? currentBroadcastingEvents.top() : null 
})