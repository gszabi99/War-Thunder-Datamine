from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")

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

let NullKey = persist("NullKey", @() {})
let NoArg = persist("NoArg", @() {})

function memoizeByEvents(func, hashFunc = null, clearOnEvents = []) {
  let cache = {}
  local simpleCache
  local simpleCacheUsed = false
  function onEventCb(_p) {
    cache.clear()
  }
  let { parameters = null, varargs = 0, defparams = null } = func.getfuncinfos()
  let isVarargved = (varargs > 0) || ((defparams?.len() ?? 0) > 0)
  let parametersNum = (parameters?.len() ?? 0) - 1
  let isOneParam = (parametersNum == 1) && !isVarargved
  let isNoParams = (parametersNum == 0) && !isVarargved

  clearOnEvents = [].extend(clearOnEvents)
  foreach (event in alwaysClearOnEvents)
    u.appendOnce(event, clearOnEvents)
  foreach (event in clearOnEvents)
    add_event_listener(event, onEventCb, this, g_listener_priority.MEMOIZE_VALIDATION)

  if (hashFunc != null) {
    return function memoizedFuncHash(...) {
      let args = [null].extend(vargv)
      let hashKey = hashFunc(vargv) ?? NullKey
      if (hashKey in cache)
        return cache[hashKey]
      let res = func.acall(args)
      cache[hashKey] <- res
      return res
    }
  }
  else if (isOneParam) {
    return function memoizedfuncOne(v) {
      let k = v ?? NullKey
      if (k in cache)
        return cache[k]
      let res = func(v)
      cache[k] <- res
      return res
    }
  }
  else if (isNoParams) {
    return function memoizedfuncNo() {
      if (simpleCacheUsed)
        return simpleCache
      simpleCache = func()
      simpleCacheUsed = true
      return simpleCache
    }
  }
  return function memoizedFuncVargv(...) {
    let args = [null].extend(vargv)
    let hashKey = vargv.len() > 0 ? vargv[0] ?? NullKey : NoArg
    if (hashKey in cache)
      return cache[hashKey]
    let res = func.acall(args)
    cache[hashKey] <- res
    return res
  }
}


return memoizeByEvents
