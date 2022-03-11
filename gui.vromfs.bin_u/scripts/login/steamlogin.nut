let { animBgLoad } = require("scripts/loading/animBg.nut")
let showTitleLogo = require("scripts/viewUtils/showTitleLogo.nut")
let { setVersionText } = require("scripts/viewUtils/objectTextUpdate.nut")
let exitGame = require("scripts/utils/exitGame.nut")
let { setGuiOptionsMode } = ::require_native("guiOptions")

::gui_handlers.LoginWndHandlerSteam <- class extends ::gui_handlers.LoginWndHandler
{
  sceneBlkName = "%gui/loginBoxSimple.blk"

  function initScreen()
  {
    animBgLoad()
    setVersionText()
    ::setProjectAwards(this)
    showTitleLogo(scene, 128)
    setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)

    let lp = ::get_login_pass()
    defaultSaveLoginFlagVal = lp.login != ""
    defaultSavePasswordFlagVal = lp.password != ""
    defaultSaveAutologinFlagVal = ::is_autologin_enabled()

    //Called init while in loading, so no need to call again authorization.
    //Just wait, when the loading will be over.
    if (::g_login.isAuthorized())
      return

    let useSteamLoginAuto = ::load_local_shared_settings(USE_STEAM_LOGIN_AUTO_SETTING_ID)
    if (!::has_feature("AllowSteamAccountLinking"))
    {
      if (!useSteamLoginAuto) //can be null or false
        goToLoginWnd(useSteamLoginAuto == null)
      else
        authorizeSteam()
      return
    }

    if (useSteamLoginAuto == true)
    {
      authorizeSteam("steam-known")
      return
    }
    else if (useSteamLoginAuto == false)
    {
      goToLoginWnd(false)
      return
    }

    showSceneBtn("button_exit", true)
    showLoginProposal()
  }

  function showLoginProposal()
  {
    ::scene_msg_box("steam_link_method_question",
      guiScene,
      ::loc("steam/login/linkQuestion" + (::has_feature("AllowSteamAccountLinking")? "" : "/noLink")),
      [["#mainmenu/loginWithGaijin", ::Callback(goToLoginWnd, this) ],
       ["#mainmenu/loginWithSteam", ::Callback(authorizeSteam, this)],
       ["exit", exitGame]
      ],
      "#mainmenu/loginWithGaijin"
    )
  }

  function proceedAuthorizationResult(result, no_dump_login)
  {
    switch(result)
    {
      case ::YU2_NOT_FOUND:
        goToLoginWnd()
        break
      case ::YU2_OK:
        if (::steam_is_running() && !::has_feature("AllowSteamAccountLinking"))
          ::save_local_shared_settings(USE_STEAM_LOGIN_AUTO_SETTING_ID, true)
          // no break!
      default:  // warning disable: -missed-break
        base.proceedAuthorizationResult(result, no_dump_login)
    }
  }

  function onLoginErrorTryAgain()
  {
    showLoginProposal()
  }

  function authorizeSteam(steamKey = "steam")
  {
    onSteamAuthorization(steamKey)
  }

  function goToLoginWnd(disableAutologin = true)
  {
    if (disableAutologin)
      ::disable_autorelogin_once <- true
    ::handlersManager.loadHandler(::gui_handlers.LoginWndHandler)
  }

  function goBack(obj)
  {
    ::scene_msg_box("steam_question_quit_game",
      guiScene,
      ::loc("mainmenu/questionQuitGame"),
      [
        ["yes", exitGame],
        ["no", @() null]
      ],
      "no",
      { cancel_fn = @() null}
    )
  }
}
