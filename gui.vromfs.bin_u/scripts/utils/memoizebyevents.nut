/**
 * Works as standard memoize() func, but clears cache on given subscriptions.broadcast events.
 * Memoizes a given function by caching the computed result. Useful for speeding up
 * slow-running computations. If passed an optional hashFunction, it will be used to compute
 * the hash key for storing the result, based on the arguments to the original function.
 * The default hashFunction just uses the first argument to the memoized function as the key.
 *
 * @param {function} func             - the original function to be memoized.
 * @param {function} [hashFunc]       - optional function for hash generation.
 * @param {string[]} [clearOnEvents]  - optional event names on which cache should be cleared.
 *
 * @return {function}                 - memoized function, to be used instead of the original one.
 */

local alwaysClearOnEvents = [
  "SignOut",
  "LoginComplete",
  "ScriptsReloaded",
]

local function memoizeByEvents(func, hashFunc = null, clearOnEvents = [])
{
  hashFunc = hashFunc ?? @(...) vargv[0]

  local cacheDefault = {}
  local cacheForNull = {}

  local function onEventCb(p) {
    cacheDefault.clear()
    cacheForNull.clear()
  }

  clearOnEvents = [].extend(clearOnEvents)
  foreach (event in alwaysClearOnEvents)
    ::u.appendOnce(event, clearOnEvents)
  foreach (event in clearOnEvents)
    ::add_event_listener(event, onEventCb, this, ::g_listener_priority.MEMOIZE_VALIDATION)

  local function memoizedFunc(...) {
    local args = [null].extend(vargv)
    local rawHash = hashFunc.acall(args)
    //index cannot be null. use different cache to avoid collision
    local hash = rawHash ?? 0
    local cache = rawHash != null ? cacheDefault : cacheForNull
    if (!(hash in cache))
      cache[hash] <- func.acall(args)
    return cache[hash]
  }

  return memoizedFunc
}

return memoizeByEvents
