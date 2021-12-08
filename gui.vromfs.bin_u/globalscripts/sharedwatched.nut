local eventbus = require("eventbus")
local log = require("%sqstd/log.nut")()
local {isEqual} = require("%sqstd/underscore.nut")
local {Watched} = require("frp")

local sharedData = {}
local NOT_INITED = {}

local function make(name, ctor) {
  if (name in sharedData) {
    assert(false, $"sharedWatched: duplicate name: {name}")
    return sharedData[name]
  }

  local res = persist(name, @() Watched(NOT_INITED))
  sharedData[name] <- res
  if (res.value == NOT_INITED) {
    res(ctor())
    try {
      eventbus.send_foreign("sharedWatched.requestData", { name, value = res.value })
    } catch (err) {
      log("eventbus.send_foreign() failed")
      log(err)
      throw err?.errMsg ?? "Unknown error"
    }
  }

  res.subscribe(function(value) {
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
    local w = sharedData?[msg.name]
    if (w && !isEqual(w.value, msg.value))
      sharedData[msg.name](msg.value)
  })

eventbus.subscribe("sharedWatched.requestData",
  function(msg) {
    local w = sharedData?[msg.name]
    if (w && !isEqual(w.value, msg.value)) {
      try {
        eventbus.send_foreign("sharedWatched.update", { name = msg.name, value = w.value })
      } catch (err) {
        log("eventbus.send_foreign() failed")
        log(err)
        throw err?.errMsg ?? "Unknown error"
      }
    }
  })

return make