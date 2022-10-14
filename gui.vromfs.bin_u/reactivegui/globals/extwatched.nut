let { Watched } = require("frp")
let { subscribe } = require("eventbus")

let extData = {}

let function update(config) {
  foreach (name, value in config) {
    let watch = extData?[name]
    if (watch == null)
      continue

    watch(value)
  }
}

let function make(name, defValue) {
  if (name in extData) {
    assert(false, $"extWatched: duplicate name: {name}")
    return extData[name]
  }

  let res = Watched(defValue)
  extData[name] <- res
  res.whiteListMutatorClosure(update)
  return res
}

subscribe("updateExtWatched", update)

return make