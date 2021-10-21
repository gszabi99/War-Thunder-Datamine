from "frp" import Watched, Computed

local {tostring_r} = require("%sqstd/string.nut")
local logLib = require("%sqstd/log.nut")

local log = logLib([
  {
    compare = @(val) val instanceof Watched
    tostring = @(val) "Watched: {0}".subst(tostring_r(val.value,{maxdeeplevel = 3, splitlines=false}))
  }
  {
    compare = @(val) val instanceof Computed
    tostring = @(val) "Computed: {0}".subst(tostring_r(val.value,{maxdeeplevel = 3, splitlines=false}))
  }
  {
    compare = @(val) type(val)=="instance" && "formatAsString" in val
    tostring = @(val) val.formatAsString()
  }
])

local logs = {
  dlog = log.dlog //warning disable: -dlog-warn
  log
  log_for_user = log.dlog //warning disable: -dlog-warn
  dlogsplit = log.dlogsplit //warning disable: -dlog-warn
  vlog = log.vlog
  console_print = log.console_print
  wlog = log.wlog
  wdlog = @(watched, prefix = "") log.wlog(watched, prefix, log.dlog) //disable: -dlog-warn
}

return require("daRg").__merge(require("frp"), require("darg_library.nut"), require("%sqstd/functools.nut"), logs)
