from "%scripts/dagui_natives.nut" import load_text_content_to_gui_object
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let topMenuHandlerClass = require("%scripts/mainmenu/topMenuHandler.nut")

function guiStartCredits() {
  handlersManager.loadHandler(gui_handlers.CreditsMenu)
}

gui_handlers.CreditsMenu <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/credits.blk"
  rootHandlerClass = topMenuHandlerClass.getHandler()
  static hasTopMenuResearch = false

  function initScreen() {
    let textArea = (this.guiScene / "credits-text" / "textarea")
    load_text_content_to_gui_object(textArea, "%lang/credits.txt")
  }

  function onScreenClick() {
    ::on_credits_finish(true)
  }
}

return {
  guiStartCredits
}
