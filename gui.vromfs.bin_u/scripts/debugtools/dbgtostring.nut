import "console" as console
from "%sqStdLibs/helpers/subscriptions.nut" import setDebugLoggingParams, debugLoggingEnable, getSubscriptionsStats
from "dagor.time" import get_time_msec
from "%scripts/dagui_library.nut" import *

let sqdebugger = require_optional("sqdebugger")

function printSubscriptionsStats() {
  let { events, listeners, withEnv, invalid, purgedByEnv } = getSubscriptionsStats()
  console_print($"subscriptions: events {events}, listeners {listeners}, with env {withEnv}, invalid now {invalid}")
  foreach (env in purgedByEnv.keys().sort(@(a, b) purgedByEnv[b] <=> purgedByEnv[a] || a <=> b))
    console_print($"purged {purgedByEnv[env]}: {env}")
}

function initEventBroadcastLogging() {
  setDebugLoggingParams(log, get_time_msec, toString)
  console.register_command(debugLoggingEnable, "debug.subscriptions_logging_enable")
  console.register_command(printSubscriptionsStats, "debug.subscriptions_stats")
}

sqdebugger?.setObjPrintFunc(debugTableData)
console.setObjPrintFunc(debugTableData) 

initEventBroadcastLogging()
