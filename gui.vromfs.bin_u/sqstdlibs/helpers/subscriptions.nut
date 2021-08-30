// warning disable: -egyptian-braces
local callback = require("sqStdLibs/helpers/callback.nut")

const SUBSCRIPTIONS_AMOUNT_TO_CLEAR = 50

local defaultPriority = 0

local currentBroadcastingEvents = []
local currentEventIdx = 0

local isDebugLoggingEnabled = false
local debugPrintFunc = @(...) null
local debugTimestampFunc = @(...) ""
local debugToStringFunc = @(...) ""

/**
 * Data model:
 * {
 *   "CrewChanged" = [{ // Event name.
 *     listenerEnvWeakref = some_object_1.weakref() // Weak reference to environment object.
 *     listenerFunc = listener_func_1 // Function to call on event broadcast.
 *   }, {
 *     listenerEnvWeakref = some_object_2.weakref()
 *     listenerFunc = listener_func_2
 *   },
 *   ...
 *   ]
 *
 *   "WndModalDestroy" = ...
 * }
 */
local subscriptionsData = {}

local Subscription = class {
  listenerPriority = 0
  listenerCallback = null

  constructor(func, env, priority) {
    listenerCallback = callback.make(func, env)
    listenerPriority = priority
  }
}

local function getSubscriptionByEventName(event_name) {
  if (!(event_name in subscriptionsData))
    subscriptionsData[event_name] <- []
  return subscriptionsData[event_name]
}

/**
 * @param {function} listener_env  Optional parameter which enforces call-environment for
 *                                 specified listener function. This parameter is also used
 *                                 for removing existing listeners.
 */
local function addEventListener(event_name, listener_func, listener_env = null, listener_priority = -1) {
  if (listener_priority < 0)
    listener_priority = defaultPriority

  local subscriptions = getSubscriptionByEventName(event_name)
  if (subscriptions.len() % SUBSCRIPTIONS_AMOUNT_TO_CLEAR == 0) //if valid subscriptions more than amount to clear,
                                                                //do not need to check on each new
    for (local i = subscriptions.len() - 1; i >= 0; i--)
      if (!subscriptions[i].listenerCallback.isValid())
        subscriptions.remove(i)

  // Subscription object must be added according to specified priority.
  local indexToInsert
  for (indexToInsert = 0; indexToInsert < subscriptions.len(); ++indexToInsert)
    if (subscriptions[indexToInsert].listenerPriority <= listener_priority)
      break

  subscriptions.insert(indexToInsert, Subscription(listener_func, listener_env, listener_priority))
}

/**
 * Removes all event listeners with specified event name and environment.
 */
local function removeEventListenersByEnv(event_name, listener_env) {
  local subscriptions = getSubscriptionByEventName(event_name)
  for (local i = subscriptions.len() - 1; i >= 0; --i)
    if (!subscriptions[i].listenerCallback.isValid()
      || subscriptions[i].listenerCallback.refToContext == listener_env) {
      subscriptions.remove(i)
    }
}

/**
 * Removes all listeners with specified environment regardless to event name.
 */
local function removeAllListenersByEnv(listener_env) {
  foreach (event_name, subscriptions in subscriptionsData)
    removeEventListenersByEnv(event_name, listener_env)
}

/*
 * Subscribes all handler functions named "onEvent<eventName>" to event <eventName>
*/
::subscribeHandler <- function subscribeHandler(handler, listener_priority = -1) {
  if (handler == null)
    return
  foreach (property_name, property in handler) {
    if (type(property)!="function")
      continue
    local index = property_name.indexof("onEvent")
    if (index != 0)
      continue
    local event_name = property_name.slice("onEvent".len())
    addEventListener(event_name, property, handler, listener_priority)
  }
}

/*
 * Subscribes all events in list without enviroment
*/
::addListenersWithoutEnv <- function addListenersWithoutEnv(eventsList, listenerPriority = -1) {
  foreach (eventName, func in eventsList)
    addEventListener(eventName, func, null, listenerPriority)
}

local function broadcast(event_name, params = {}) {
  if (isDebugLoggingEnabled)
    debugPrintFunc($"{debugTimestampFunc()} event_broadcast \"{event_name}\" {debugToStringFunc(params)}")

  currentBroadcastingEvents.append({
    eventName = event_name
    eventId = currentEventIdx++
  })

  // Remove invalid callbacks.
  local subscriptions = getSubscriptionByEventName(event_name)
  for (local i = subscriptions.len() - 1; i >= 0; --i)
    if (!subscriptions[i].listenerCallback.isValid())
      subscriptions.remove(i)

  // Using cloned queue to handle properly nested broadcasts.
  local subscriptionQueue = clone subscriptions
  local queueLen = subscriptionQueue.len()
  for (local i = 0; i < queueLen; ++i)
    subscriptionQueue[i].listenerCallback(params)

  currentBroadcastingEvents.pop()
}

local function setDebugLoggingParams(printFunc, timestampFunc, toStringFunc) {
  debugPrintFunc      = printFunc
  debugTimestampFunc  = timestampFunc
  debugToStringFunc   = toStringFunc
}

/*
 * Toggles debug logging. Requires initialization by setDebugLoggingParams func.
 * @param {bool|null} isEnable - Use true/false, or null to toggle on/off
*/
local function debugLoggingEnable(isEnable  = null) {
  isDebugLoggingEnabled = isEnable ?? !isDebugLoggingEnabled
}

return {
  broadcast = broadcast
  addEventListener = addEventListener
  subscribeHandler = subscribeHandler
  addListenersWithoutEnv = addListenersWithoutEnv
  removeEventListenersByEnv = removeEventListenersByEnv
  removeAllListenersByEnv = removeAllListenersByEnv
  setDebugLoggingParams = setDebugLoggingParams
  debugLoggingEnable = debugLoggingEnable

  //standard priorities
  DEFAULT = 0
  DEFAULT_HANDLER = 1
  CONFIG_VALIDATION = 2

  //configure parameters
  setDefaultPriority = function(priority) { defaultPriority = priority }

  //debug
  getCurrentEventName = @() currentBroadcastingEvents.len() ? currentBroadcastingEvents.top().eventName : null //for debug
}