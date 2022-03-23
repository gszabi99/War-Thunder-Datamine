let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")

const INFO_WND_SAVE_PATH = "infoWnd"
/*
  simple handler to show info, with checkbox "do not show me again"

  ::gui_handlers.InfoWnd.openChecked(config)
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


  ::gui_handlers.InfoWnd.clearAllSaves()
    clear all info about saved switches
*/

::gui_handlers.InfoWnd <- class extends ::BaseGuiHandler
{
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

  static function openChecked(config)
  {
    if (!::gui_handlers.InfoWnd.canShowAgain(::getTblValue("checkId", config)))
      return false

    ::handlersManager.loadHandler(::gui_handlers.InfoWnd, config)
    return true
  }

  static function canShowAgain(chkId)
  {
    return !chkId || ::load_local_account_settings(INFO_WND_SAVE_PATH + "/" + chkId, true)
  }

  static function setCanShowAgain(chkId, isCanShowAgain)
  {
    ::save_local_account_settings(INFO_WND_SAVE_PATH + "/" + chkId, isCanShowAgain)
  }

  static function clearAllSaves()
  {
    ::save_local_account_settings(INFO_WND_SAVE_PATH, null)
  }

  function initScreen()
  {
    scene.findObject("header").setValue(header)
    scene.findObject("message").setValue(message)
    if (!checkId)
      showSceneBtn("do_not_show_me_again", false)
    createButtons()
    buttonsContext = null //remove permanent link to context

    if (!canCloseByEsc)
      scene.findObject("close_btn").have_shortcut = "BNotEsc"
  }

  function createButtons()
  {
    buttonsCbs = {}
    local markup = ""
    let infoHandler = this
    local hasBigButton = false
    if (buttons)
      foreach(idx, btn in buttons)
      {
        local cb = null
        if ("onClick" in btn)
          cb = ::Callback(btn.onClick, buttonsContext)

        let cbName = "onClickBtn" + idx
        buttonsCbs[cbName] <- (@(cb, infoHandler) function() {
          if (cb)
            cb()
          if (infoHandler && infoHandler.isValid())
            infoHandler.onButtonClick()
        })(cb, infoHandler)
        btn.funcName <- cbName
        markup += ::handyman.renderCached("%gui/commonParts/button", btn)

        hasBigButton = hasBigButton || ::getTblValue("isToBattle", btn, false)
      }
    guiScene.replaceContentFromText(scene.findObject("buttons_place"), markup, markup.len(), buttonsCbs)

    //update navBar
    if (!markup.len())
    {
      scene.findObject("info_wnd_frame")["class"] = "wnd"
      showSceneBtn("nav-help", false)
    }
    else if (hasBigButton)
      scene.findObject("info_wnd_frame").largeNavBarHeight = "yes"
  }

  function onButtonClick()
  {
    isCanceled = false
    goBack()
  }

  function onDoNotShowMeAgain(obj)
  {
    if (obj)
      setCanShowAgain(checkId, !obj.getValue())
  }

  function afterModalDestroy()
  {
    if (isCanceled && onCancel)
      onCancel()
  }
}

subscriptions.addListenersWithoutEnv({
  AccountReset = function(p) {
    ::gui_handlers.InfoWnd.clearAllSaves()
  }
}, ::g_listener_priority.CONFIG_VALIDATION)