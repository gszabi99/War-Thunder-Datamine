#explicit-this
#no-root-fallback
let { Watched } = require("frp")
let eventbus = require("eventbus")
let { ndbWrite, ndbRead, ndbExists } = require("nestdb")
let { log } = require("%sqstd/log.nut")()

let sharedData = {}

let function make(name, ctor) {
  if (sharedData?[name].watch != null) {
    assert(false, $"sharedWatched: duplicate name: {name}")
    return sharedData[name].watch
  }

  let key = ["SHARED_WATCHED_STATE", name]
  local val = null
  if (ndbExists(key))
    val = ndbRead(key)
  else {
    val = ctor()
    ndbWrite(key, val)
  }

  let res = Watched(val)
  let data = { key, watch = res.weakref(), isExternalEvent = false }
  sharedData[name] <- data

  res.subscribe(function(value) {
    if (data.isExternalEvent)
      return
    ndbWrite(key, value)
    try {
      eventbus.send_foreign("sharedWatched.update", { name, value })
    } catch (err) {
      log($"eventbus.send_foreign() failed (sharedWatched = {name})")
      log(err)
      throw err?.errMsg ?? "Unknown error"
    }
  })
  return res
}

eventbus.subscribe("sharedWatched.update",
  function(msg) {
    let data = sharedData?[msg.name]
    if (data?.watch == null)
      return
    data.isExternalEvent = true
    data.watch(msg.value)
    data.isExternalEvent = false
  })

return make