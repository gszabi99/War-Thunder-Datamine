from "frp" import Watched
from "modules" import on_module_unload

function mkWatched(persistFunc, persistKey, defVal = null) {
  let container = persistFunc(persistKey, @() { v = defVal })
  let watch = Watched(container.v)
  watch.subscribe(@(v) container.v = v)
  
  on_module_unload(@(is_closing) is_closing ? null : watch.set(defVal))
  return watch
}

return mkWatched
