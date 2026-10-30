from "%sqstd/string.nut" import tostring_r
from "frp" import Watched
from "types" import Function

let log = require("%sqstd/log.nut")([
  {
    compare = @(val) type(val) == "instance" && val?.formatAsString instanceof Function
    tostring = @(val) val.formatAsString()
  }
  {
    compare = @(val) val instanceof Watched
    tostring = @(val) "Watched: {0}".subst(
      tostring_r(val.get(), { maxdeeplevel = 3, splitlines = false }))
  }
])

let { console_print, dlog, wlog, wdlog, with_prefix, logerr, debugTableData } = log

return freeze({
  log = log.log
  console_print
  wlog
  dlog  
  wdlog 
  log_with_prefix = with_prefix
  logerr
  debugTableData
})
