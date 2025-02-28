from "%scripts/dagui_natives.nut" import check_login_pass, set_login_pass
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let statsd = require("statsd")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { addLoginState } = require("%scripts/login/loginManager.nut")
let { setProjectAwards } = require("%scripts/viewUtils/projectAwards.nut")

gui_handlers.LoginWndHandlerEpic <- class (gui_handlers.LoginWndHandler) {
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen() {
    animBgLoad()
    setVersionText()
    setProjectAwards(this)

    this.guiScene.performDelayed(this, function() { this.doLogin() })
  }

  function doLogin() {
    log("Epic login: check_login_pass")
    statsd.send_counter("sq.game_start.request_login", 1, { login_type = "epic" })
    addLoginState(LOGIN_STATE.LOGIN_STARTED)
    let ret = check_login_pass("", "", "epic", "epic", false, false)
    this.proceedAuthorizationResult(ret)
  }

  function proceedAuthorizationResult(result) {
    if (!checkObj(this.scene)) //check_login_pass is not instant
      return

    if (result == YU2_OK) {
      set_login_pass("", "", 0)
      addLoginState(LOGIN_STATE.AUTHORIZED)
    }
    else {
      ::error_message_box("yn1/connect_error", result,
      [
        ["exit", exitGame],
        ["tryAgain", Callback(this.doLogin, this)]
      ], "tryAgain", { cancel_fn = Callback(this.doLogin, this) })
    }
  }

  function goBack(_obj) {}
}

