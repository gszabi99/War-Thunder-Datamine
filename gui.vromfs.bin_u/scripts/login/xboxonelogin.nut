import "%scripts/viewUtils/showTitleLogo.nut" as showTitleLogo
from "%scripts/login/loginState.nut" import get_disable_autorelogin_once
from "%scripts/sqDagui/framework/baseGuiHandler.nut" import BaseGuiHandler
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/loading/animBg.nut" import animBgLoad
from "%scripts/viewUtils/objectTextUpdate.nut" import setVersionText
from "%scripts/controls/mousePointerVisibility.nut" import forceHideCursor
from "%scripts/gdk/loginState.nut" import login
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY
from "%appGlobals/clientState/localProfile.nut" import loadLocalSharedSettings
from "%scripts/eulaWnd.nut" import LOCAL_AGREED_EULA_VERSION_SAVE_ID, openEulaWnd
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_obj
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/viewUtils/projectAwards.nut" import setProjectAwards
from "%scripts/waitScreen/waitScreen.nut" import showWaitScreen, closeWaitScreen
from "%sqStdLibs/helpers/daguiString.nut" import stripTags
from "guiOptions" import setGuiOptionsMode
from "%gdkLib/impl/user.nut" import get_gamertag
from "%sqstd/platform.nut" import is_xbox
from "%scripts/dagui_natives.nut" import xbox_complete_login
from "%scripts/dagui_library.nut" import *

const AUTOLOGIN_DISABLED = true

register_gui_handler("LoginWndHandlerXboxOne", class (BaseGuiHandler) {
  sceneBlkName = "%gui/loginBoxSimple.blk"
  needAutoLogin = false
  isLoginInProcess = false
  shouldHideCursor = is_xbox

  function initScreen() {
    if (this.shouldHideCursor) {
      this.guiScene.performDelayed(this, function () {
        forceHideCursor.set(true)
      })
    }
    animBgLoad()
    setVersionText(this.scene)
    setProjectAwards(this)
    showTitleLogo(this.scene, 128)
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    let haveAgreedEulaVersion = loadLocalSharedSettings(LOCAL_AGREED_EULA_VERSION_SAVE_ID, 0) > 0
    this.needAutoLogin = !get_disable_autorelogin_once() && haveAgreedEulaVersion && !AUTOLOGIN_DISABLED

    this.scene.findObject("user_notify_text").setValue(loc("xbox/reqInstantConnection"))

    let tipHint = stripTags(loc("ON_GAME_ENTER_YOU_APPLY_EULA", { sendShortcuts = "{{INPUT_BUTTON GAMEPAD_START}}"}))
    let hintBlk = "".concat("loadingHint{pos:t='50%(pw-w), 0.5ph-0.5h' position:t='absolute' width:t='2/3sw' behaviour:t='bhvHint' value:t='", tipHint, "'}")

    local buttons = []

    if (!this.needAutoLogin) {
      buttons.append({
        id = "authorization_button"
        text = "#HUD_PRESS_A_CNT"
        shortcut = "AX"
        funcName = "onOk"
        delayed = true
        visualStyle = "noBgr"
        mousePointerCenteringBelowText = true
        actionParamsMarkup = "bigBoldFont:t='yes'; shadeStyle:t='shadowed'"
      })
    }

    if (is_xbox) {
      buttons.append({
        id = "show_eula_button"
        shortcut = "start"
        funcName = "onEulaButton"
        delayed = true
        visualStyle = "noBgr"
        mousePointerCenteringBelowText = true
        actionParamsMarkup = $"bigBoldFont:t='yes'; shadeStyle:t='shadowed'; {hintBlk}"
        showOnSelect = "no"
      })
    }

    let data = handyman.renderCached("%gui/commonParts/buttonsList.tpl", {buttons})

    this.guiScene.prependWithBlk(this.scene.findObject("authorization_button_place"), data, this)

    if (!this.needAutoLogin)
      move_mouse_on_obj("authorization_button")

    this.updateGamertag()

    log($"Prelogin checks: EULA: {haveAgreedEulaVersion}, DisableAutoLoginOnce: {get_disable_autorelogin_once()}, gamertag: {get_gamertag()}")

    if (this.needAutoLogin && get_gamertag() != "")
      this.onOk()
  }

  function onEulaButton() {
    openEulaWnd()
  }

  function onOk() {
    if (this.isLoginInProcess)
      return

    this.performLogin()
  }

  function loginCallback(errCode) {
    closeWaitScreen()
    if (errCode == 0) { 
      if (this.shouldHideCursor)
        forceHideCursor.set(false)
      loadHandler(get_gui_handler("UpdaterModal"),
        {
          configPath = "updater.blk"
          onFinishCallback = function() {
            log("Login completed")
            xbox_complete_login()
          }
        })
    }
    else {
      this.msgBox("no_internet_connection", loc("xbox/noInternetConnection"), [["ok", function() {} ]], "ok")
      this.isLoginInProcess = false
      logerr($"XBOX: login failed with error - {errCode}")
    }
  }

  function performLogin() {
    this.needAutoLogin = false
    showWaitScreen("msgbox/please_wait")
    login(Callback(@(errCode) this.loginCallback(errCode), this))
  }

  function updateGamertag() {
    this.isLoginInProcess = false
    local text = get_gamertag()
    if (text != "")
      text = loc("xbox/playAs", { name = text })

    this.scene.findObject("xbox_active_usertag").setValue(text)
  }

  function onEventXboxActiveUserGamertagChanged(_params) {
    this.updateGamertag()
    if (this.needAutoLogin && get_gamertag() != "")
      this.onOk()
  }

  function onEventXboxInviteAccepted(_p) {
    this.onOk()
  }

  function onDestroy() {
    if (this.shouldHideCursor)
      forceHideCursor.set(false)
  }

  function goBack(_obj) {}
})
