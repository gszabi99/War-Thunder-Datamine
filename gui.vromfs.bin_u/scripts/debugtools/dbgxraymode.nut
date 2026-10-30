from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "console" import register_command
from "%scripts/dagui_library.nut" import log

local debugXrayMode = false

function setDebugXrayMode(val) {
  if (val == debugXrayMode)
    return
  debugXrayMode = val
  broadcastEvent("DebugXrayModeChange", { isActive = val })
}

let isDebugXrayModeActive = @() debugXrayMode

register_command(function() {
  setDebugXrayMode(!isDebugXrayModeActive())
  log($"DebugXrayMode is {isDebugXrayModeActive() ? "ON" : "OFF"}")
}, "debug.toggle_xray_dev_mode")

return freeze({
  setDebugXrayMode
  isDebugXrayModeActive
})
