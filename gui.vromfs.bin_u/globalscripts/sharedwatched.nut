from "frp" import this_subscriber_call_may_take_up_to_usec, get_slow_subscriber_threshold_usec
let { eventbus_send_foreign, eventbus_subscribe } = require("eventbus")
let { ndbWrite, ndbRead, ndbExists } = require("nestdb")
let { WatchedImmediate } = require("%sqstd/frp.nut")
let { log } = require("%sqstd/log.nut")()


let sharedData = {}
let persistSharedData = persist("PERSIST_SHARED_DATA", @() {}) 

let mkNdbKey = @(name) $"SHARED_WATCHED_STATE__{name}"

function make(name, ctor, slowNdbThrehsholdMul = 1) {
  if (sharedData?[name].watch != null) {
    assert(false, $"sharedWatched: duplicate name: {name}")
    return sharedData[name].watch
  }

  let key = mkNdbKey(name)
  local val = null
  if (name in persistSharedData)
    val = persistSharedData[name]
  else {
    if (ndbExists(key))
      val = ndbRead(key)
    else {
      val = ctor()
      ndbWrite(key, val)
    }
    persistSharedData[name] <- val
  }

  let res = WatchedImmediate(val)
  let data = { key, watch = res.weakref(), isExternalEvent = false }
  sharedData[name] <- data

  let onSubscription = slowNdbThrehsholdMul == 1 ? null
    : @() this_subscriber_call_may_take_up_to_usec(slowNdbThrehsholdMul * get_slow_subscriber_threshold_usec())

  res.subscribe(function(value) {
    if (data.isExternalEvent)
      return
    onSubscription?()
    ndbWrite(key, value)
    persistSharedData[name] <- value
    try {
      eventbus_send_foreign("sharedWatched.update", { name })
    } catch (err) {
      log($"eventbus_send_foreign() failed (sharedWatched = {name})")
      log(err)
      throw err?.errMsg ?? "Unknown error"
    }
  })
  return res
}

eventbus_subscribe("sharedWatched.update",
  function(msg) {
    let { name } = msg
    let data = sharedData?[name]
    if (data?.watch == null)
      return
    data.isExternalEvent = true
    let { key } = data
    if (ndbExists(key)) {
      let val = ndbRead(key)
      persistSharedData[name] <- val
      data.watch.set(val)
    }
    data.isExternalEvent = false
  })

return make