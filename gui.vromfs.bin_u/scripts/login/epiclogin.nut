//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let statsd = require("statsd")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let exitGame = require("%scripts/utils/exitGame.nut")

::gui_handlers.LoginWndHandlerEpic <- class extends ::gui_handlers.LoginWndHandler {
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen() {
    animBgLoad()
    setVersionText()
    ::setProjectAwards(this)

    this.guiScene.performDelayed(this, function() { this.doLogin() })
  }

  function doLogin() {
    log("Epic login: check_login_pass")
    statsd.send_counter("sq.game_start.request_login", 1, { login_type = "epic" })
    let ret = ::check_login_pass("", "", "epic", "epic", false, false)
    this.proceedAuthorizationResult(ret)
  }

  function proceedAuthorizationResult(result) {
    if (!checkObj(this.scene)) //check_login_pass is not instant
      return

    switch (result) {
      case YU2_OK:
        ::set_login_pass("", "", 0)
        ::g_login.addState(LOGIN_STATE.AUTHORIZED)
        break
      default:
        ::error_message_box("yn1/connect_error", result,
        [
          ["exit", exitGame],
          ["tryAgain", Callback(this.doLogin, this)]
        ], "tryAgain", { cancel_fn = Callback(this.doLogin, this) })
    }
  }

  function goBack(_obj) {}
}

