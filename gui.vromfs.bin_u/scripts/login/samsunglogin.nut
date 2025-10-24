from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE

let { checkLoginPass, setLoginPass } = require("auth_wt")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let statsd = require("statsd")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let exitGamePlatform = require("%scripts/utils/exitGamePlatform.nut")
let { addLoginState } = require("%scripts/login/loginManager.nut")
let { setProjectAwards } = require("%scripts/viewUtils/projectAwards.nut")
let { showErrorMessageBox } = require("%scripts/utils/errorMsgBox.nut")

gui_handlers.LoginWndHandlerSamsung <- class (gui_handlers.LoginWndHandler) {
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen() {
    animBgLoad()
    setVersionText()
    setProjectAwards(this)

    this.guiScene.performDelayed(this, function() { this.doLogin() })
  }

  function doLogin() {
    log("Samsung TV login: checkLoginPass")
    statsd.send_counter("sq.game_start.request_login", 1, { login_type = "samsung" })
    addLoginState(LOGIN_STATE.LOGIN_STARTED)
    let ret = checkLoginPass("", "", "samsung", "samsung", false, false)
    this.proceedAuthorizationResult(ret)
  }

  function proceedAuthorizationResult(result) {
    if (!checkObj(this.scene)) 
      return

    if (YU2_OK == result) {
      setLoginPass("", "", 0)
      addLoginState(LOGIN_STATE.AUTHORIZED)
    }
    else {
      showErrorMessageBox("yn1/connect_error", result,
      [
        ["exit", exitGamePlatform],
        ["tryAgain", Callback(this.doLogin, this)]
      ], "tryAgain", { cancel_fn = Callback(this.doLogin, this) })
    }
  }

  function goBack(_obj) {}
}
