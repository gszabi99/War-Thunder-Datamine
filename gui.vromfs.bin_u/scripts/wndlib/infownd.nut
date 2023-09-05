//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

const INFO_WND_SAVE_PATH = "infoWnd"
/*
  simple handler to show info, with checkbox "do not show me again"

  gui_handlers.InfoWnd.openChecked(config)
    open handler by config if player never check "do not show me again"
    return true if window opened

  config:
    checkId (string) - uniq id to check is player switch on "do not show me again"
                       if null, window will not have this switch.
    header  (string) - window header
    message (string) - message to player
    buttons (array)  - buttons configs for "commonParts/button.tpl"
                       but with a difference - for buttons callbacks you use (function)onClick instead of button name.
                       example:
                       {
                         text = "#HUD_PRESS_A_CNT"
                         shortcut = "A"
                         onClick = function() { dlog("onClick") }
                         delayed = true
                       }
    buttonsContext   - context to all buttons callbacks. (used as weakref)
    onCancel (func)  - callback on close window
    canCloseByEsc    - can close window b esc. (true by default)


  gui_handlers.InfoWnd.clearAllSaves()
    clear all info about saved switches
*/

gui_handlers.InfoWnd <- class extends ::BaseGuiHandler {
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
    return !chkId || ::load_local_account_settings(INFO_WND_SAVE_PATH + "/" + chkId, true)
  }

  static function setCanShowAgain(chkId, isCanShowAgain) {
    ::save_local_account_settings(INFO_WND_SAVE_PATH + "/" + chkId, isCanShowAgain)
  }

  static function clearAllSaves() {
    ::save_local_account_settings(INFO_WND_SAVE_PATH, null)
  }

  function initScreen() {
    this.scene.findObject("header").setValue(this.header)
    this.scene.findObject("message").setValue(this.message)
    if (!this.checkId)
      this.showSceneBtn("do_not_show_me_again", false)
    this.createButtons()
    this.buttonsContext = null //remove permanent link to context

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

        let cbName = "onClickBtn" + idx
        this.buttonsCbs[cbName] <- function() {
          if (cb)
            cb()
          if (infoHandler && infoHandler.isValid())
            infoHandler.onButtonClick()
        }
        btn.funcName <- cbName
        markup += handyman.renderCached("%gui/commonParts/button.tpl", btn)

        hasBigButton = hasBigButton || getTblValue("isToBattle", btn, false)
      }
    this.guiScene.replaceContentFromText(this.scene.findObject("buttons_place"), markup, markup.len(), this.buttonsCbs)

    //update navBar
    if (!markup.len()) {
      this.scene.findObject("info_wnd_frame")["class"] = "wnd"
      this.showSceneBtn("nav-help", false)
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
}, ::g_listener_priority.CONFIG_VALIDATION)