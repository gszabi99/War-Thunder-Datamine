import "%scripts/utils/exitGamePlatform.nut" as exitGamePlatform
import "%globalScripts/wordHyphenation.nut" as wordHyphenation
from "%scripts/sqDagui/framework/baseGuiHandler.nut" import BaseGuiHandler
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/firstChoice/firstChoice.nut" import fillUserNick
from "%scripts/bqQueue/bqQueue.nut" import sendBqEvent
from "%appGlobals/clientState/localProfile.nut" import saveLocalSharedSettings
from "%scripts/langUtils/language.nut" import getCurLangShortName
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "sqEulaUtils" import setAgreedEulaVersion
from "dagor.workcycle" import defer
from "%sqstd/globalState.nut" import hardPersistWatched
from "%sqstd/packedText.nut" import readPackedText
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

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

let readEula = @(prefix, postfix) readPackedText($"%langTxt/{prefix}eula{postfix}.txt")
  ?? readPackedText($"%langTxt/{prefix}eula.txt") 

function loadAndProcessText(){
  let shortLang = getCurLangShortName()
  local langPostfix = shortLangToEulaLang?[shortLang] ?? shortLang
  langPostfix = langPostfix == "" ? "" : $"_{langPostfix}"
  let eulaPrefixForCircuit = getCurCircuitOverride("eulaPrefix", "")
  let text = readEula(eulaPrefixForCircuit, langPostfix) ?? readEula("", langPostfix)
  if (text == null)
    logerr($"EulaWnd: %langTxt/{eulaPrefixForCircuit}eula{langPostfix}.txt is missing")
  return text == null ? null : wordHyphenation(text)
}

let EulaWndHandler = class (BaseGuiHandler) {
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

    let eulaText = loadAndProcessText()
    if (eulaText == null)
      showObjById("eula_online_link", hasFeature("AllowExternalLink"), this.scene).link = getCurCircuitOverride("eulaURL", loc("url/eula"))
    textObj.setValue(eulaText ?? loc("eula/textMissing"))
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
    localAgreedEulaVersion.set(currentEulaVersion)
    saveLocalSharedSettings(LOCAL_AGREED_EULA_VERSION_SAVE_ID, currentEulaVersion)
    if (this.onAcceptCallback != null) {
      let callback = this.onAcceptCallback
      defer(@()callback())
    }
    if (!this.doOnlyLocalSave && !this.isNewEulaVersion)
      sendBqEvent("CLIENT_NEW_USER_1", "acceptEula", { details = "acceptEula" })
    this.goBack()
  }

  function afterModalDestroy() {
  }

  function onExit() {
    scene_msg_box(
      "exit_eula",
      null,
      loc("msgbox/exit_eula_warning"),
      [
        ["yes", Callback(function() {
            this.sendEulaStatistic("decline")
            if (!this.isNewEulaVersion)
              sendBqEvent("CLIENT_NEW_USER_1", "declineEula", { details = "declineEula" })
            exitGamePlatform()
          }, this)
        ],
        ["no", @() null ]
      ],
      "no"
    )
  }

  function sendEulaStatistic(action) {
    sendBqEvent("CLIENT_GAMEPLAY_1", "eula_screen", { action })
  }
}
register_gui_handler("EulaWndHandler", EulaWndHandler)

addListenersWithoutEnv({
  SignOut = @(_p) localAgreedEulaVersion.set(0) 
})

return freeze({
  LOCAL_AGREED_EULA_VERSION_SAVE_ID
  localAgreedEulaVersion
  getEulaVersion
  openEulaWnd = @(param = {}) handlersManager.loadHandler(EulaWndHandler, param)
})