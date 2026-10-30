from "%scripts/onlineShop/browserWnd.nut" import BrowserModalHandler
from "%scripts/sqDagui/framework/baseGuiHandlerManager.nut" import isHandlerInScene
from "%scripts/dagui_library.nut" import *

function is_builtin_browser_active() {
  return isHandlerInScene(BrowserModalHandler)
}

return freeze({
  is_builtin_browser_active
})