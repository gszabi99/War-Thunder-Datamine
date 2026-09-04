from "%scripts/dagui_library.nut" import *

let { BrowserModalHandler } = require("%scripts/onlineShop/browserWnd.nut")
let { isHandlerInScene } = require("%scripts/sqDagui/framework/baseGuiHandlerManager.nut")

function is_builtin_browser_active() {
  return isHandlerInScene(BrowserModalHandler)
}

return {
  is_builtin_browser_active
}