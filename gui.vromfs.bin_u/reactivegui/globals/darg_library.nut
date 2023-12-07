// Put to global namespace for compatibility
from "math" import min, max, clamp
require("%sqstd/globalState.nut").setUniqueNestKey("darg")
let { utf8 } = require("%globalScripts/ui_globals.nut")
let sharedEnums = require("wtSharedEnums")
let { DBGLEVEL } = require("dagor.system")
let frp = require("frp")
let log = require("%globalScripts/logs.nut")
let darg_library = require("%darg/darg_library.nut")

let { set_nested_observable_debug } = frp

set_nested_observable_debug(DBGLEVEL > 0)


let shHud = @(value) (darg_library.fsh(value)).tointeger()

return frp.__merge(
  sharedEnums,
  require("dagor.localize"),
  darg_library,
  require("%sqstd/functools.nut"),
  require("daRg"),
  { shHud, utf8, min, max, clamp,
    log = log.log, dlog = log.dlog, log_for_user = log.dlog, console_print = log.console_print, log_with_prefix = log.log_with_prefix }) //disable: -dlog-warn
