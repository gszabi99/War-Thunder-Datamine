let log = require("%sqstd/log.nut")(
  [{
    compare = @(val) type(val)=="instance" && val?.formatAsString != null
    tostring = @(val) val.formatAsString()
  }]
)

return {
  log
  console_print = log.console_print
  debugTableData = log.debugTableData
  wlog = log.wlog
  log_with_prefix = log.with_prefix
  logerr = log.logerr
}
