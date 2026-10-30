import "%scripts/utils/exitGamePlatform.nut" as exitGamePlatform
import "statsd" as statsd
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/login/loginWnd.nut" import LoginWndHandler
from "%scripts/loading/animBg.nut" import animBgLoad
from "%scripts/viewUtils/objectTextUpdate.nut" import setVersionText
from "%scripts/login/loginManager.nut" import addLoginState
from "%scripts/viewUtils/projectAwards.nut" import setProjectAwards
from "%scripts/utils/errorMsgBox.nut" import showErrorMessageBox
from "auth_wt" import checkLoginPass, setLoginPass
from "%globalScripts/yuplay2Consts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE

register_gui_handler("LoginWndHandlerSamsung", class (LoginWndHandler) {
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen() {
    animBgLoad()
    setVersionText(this.scene)
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
})
