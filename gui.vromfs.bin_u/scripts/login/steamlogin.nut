from "%appGlobals/login/loginState.nut" import isAuthorized
from "auth_wt" import getLoginPass
from "guiOptions" import setGuiOptionsMode
from "steam" import steam_is_running
from "%globalScripts/yuplay2Consts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import USE_STEAM_LOGIN_AUTO_SETTING_ID

let { set_disable_autorelogin_once } = require("%scripts/login/loginState.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { LoginWndHandler } = require("%scripts/login/loginWnd.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let exitGamePlatform = require("%scripts/utils/exitGamePlatform.nut")
let { saveLocalSharedSettings, loadLocalSharedSettings } = require("%scripts/clientState/localProfile.nut")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { openEulaWnd } = require("%scripts/eulaWnd.nut")
let { is_autologin_enabled } = require("%scripts/options/optionsBeforeLogin.nut")
let { setProjectAwards } = require("%scripts/viewUtils/projectAwards.nut")

register_gui_handler("LoginWndHandlerSteam", class (LoginWndHandler) {
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen() {
    animBgLoad()
    setVersionText()
    setProjectAwards(this)
    showTitleLogo(this.scene, 128)
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    let lp = getLoginPass()
    this.defaultSaveLoginFlagVal = lp.login != ""
    this.defaultSavePasswordFlagVal = lp.password != ""
    this.defaultSaveAutologinFlagVal = is_autologin_enabled()

    
    
    if (isAuthorized.get())
      return

    this.tryLogin()
  }

  function tryLogin() {
    let useSteamLoginAuto = loadLocalSharedSettings(USE_STEAM_LOGIN_AUTO_SETTING_ID, true)
    if (!useSteamLoginAuto) 
      this.goToLoginWnd(useSteamLoginAuto == null)
    else
      this.guiScene.performDelayed(this, @() this.steamAuthorization("steam-known"))
  }

  function proceedAuthorizationResult(result, no_dump_login) {
    if (YU2_NOT_FOUND == result) {
      openEulaWnd({
        isForView = false
        onAcceptCallback = Callback(function() {
          this.steamAuthorization("steam")
        }, this),
      })
      return
    }
    if ( result == YU2_OK) {
      if (steam_is_running()) {
        saveLocalSharedSettings(USE_STEAM_LOGIN_AUTO_SETTING_ID, true)
      }
    }
    base.proceedAuthorizationResult(result, no_dump_login)
  }

  function onLoginErrorTryAgain() {
    this.tryLogin()
  }

  function goToLoginWnd(disableAutologin = true) {
    if (disableAutologin)
      set_disable_autorelogin_once(true)
    handlersManager.loadHandler(LoginWndHandler)
  }

  function goBack(_obj) {
    scene_msg_box("steam_question_quit_game",
      this.guiScene,
      loc("mainmenu/questionQuitGame"),
      [
        ["yes", exitGamePlatform],
        ["no", @() null]
      ],
      "no",
      { cancel_fn = @() null }
    )
  }
})
