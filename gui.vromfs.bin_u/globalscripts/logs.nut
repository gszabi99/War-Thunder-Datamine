let { Watched } = require("frp")
let { tostring_r } = require("%sqstd/string.nut")

let log = require("%sqstd/log.nut")([
  {
    compare = @(val) type(val) == "instance" && type(val?.formatAsString) == "function"
    tostring = @(val) val.formatAsString()
  }
  {
    compare = @(val) val instanceof Watched
    tostring = @(val) "Watched: {0}".subst(
      tostring_r(val.get(), { maxdeeplevel = 3, splitlines = false }))
  }
])

let { console_print, dlog, wlog, wdlog, with_prefix, logerr, debugTableData } = log

return {
  log = log.log
  console_print
  wlog
  dlog  
  wdlog 
  log_with_prefix = with_prefix
  logerr
  debugTableData
}
