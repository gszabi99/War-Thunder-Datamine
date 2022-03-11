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

let alwaysClearOnEvents = [
  "SignOut",
  "LoginComplete",
  "ScriptsReloaded",
]

local function memoizeByEvents(func, hashFunc = null, clearOnEvents = [])
{
  hashFunc = hashFunc ?? @(...) vargv[0]

  let cacheDefault = {}
  let cacheForNull = {}

  let function onEventCb(p) {
    cacheDefault.clear()
    cacheForNull.clear()
  }

  clearOnEvents = [].extend(clearOnEvents)
  foreach (event in alwaysClearOnEvents)
    ::u.appendOnce(event, clearOnEvents)
  foreach (event in clearOnEvents)
    ::add_event_listener(event, onEventCb, this, ::g_listener_priority.MEMOIZE_VALIDATION)

  let function memoizedFunc(...) {
    let args = [null].extend(vargv)
    let rawHash = hashFunc.acall(args)
    //index cannot be null. use different cache to avoid collision
    let hash = rawHash ?? 0
    let cache = rawHash != null ? cacheDefault : cacheForNull
    if (!(hash in cache))
      cache[hash] <- func.acall(args)
    return cache[hash]
  }

  return memoizedFunc
}

return memoizeByEvents
