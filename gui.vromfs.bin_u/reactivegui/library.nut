local log_ = require("std/log.nut")()
::debugTableData <- log_.debugTableData //used for sq debugger

global enum Layers {
  Default
  Tooltip
  Inspector
}

global const LINE_WIDTH = 1.6
global const INVALID_ENTITY_ID = 0//::ecs.INVALID_ENTITY_ID

local function mkWatched(persistFunc, persistKey, defVal=null, observableInitArg=null){
  local container = persistFunc(persistKey, @() {v=defVal})
  local watch = observableInitArg==null ? Watched(container.v) : Watched(container.v, observableInitArg)
  watch.subscribe(@(v) container.v=v)
  return watch
}

::cross_call <- class {
  path = null

  constructor () {
    path = []
  }

  function _get(idx) {
    path.append(idx)
    return this
  }

  function _call(self, ...) {
    local args = [this]
    args.append(path)
    args.extend(vargv)
    local result = ::perform_cross_call.acall(args)
    path.clear()
    return result
  }
}()

::str <- @(...) "".join(vargv)

::mkWatched <- mkWatched //warning disable: -ident-hides-ident
::log_for_user <- log_.dlog  //disable: -dlog-warn
