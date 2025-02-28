from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")

function open_browser_modal(url = "", tags = [], baseUrl = "") {
  loadHandler(gui_handlers.BrowserModalHandler, { url, urlTags = tags, baseUrl })
}

function close_browser_modal() {
  let handler = handlersManager.findHandlerClassInScene(
    gui_handlers.BrowserModalHandler)

  if (handler == null) {
    log("[BRWS] Couldn't find embedded browser modal handler")
    return
  }

  handler.goBack()
}

function browser_set_external_url(url) {
  let handler = handlersManager.findHandlerClassInScene(
    gui_handlers.BrowserModalHandler);
  if (handler)
    handler.externalUrl = url;
}

return {
  open_browser_modal
  close_browser_modal
  browser_set_external_url
}