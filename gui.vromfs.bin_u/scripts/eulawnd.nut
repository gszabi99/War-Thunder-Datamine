//-file:plus-string
from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getLocTextForLang } = require("dagor.localize")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { fillUserNick } = require("%scripts/firstChoice/firstChoice.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")

::gui_start_eula <- function gui_start_eula(isForView = false) {
  ::gui_start_modal_wnd(gui_handlers.EulaWndHandler, { isForView })
}

gui_handlers.EulaWndHandler <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/eulaFrame.blk"
  isForView = false

  function initScreen() {
    fillUserNick(this.scene.findObject("usernick_place"))
    let textObj = this.scene.findObject("eulaText")
    textObj["punctuation-exception"] = "-.,'\"():/\\@"
    ::load_text_content_to_gui_object(textObj, loc("eula_filename"))
    if (isPlatformSony) {
      local regionTextRootMainPart = "scee"
      if (::ps4_get_region() == SCE_REGION_SCEA)
        regionTextRootMainPart = "scea"

      local eulaText = textObj.getValue()
      let locId = "sony/" + regionTextRootMainPart
      let legalLocText = loc(locId, "")
      if (legalLocText == "") {
        log("Cannot find '" + locId + "' text for " + ::get_current_language() + " language.")
        eulaText += getLocTextForLang(locId, "English")
      }
      else
        eulaText += legalLocText

      textObj.setValue(eulaText)
    }

    this.showSceneBtn("accept", !this.isForView)
    this.showSceneBtn("decline", !this.isForView)
    this.showSceneBtn("close", this.isForView)
  }

  function onAcceptEula() {
    ::set_agreed_eula_version(::eula_version, ::TEXT_EULA)
    this.sendEulaStatistic("accept")
    this.goBack()
  }

  function afterModalDestroy() {
  }

  function onExit() {
    this.sendEulaStatistic("decline")
    exitGame()
  }

  function sendEulaStatistic(action) {
    sendBqEvent("CLIENT_GAMEPLAY_1", "eula_screen", { action })
  }
}
