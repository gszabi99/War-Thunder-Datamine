//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getLocTextForLang } = require("dagor.localize")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { fillUserNick } = require("%scripts/firstChoice/firstChoice.nut")

::gui_start_eula <- function gui_start_eula(eulaType, isForView = false) {
  ::gui_start_modal_wnd(::gui_handlers.EulaWndHandler, { eulaType = eulaType, isForView = isForView })
}

::gui_handlers.EulaWndHandler <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/eulaFrame.blk"

  eulaType = ::TEXT_EULA
  isForView = false

  function initScreen() {
    fillUserNick(this.scene.findObject("usernick_place"))
    let textObj = this.scene.findObject("eulaText")
    textObj["punctuation-exception"] = "-.,'\"():/\\@"
    let isEULA = this.eulaType == ::TEXT_EULA
    ::load_text_content_to_gui_object(textObj, isEULA ? loc("eula_filename") : loc("nda_filename"))
    if (isEULA && isPlatformSony) {
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
    ::set_agreed_eula_version(this.eulaType == ::TEXT_NDA ? ::nda_version : ::eula_version, this.eulaType)
    this.sendEulaStatistic("accept")
    this.goBack()
  }

  function afterModalDestroy() {
    if (this.eulaType == ::TEXT_NDA)
      if (::should_agree_eula(::eula_version, ::TEXT_EULA))
        ::gui_start_eula(::TEXT_EULA)
  }

  function onExit() {
    this.sendEulaStatistic("decline")
    exitGame()
  }

  function sendEulaStatistic(action) {
    ::add_big_query_record("eula_screen", action)
  }
}
