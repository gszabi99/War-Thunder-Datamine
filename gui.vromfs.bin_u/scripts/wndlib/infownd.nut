from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

const INFO_WND_SAVE_PATH = "infoWnd"






























gui_handlers.InfoWnd <- class (BaseGuiHandler) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/wndLib/infoWnd.blk"

  checkId = null
  header = ""
  message = ""
  buttons = null
  buttonsContext = null
  onCancel = null
  canCloseByEsc = true

  isCanceled = true
  buttonsCbs = null

  static function openChecked(config) {
    if (!gui_handlers.InfoWnd.canShowAgain(getTblValue("checkId", config)))
      return false

    handlersManager.loadHandler(gui_handlers.InfoWnd, config)
    return true
  }

  static function canShowAgain(chkId) {
    return !chkId || loadLocalAccountSettings($"{INFO_WND_SAVE_PATH}/{chkId}", true)
  }

  static function setCanShowAgain(chkId, isCanShowAgain) {
    saveLocalAccountSettings($"{INFO_WND_SAVE_PATH}/{chkId}", isCanShowAgain)
  }

  static function clearAllSaves() {
    saveLocalAccountSettings(INFO_WND_SAVE_PATH, null)
  }

  function initScreen() {
    this.scene.findObject("header").setValue(this.header)
    this.scene.findObject("message").setValue(this.message)
    if (!this.checkId)
      showObjById("do_not_show_me_again", false, this.scene)
    this.createButtons()
    this.buttonsContext = null 

    if (!this.canCloseByEsc)
      this.scene.findObject("close_btn").have_shortcut = "BNotEsc"
  }

  function createButtons() {
    this.buttonsCbs = {}
    local markup = ""
    let infoHandler = this
    local hasBigButton = false
    if (this.buttons)
      foreach (idx, btn in this.buttons) {
        local cb = null
        if ("onClick" in btn)
          cb = Callback(btn.onClick, this.buttonsContext)

        let cbName = $"onClickBtn{idx}"
        this.buttonsCbs[cbName] <- function() {
          if (cb)
            cb()
          if (infoHandler && infoHandler.isValid())
            infoHandler.onButtonClick()
        }
        btn.funcName <- cbName
        markup = "".concat(markup, handyman.renderCached("%gui/commonParts/button.tpl", btn))

        hasBigButton = hasBigButton || getTblValue("isToBattle", btn, false)
      }
    this.guiScene.replaceContentFromText(this.scene.findObject("buttons_place"), markup, markup.len(), this.buttonsCbs)

    
    if (!markup.len()) {
      this.scene.findObject("info_wnd_frame")["class"] = "wnd"
      showObjById("nav-help", false, this.scene)
    }
    else if (hasBigButton)
      this.scene.findObject("info_wnd_frame").largeNavBarHeight = "yes"
  }

  function onButtonClick() {
    this.isCanceled = false
    this.goBack()
  }

  function onDoNotShowMeAgain(obj) {
    if (obj)
      this.setCanShowAgain(this.checkId, !obj.getValue())
  }

  function afterModalDestroy() {
    if (this.isCanceled && this.onCancel)
      this.onCancel()
  }
}

subscriptions.addListenersWithoutEnv({
  AccountReset = function(_p) {
    gui_handlers.InfoWnd.clearAllSaves()
  }
}, g_listener_priority.CONFIG_VALIDATION)