

import "frp" as frp
import "%darg/darg_library.nut" as darg_library
from "dagor.localize" import loc, doesLocTextExist
from "math" import min, max, clamp
require("%sqstd/globalState.nut").setUniqueNestKey("darg")
let { utf8 } = require("%globalScripts/ui_globals.nut")
let sharedEnums = require("%globalScripts/sharedEnums.nut")
let log = require("%globalScripts/logs.nut")


let shHud = @[pure](value) (darg_library.fsh(value)).tointeger()

let colorArr = @[pure](color) [(color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF, (color >> 24) & 0xFF]

return frp.__merge(
  sharedEnums,
  {loc, doesLocTextExist},
  darg_library,
  require("%sqstd/functools.nut"),
  require("daRg"),
  { shHud, utf8, min, max, clamp,
    log = log.log, dlog = log.dlog, log_for_user = log.dlog, wlog = log.wlog,
    console_print = log.console_print, log_with_prefix = log.log_with_prefix,
    colorArr,
    WtBhv = require("wt.behaviors")
  }
) 
