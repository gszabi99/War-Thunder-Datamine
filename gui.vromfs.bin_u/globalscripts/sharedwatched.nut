let eventbus = require("eventbus")
let {log} = require("%sqstd/log.nut")()
let {isEqual} = require("%sqstd/underscore.nut")
let {Watched} = require("frp")

let sharedData = {} //id = { watch, lastReceived }
let NOT_INITED = {}

let function make(name, ctor) {
  if (name in sharedData) {
    assert(false, $"sharedWatched: duplicate name: {name}")
    return sharedData[name].watch
  }

  let res = persist(name, @() Watched(NOT_INITED))
  let data = { watch = res, lastReceived = NOT_INITED }
  sharedData[name] <- data
  if (res.value == NOT_INITED) {
    res(ctor())
    try {
      eventbus.send_foreign("sharedWatched.requestData", { name })
    } catch (err) {
      log("eventbus.send_foreign() failed")
      log(err)
      throw err?.errMsg ?? "Unknown error"
    }
  }

  res.subscribe(function(value) {
    if (data.lastReceived == value)
      return
    data.lastReceived = NOT_INITED
    try {
      eventbus.send_foreign("sharedWatched.update", { name, value })
    } catch (err) {
      log("eventbus.send_foreign() failed")
      log(err)
      throw err?.errMsg ?? "Unknown error"
    }
  })
  return res
}

eventbus.subscribe("sharedWatched.update",
  function(msg) {
    let data = sharedData?[msg.name]
    if (!data || isEqual(data.watch.value, msg.value))
      return
    data.lastReceived = msg.value
    data.watch(msg.value)
  })

eventbus.subscribe("sharedWatched.requestData",
  function(msg) {
    let w = sharedData?[msg.name].watch
    if (!w)
      return
    try {
      eventbus.send_foreign("sharedWatched.update", { name = msg.name, value = w.value })
    } catch (err) {
      log("eventbus.send_foreign() failed")
      log(err)
      throw err?.errMsg ?? "Unknown error"
    }
  })

return make