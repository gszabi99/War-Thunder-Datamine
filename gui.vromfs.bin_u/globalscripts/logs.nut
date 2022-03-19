local log = require("%sqstd/log.nut")(
  [{
    compare = @(val) type(val)=="instance" && "formatAsString" in val
    tostring = @(val) val.formatAsString()
  }]
)

return {
  log
  debugTableData = log.debugTableData
  wlog = log.wlog
  log_with_prefix = log.with_prefix
}
