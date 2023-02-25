#explicit-this
#no-root-fallback
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
      tostring_r(val.value, { maxdeeplevel = 3, splitlines = false }))
  }
])

let { console_print, dlog, wlog, with_prefix, logerr } = log

return {
  log = log.log
  console_print
  wlog
  dlog  //disable: -dlog-warn
  wdlog = @(watched, prefix = null, transform = null) log.wlog(watched, prefix, transform, log.dlog) //disable: -dlog-warn
  log_with_prefix = with_prefix
  logerr
}
