from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { isHandlerInScene } = require("%sqDagui/framework/baseGuiHandlerManager.nut")

function is_builtin_browser_active() {
  return isHandlerInScene(gui_handlers.BrowserModalHandler)
}

return {
  is_builtin_browser_active
}