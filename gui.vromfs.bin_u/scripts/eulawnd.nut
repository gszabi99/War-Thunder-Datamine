//-file:plus-string
from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getLocTextForLang } = require("dagor.localize")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { fillUserNick } = require("%scripts/firstChoice/firstChoice.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { setAgreedEulaVersion } = require("sqEulaUtils")
let { saveLocalSharedSettings } = require("%scripts/clientState/localProfile.nut")
let { defer } = require("dagor.workcycle")

const LOCAL_AGREED_EULA_VERSION_SAVE_ID = "agreedEulaVersion"

local eulaVesion = -1;

function getEulaVersion() {
  if ( eulaVesion == -1) {
    eulaVesion = to_integer_safe(loc("eula_version", "-1"))
  }
  return eulaVesion
}

gui_handlers.EulaWndHandler <- class extends ::BaseGuiHandler {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/eulaFrame.blk"
  isForView = false
  isNewEulaVersion = false
  doOnlyLocalSave = false
  onAcceptCallback = null

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

    if (!this.isForView && this.isNewEulaVersion) {
        this.showSceneBtn("acceptNewEulaVersion", true)
        this.showSceneBtn("accept", false)
        this.showSceneBtn("decline", false)
    } else {
        this.showSceneBtn("acceptNewEulaVersion", false)
        this.showSceneBtn("accept", !this.isForView)
        this.showSceneBtn("decline", !this.isForView)
    }
    if (this.isNewEulaVersion) {
      this.scene.findObject("eula_title").setValue(loc("eula/eulaUpdateTitle"))
    }
    this.showSceneBtn("close", this.isForView)

  }

  function onAcceptEula() {
    let currentEulaVersion = getEulaVersion()
    if (!this.doOnlyLocalSave) {
      setAgreedEulaVersion(currentEulaVersion, ::TEXT_EULA)
      this.sendEulaStatistic("accept")
    }
    saveLocalSharedSettings(LOCAL_AGREED_EULA_VERSION_SAVE_ID, currentEulaVersion)
    if (this.onAcceptCallback != null) {
      let callback = this.onAcceptCallback
      defer(@()callback())
    }
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

return {
  LOCAL_AGREED_EULA_VERSION_SAVE_ID,
  getEulaVersion
  openEulaWnd = @(param) handlersManager.loadHandler(gui_handlers.EulaWndHandler, param)
}