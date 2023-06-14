//-file:plus-string
from "%scripts/dagui_library.nut" import *

let statsd = require("statsd")
let { clearBorderSymbols } = require("%sqstd/string.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { is_chat_message_empty } = require("chat")

::gui_handlers.LoginWndHandlerTencent <- class extends ::BaseGuiHandler {
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen() {
    animBgLoad()
    setVersionText()
    ::setProjectAwards(this)

    this.guiScene.performDelayed(this, function() { this.doLogin() })
  }

  function afterLogin() {
    ::g_login.addState(LOGIN_STATE.AUTHORIZED)
  }

  function doLogin() {
    log("Login: yuplay2_tencent_login")
    statsd.send_counter("sq.game_start.request_login", 1, { login_type = "tencent" })
    let res = ::yuplay2_tencent_login()
    if (res == YU2_OK)
      return this.afterLogin()

    log("yuplay2_tencent_login returned " + res)

    let buttons = [["exit", exitGame]]
    local defBtn = "exit"
    local cancelFnFunc = exitGame

    if (!isInArray(res, [YU2_TENCENT_CLIENT_DLL_LOST, YU2_TENCENT_CLIENT_NOT_RUNNING])) {
      buttons.append(["tryAgain", Callback(this.doLogin, this)])
      defBtn = "tryAgain"
      cancelFnFunc = Callback(this.doLogin, this)
    }

    ::error_message_box("yn1/connect_error", res, buttons, defBtn, { saved = true,  cancel_fn = cancelFnFunc })
  }

  function onOk() {
    this.doLogin()
  }

  function goBack(_obj) {}
}

let function do_change_nickname(nick, onSuccess, onCancel = null) {
  let taskId = ::char_change_nick(nick)
  let onError = (@(onSuccess, onCancel) function(res) {
    log("Change nickname error: " + res)
    ::change_nickname(onSuccess, onCancel)
  })(onSuccess, onCancel)

  ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess, onError)
}

::change_nickname <- function change_nickname(onSuccess, onCancel = null) {
  ::gui_modal_editbox_wnd({
    title = loc("mainmenu/chooseName")
    maxLen = 16
    validateFunc = function(nick) {
      if (is_chat_message_empty(nick))
        return ""
      return clearBorderSymbols(nick, [" "])
    }
    canCancel = false
    allowEmpty = false
    cancelFunc = onCancel
    okFunc = (@(onSuccess, onCancel) function(nick) {
      do_change_nickname(nick, onSuccess, onCancel)
    })(onSuccess, onCancel)
  })
}
