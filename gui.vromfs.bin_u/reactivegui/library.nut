local log_ = require("std/log.nut")()
::debugTableData <- log_.debugTableData //used for sq debugger

global enum Layers {
  Default
  Tooltip
  Inspector
}

global const LINE_WIDTH = 1.6

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
