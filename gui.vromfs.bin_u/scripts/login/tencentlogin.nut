let statsd = require("statsd")
let { clearBorderSymbols } = require("%sqstd/string.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let exitGame = require("%scripts/utils/exitGame.nut")

::gui_handlers.LoginWndHandlerTencent <- class extends ::BaseGuiHandler
{
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen()
  {
    animBgLoad()
    setVersionText()
    ::setProjectAwards(this)

    guiScene.performDelayed(this, function() { doLogin() })
  }

  function afterLogin()
  {
    ::g_login.addState(LOGIN_STATE.AUTHORIZED)
  }

  function doLogin()
  {
    ::dagor.debug("Login: yuplay2_tencent_login")
    statsd.send_counter("sq.game_start.request_login", 1, {login_type = "tencent"})
    let res = ::yuplay2_tencent_login()
    if (res == ::YU2_OK)
      return afterLogin()

    dagor.debug("yuplay2_tencent_login returned " + res)

    let buttons = [["exit", exitGame]]
    local defBtn = "exit"
    local cancelFnFunc = exitGame

    if (!::isInArray(res, [::YU2_TENCENT_CLIENT_DLL_LOST, ::YU2_TENCENT_CLIENT_NOT_RUNNING]))
    {
      buttons.append(["tryAgain", ::Callback(doLogin, this)])
      defBtn = "tryAgain"
      cancelFnFunc = ::Callback(doLogin, this)
    }

    ::error_message_box("yn1/connect_error", res, buttons, defBtn, { saved = true,  cancel_fn = cancelFnFunc})
  }

  function onOk()
  {
    doLogin()
  }

  function goBack(obj) {}
}

::change_nickname <- function change_nickname(onSuccess, onCancel = null)
{
  ::gui_modal_editbox_wnd({
    title = ::loc("mainmenu/chooseName")
    maxLen = 16
    validateFunc = function(nick) {
      if (::is_chat_message_empty(nick))
        return ""
      return clearBorderSymbols(nick, [" "])
    }
    canCancel = false
    allowEmpty = false
    cancelFunc = onCancel
    okFunc = (@(onSuccess, onCancel) function(nick) {
      ::do_change_nickname(nick, onSuccess, onCancel)
    })(onSuccess, onCancel)
  })
}

::do_change_nickname <- function do_change_nickname(nick, onSuccess, onCancel = null)
{
  let taskId = ::char_change_nick(nick)
  let onError = (@(onSuccess, onCancel) function(res) {
    dagor.debug("Change nickname error: " + res)
    ::change_nickname(onSuccess, onCancel)
  })(onSuccess, onCancel)

  ::g_tasker.addTask(taskId, {showProgressBox = true}, onSuccess, onError)
}
