from "%scripts/dagui_natives.nut" import get_login_pass
from "%scripts/dagui_library.nut" import *
from "%scripts/login/loginConsts.nut" import USE_STEAM_LOGIN_AUTO_SETTING_ID

let { set_disable_autorelogin_once } = require("loginState.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { setGuiOptionsMode } = require("guiOptions")
let { steam_is_running } = require("steam")
let { saveLocalSharedSettings, loadLocalSharedSettings
} = require("%scripts/clientState/localProfile.nut")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { openEulaWnd } = require("%scripts/eulaWnd.nut")

gui_handlers.LoginWndHandlerSteam <- class (gui_handlers.LoginWndHandler) {
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen() {
    animBgLoad()
    setVersionText()
    ::setProjectAwards(this)
    showTitleLogo(this.scene, 128)
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    let lp = get_login_pass()
    this.defaultSaveLoginFlagVal = lp.login != ""
    this.defaultSavePasswordFlagVal = lp.password != ""
    this.defaultSaveAutologinFlagVal = ::is_autologin_enabled()

    //Called init while in loading, so no need to call again authorization.
    //Just wait, when the loading will be over.
    if (::g_login.isAuthorized())
      return

    let useSteamLoginAuto = loadLocalSharedSettings(USE_STEAM_LOGIN_AUTO_SETTING_ID, true)
    if (!useSteamLoginAuto) //can be null or false
      this.goToLoginWnd(useSteamLoginAuto == null)
    else
      this.steamAuthorization("steam-known")

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
    this.goToLoginWnd()
  }

  function goToLoginWnd(disableAutologin = true) {
    if (disableAutologin)
      set_disable_autorelogin_once(true)
    handlersManager.loadHandler(gui_handlers.LoginWndHandler)
  }

  function goBack(_obj) {
    scene_msg_box("steam_question_quit_game",
      this.guiScene,
      loc("mainmenu/questionQuitGame"),
      [
        ["yes", exitGame],
        ["no", @() null]
      ],
      "no",
      { cancel_fn = @() null }
    )
  }
}
