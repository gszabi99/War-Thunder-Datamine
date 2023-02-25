//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let sqdebugger = require_optional("sqdebugger")
let console = require("console")
let { setDebugLoggingParams, debugLoggingEnable
} = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")

let function initEventBroadcastLogging() {
  setDebugLoggingParams(log, get_time_msec, toString)
  console.register_command(debugLoggingEnable, "debug.subscriptions_logging_enable")
}

sqdebugger?.setObjPrintFunc(debugTableData)
console.setObjPrintFunc(debugTableData) // For dagui.exec console command

initEventBroadcastLogging()
