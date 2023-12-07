//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let topMenuHandlerClass = require("%scripts/mainmenu/topMenuHandler.nut")

::gui_start_credits <- function gui_start_credits() {
  handlersManager.loadHandler(gui_handlers.CreditsMenu)
}

::gui_start_credits_ingame <- function gui_start_credits_ingame() {
  ::credits_handler = handlersManager.loadHandler(gui_handlers.CreditsMenu, { backSceneParams = null })
}

gui_handlers.CreditsMenu <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/credits.blk"
  rootHandlerClass = topMenuHandlerClass.getHandler()
  static hasTopMenuResearch = false

  function initScreen() {
    let textArea = (this.guiScene / "credits-text" / "textarea")
    ::load_text_content_to_gui_object(textArea, "%lang/credits.txt")
  }

  function onScreenClick() {
    ::on_credits_finish(true)
  }
}