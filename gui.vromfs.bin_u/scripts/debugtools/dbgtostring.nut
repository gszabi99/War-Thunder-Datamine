from "%scripts/dagui_library.nut" import *

let sqdebugger = require_optional("sqdebugger")
let console = require("console")
let { setDebugLoggingParams, debugLoggingEnable
} = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")

function initEventBroadcastLogging() {
  setDebugLoggingParams(log, get_time_msec, toString)
  console.register_command(debugLoggingEnable, "debug.subscriptions_logging_enable")
}

sqdebugger?.setObjPrintFunc(debugTableData)
console.setObjPrintFunc(debugTableData) // For dagui.exec console command

initEventBroadcastLogging()
