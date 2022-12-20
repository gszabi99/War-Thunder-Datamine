#explicit-this
#no-root-fallback
let { Watched } = require("frp")
let eventbus = require("eventbus")
let { ndbWrite, ndbRead, ndbExists } = require("nestdb")

let sharedData = {}

let function make(name, val) {
  if (sharedData?[name].watch != null) {
    assert(false, $"extWatched: duplicate name: {name}")
    return sharedData[name].watch
  }

  let key = ["EXT_WATCHED_STATE", name]
  if (ndbExists(key))
    val = ndbRead(key)
  else
    ndbWrite(key, val)

  let res = Watched(val)
  let data = { key, watch = res.weakref() }
  sharedData[name] <- data

  return res
}

eventbus.subscribe("extWatched.update",
  function(config) {
    foreach (name, value in config) {
      let data = sharedData?[name]
      if (data?.watch == null)
        return
      data.watch(value)
    }
  })

return make