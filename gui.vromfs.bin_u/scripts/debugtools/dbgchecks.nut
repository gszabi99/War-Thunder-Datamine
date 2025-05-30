from "%scripts/dagui_library.nut" import *

let isDebugModeEnabled = persist("isDebugModeEnabled", @() { status = false })

return {
  isDebugModeEnabled
}