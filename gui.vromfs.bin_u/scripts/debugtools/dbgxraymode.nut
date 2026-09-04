from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "console" import register_command
from "%scripts/dagui_library.nut" import log

let devXrayMode = persist("debugXrayMode", @() {isActive = false})

function setDebugXrayMode(val) {
  if (val == devXrayMode.isActive)
    return
  devXrayMode.isActive = val
  broadcastEvent("DebugXrayModeChange", { isActive = val })
}

let isDebugXrayModeActive = @() devXrayMode.isActive

register_command(function() {
  setDebugXrayMode(!isDebugXrayModeActive())
  log($"DebugXrayMode is {isDebugXrayModeActive() ? "ON" : "OFF"}")
}, "debug.toggle_xray_dev_mode")

return {
  setDebugXrayMode
  isDebugXrayModeActive
}
