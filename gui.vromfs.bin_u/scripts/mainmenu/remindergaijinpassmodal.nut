//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

gui_handlers.reminderGPModal <- class extends ::BaseGuiHandler {
  wndType      = handlerType.MODAL
  sceneBlkName = "%gui/mainmenu/reminderGaijinPassModal.blk"

  function onDontShowChange(obj) {
    ::save_local_account_settings("skipped_msg/gaijinPassDontShowThisAgain", obj.getValue())
  }
}

return {
  open = @() handlersManager.loadHandler(gui_handlers.reminderGPModal)
}
