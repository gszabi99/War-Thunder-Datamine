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
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let { read_text_from_file, file_exists } = require("dagor.fs")
let { text_wordwrap_process } = require("%appGlobals/text_wordwrap_process.nut")
const LOCAL_AGREED_EULA_VERSION_SAVE_ID = "agreedEulaVersion" //For break auto login on PS for new user, if no EULA has been accepted on this console.

local eulaVesion = -1

let localAgreedEulaVersion = hardPersistWatched("localAgreedEulaVersion", 0)

function getEulaVersion() {
  if ( eulaVesion == -1) {
    eulaVesion = to_integer_safe(loc("eula_version", "-1"))
  }
  return eulaVesion
}

let function loadAndProcessText(){
  const locId = "eula_filename"
  local fileName = loc(locId)
  if (!file_exists(fileName)) {
    logerr($"no file found: '{fileName}'")
    fileName = getLocTextForLang(locId, "English")
    if (!file_exists(fileName))
      return ""
  }
  return text_wordwrap_process(read_text_from_file(fileName))
}

gui_handlers.EulaWndHandler <- class extends ::BaseGuiHandler {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/eulaFrame.blk"
  isForView = true
  isNewEulaVersion = false
  doOnlyLocalSave = true
  onAcceptCallback = null

  function initScreen() {
    fillUserNick(this.scene.findObject("usernick_place"))
    let textObj = this.scene.findObject("eulaText")
    textObj["punctuation-exception"] = "-.,'\"():/\\@"
    textObj.setValue(loadAndProcessText())
    if (isPlatformSony) {
      local regionTextRootMainPart = "scee"
      if (::ps4_get_region() == SCE_REGION_SCEA)
        regionTextRootMainPart = "scea"

      local eulaText = textObj.getValue()
      let locId = $"sony/{regionTextRootMainPart}"
      let legalLocText = loc(locId, "")
      if (legalLocText == "") {
        log($"Cannot find '{locId}' text.")
        eulaText = "".concat(eulaText, getLocTextForLang(locId, "English"))
      }
      else
        eulaText = "".concat(eulaText, legalLocText)

      textObj.setValue(eulaText)
    }

    let hasOneOkBtn = this.isForView || this.isNewEulaVersion
    this.showSceneBtn("acceptNewEulaVersion", hasOneOkBtn)
    this.showSceneBtn("accept", !hasOneOkBtn)
    this.showSceneBtn("decline", !hasOneOkBtn)

    if (this.isNewEulaVersion)
      this.scene.findObject("eula_title").setValue(loc("eula/eulaUpdateTitle"))
  }

  function onAcceptEula() {
    let currentEulaVersion = getEulaVersion()
    if (!this.doOnlyLocalSave) {
      setAgreedEulaVersion(currentEulaVersion, ::TEXT_EULA)
      this.sendEulaStatistic("accept")
    }
    localAgreedEulaVersion(currentEulaVersion)
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

addListenersWithoutEnv({
  SignOut = @(_p) localAgreedEulaVersion(0) //for show EULA update when login for account without show new EULA version
})

return {
  LOCAL_AGREED_EULA_VERSION_SAVE_ID
  localAgreedEulaVersion
  getEulaVersion
  openEulaWnd = @(param = {}) handlersManager.loadHandler(gui_handlers.EulaWndHandler, param)
}