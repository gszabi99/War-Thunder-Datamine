let { Watched } = require("frp")
let { eventbus_subscribe } = require("eventbus")
let { ndbWrite, ndbRead, ndbExists } = require("nestdb")

let sharedData = {}

function make(name, val) {
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
  let data = { key, watch = res }
  sharedData[name] <- data

  return res
}

eventbus_subscribe("extWatched.update",
  function(config) {
    foreach (name, value in config) {
      let data = sharedData?[name]
      if (data?.watch == null)
        return
      data.watch(value)
    }
  })

return make