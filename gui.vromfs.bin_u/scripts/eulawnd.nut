from "%scripts/dagui_natives.nut" import ps4_get_region
from "%scripts/dagui_library.nut" import *

let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
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
let wordHyphenation = require("%globalScripts/wordHyphenation.nut")
let { getCurLangShortName } = require("%scripts/langUtils/language.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")

const LOCAL_AGREED_EULA_VERSION_SAVE_ID = "agreedEulaVersion" 

local eulaVersion = -1

let localAgreedEulaVersion = hardPersistWatched("localAgreedEulaVersion", 0)

let shortLangToEulaLang = {
  en = ""
  cs = "cz"
  ja = "jp"
  zhhx = "zh"
}

function getEulaVersion() {
  if (eulaVersion == -1)
    eulaVersion = to_integer_safe(getCurCircuitOverride("eulaVersion") ?? loc("eula_version", "12"))
  return eulaVersion
}

function getExistFileNameByPrefixAndPostfix(prefix, postfix) {
  local fileName = $"%langTxt/{prefix}eula{postfix}.txt"
  if (file_exists(fileName))
    return fileName

  fileName = $"%langTxt/{prefix}eula.txt" 
  return file_exists(fileName) ? fileName : null
}

function loadAndProcessText(){
  let shortLang = getCurLangShortName()
  local langPostfix = shortLangToEulaLang?[shortLang] ?? shortLang
  langPostfix = langPostfix == "" ? "" : $"_{langPostfix}"
  let eulaPrefixForCircuit = getCurCircuitOverride("eulaPrefix", "")
  let fileName = getExistFileNameByPrefixAndPostfix(eulaPrefixForCircuit, langPostfix)
    ?? getExistFileNameByPrefixAndPostfix("", langPostfix)

  if (fileName == null)
    return ""

  return wordHyphenation(read_text_from_file(fileName))
}

gui_handlers.EulaWndHandler <- class (BaseGuiHandler) {
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
      if (ps4_get_region() == SCE_REGION_SCEA)
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
    showObjById("acceptNewEulaVersion", hasOneOkBtn, this.scene)
    showObjById("accept", !hasOneOkBtn, this.scene)
    showObjById("decline", !hasOneOkBtn, this.scene)

    let eulaTitle = getCurCircuitOverride("eulaPrefix", "") != "" ? ""
      : this.isNewEulaVersion ? loc("eula/eulaUpdateTitle")
      : loc("eula/eulaTitle")
    this.scene.findObject("eula_title").setValue(eulaTitle)
  }

  function onAcceptEula() {
    let currentEulaVersion = getEulaVersion()
    if (!this.doOnlyLocalSave) {
      setAgreedEulaVersion(currentEulaVersion)
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
  SignOut = @(_p) localAgreedEulaVersion(0) 
})

return {
  LOCAL_AGREED_EULA_VERSION_SAVE_ID
  localAgreedEulaVersion
  getEulaVersion
  openEulaWnd = @(param = {}) handlersManager.loadHandler(gui_handlers.EulaWndHandler, param)
}