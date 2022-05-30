let { Watched } = require("frp")
let { tostring_r } = require("%sqstd/string.nut")

let log = require("%sqstd/log.nut")([
  {
    compare = @(val) type(val)=="instance" && val?.formatAsString != null
    tostring = @(val) val.formatAsString()
  }
  {
    compare = @(val) val instanceof Watched
    tostring = @(val) "Watched: {0}".subst(
      tostring_r(val.value, { maxdeeplevel = 3, splitlines = false }))
  }
])

let { console_print, debugTableData, dlog, wlog, with_prefix, logerr } = log

return {
  log
  console_print
  debugTableData
  wlog
  dlog  //disable: -dlog-warn
  wdlog = @(watched, prefix = "") wlog(watched, prefix, dlog) //disable: -dlog-warn
  log_with_prefix = with_prefix
  logerr
}
