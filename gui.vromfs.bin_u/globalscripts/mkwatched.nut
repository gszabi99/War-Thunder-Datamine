#explicit-this
#no-root-fallback
let { Watched } = require("frp")

let function mkWatched(persistFunc, persistKey, defVal = null, observableInitArg = null) {
  let container = persistFunc(persistKey, @() { v = defVal })
  let watch = observableInitArg == null ? Watched(container.v) : Watched(container.v, observableInitArg)
  watch.subscribe(@(v) container.v = v)
  return watch
}

return mkWatched
