local log_ = require("std/log.nut")(
  [{
    compare = @(val) type(val)=="instance" && "formatAsString" in val
    tostring = @(val) val.formatAsString()
  }]
)
require("%sqstd/regScriptDebugger.nut")(log_.debugTableData)

global enum Layers {
  Default
  Tooltip
  Inspector
}

global const LINE_WIDTH = 1.6
global const INVALID_ENTITY_ID = 0//::ecs.INVALID_ENTITY_ID

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

::log_for_user <- log_.dlog  //disable: -dlog-warn
