import "%scripts/login/twoStepModal.nut" as twoStepModal
import "%scripts/wndLib/editBoxHandler.nut" as openEditBoxDialog
import "%scripts/login/loginWndState.nut" as loginWndState
import "regexp2" as regexp2
from "%scripts/sqDagui/framework/baseGuiHandler.nut" import BaseGuiHandler
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/loading/animBg.nut" import animBgLoad
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY
from "guiOptions" import setGuiOptionsMode
from "%scripts/dirtyWordsFilter.nut" import isNamePassing
from "%scripts/utils/errorMsgBox.nut" import showErrorMessageBox
from "eventbus" import eventbus_subscribe, eventbus_send
from "%scripts/dagui_natives.nut" import enable_keyboard_layout_change_tracking, enable_keyboard_locks_change_tracking
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

const LOGIN_SHELL_BLK = "%gui/loginDargShell.blk"

let validateNickRegexp = regexp2(@"[^_0-9a-zA-Z]")


let LoginWndHandler = class (BaseGuiHandler) {
  sceneBlkName = LOGIN_SHELL_BLK

  defaultSaveLoginFlagVal = false
  defaultSavePasswordFlagVal = false
  defaultSaveAutologinFlagVal = false

  
  getWidgetsList = @() this.sceneBlkName == LOGIN_SHELL_BLK ? [{ widgetId = DargWidgets.SCREEN, screen = "login" }] : []

  function initScreen() {
    animBgLoad()
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)
    enable_keyboard_layout_change_tracking(true)
    enable_keyboard_locks_change_tracking(true)
    loginWndState.openLoginForm(this)
  }

  function onDestroy() {
    loginWndState.closeLoginForm()
    enable_keyboard_layout_change_tracking(false)
    enable_keyboard_locks_change_tracking(false)
  }

  steamAuthorization = @(steamSpecCode = "steam")
    this.proceedAuthorizationResult(loginWndState.requestSteamLogin(steamSpecCode, this), "")

  proceedAuthorizationResult = @(result, no_dump_login) loginWndState.proceedAuthorizationResult(result, no_dump_login)
  function onLoginErrorTryAgain() {}
  onEventKeyboardLayoutChanged = @(params) loginWndState.onKeyboardLayoutChanged(params.layout)
  onEventKeyboardLocksChanged = @(params) loginWndState.onKeyboardLocksChanged(params.locks)
  goBack = @() loginWndState.askQuitGame()
}
register_gui_handler("LoginWndHandler", LoginWndHandler)

let mkActionCb = @(action) action == null ? @() null : @() eventbus_send("loginScreen.action", { action })

eventbus_subscribe("loginScreen.msgBox", function(box) {
  let { uid = "info_msg_box", text = "", errorCode = null, buttons = [], defBtn = null, cancelBtn = null,
    isOwned = false } = box
  if (buttons.len() == 0) {
    showInfoMsgBox(text, uid)
    return
  }
  let btns = buttons.map(@(b) [b.id, mkActionCb(b?.action)])
  let options = cancelBtn == null ? {}
    : { cancel_fn = mkActionCb(buttons.findvalue(@(b) b.id == cancelBtn)?.action) }
  if (errorCode != null)
    showErrorMessageBox("yn1/connect_error", errorCode, btns, defBtn, options)
  else if (isOwned)
    handlersManager.getActiveBaseHandler()?.msgBox(uid, text, btns, defBtn, options)
  else
    scene_msg_box(uid, get_gui_scene(), text, btns, defBtn, options)
})

eventbus_subscribe("loginScreen.openTwoStep", @(_) twoStepModal.open({
  getLoginFormValue = loginWndState.getFormValue
  continueLogin = loginWndState.continueLogin
}))

eventbus_subscribe("loginScreen.openGuestNick", @(_) openEditBoxDialog({
  title = loc("mainmenu/chooseName")
  label = loc("choose_nickname_req")
  maxLen = 16
  validateFunc = @(nick) validateNickRegexp.replace("", nick)
  editboxWarningTooltip = loc("invalid_nickname")
  checkWarningFunc = isNamePassing
  canCancel = true
  okFunc = @(nick) eventbus_send("loginScreen.action", { action = "guestNick", nick })
}))

return freeze({ LoginWndHandler })
