from "%scripts/dagui_library.nut" import *
from "%scripts/login/loginConsts.nut" import LOGIN_STATE

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let statsd = require("statsd")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let exitGame = require("%scripts/utils/exitGame.nut")

gui_handlers.LoginWndHandlerSamsung <- class (gui_handlers.LoginWndHandler) {
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen() {
    animBgLoad()
    setVersionText()
    ::setProjectAwards(this)

    this.guiScene.performDelayed(this, function() { this.doLogin() })
  }

  function doLogin() {
    log("Samsung TV login: check_login_pass")
    statsd.send_counter("sq.game_start.request_login", 1, { login_type = "samsung" })
    let ret = ::check_login_pass("", "", "samsung", "samsung", false, false)
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
