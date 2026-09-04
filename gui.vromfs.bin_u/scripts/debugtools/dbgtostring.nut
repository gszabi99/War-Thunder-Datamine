import "console" as console
from "%sqStdLibs/helpers/subscriptions.nut" import setDebugLoggingParams, debugLoggingEnable
from "dagor.time" import get_time_msec
from "%scripts/dagui_library.nut" import *

let sqdebugger = require_optional("sqdebugger")

function initEventBroadcastLogging() {
  setDebugLoggingParams(log, get_time_msec, toString)
  console.register_command(debugLoggingEnable, "debug.subscriptions_logging_enable")
}

sqdebugger?.setObjPrintFunc(debugTableData)
console.setObjPrintFunc(debugTableData) 

initEventBroadcastLogging()
