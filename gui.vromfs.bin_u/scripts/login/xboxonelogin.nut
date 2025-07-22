from "%scripts/dagui_natives.nut" import xbox_complete_login
from "%scripts/dagui_library.nut" import *

let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { stripTags } = require("%sqstd/string.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { setGuiOptionsMode } = require("guiOptions")
let { forceHideCursor } = require("%scripts/controls/mousePointerVisibility.nut")
let { get_gamertag } = require("%gdkLib/impl/user.nut")
let { init_with_ui } = require("%scripts/gdk/user.nut")
let { login } = require("%scripts/gdk/loginState.nut")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { openEulaWnd } = require("%scripts/eulaWnd.nut")
let { move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { setProjectAwards } = require("%scripts/viewUtils/projectAwards.nut")
let { showWaitScreen, closeWaitScreen } = require("%scripts/waitScreen/waitScreen.nut")
let { is_xbox } = require("%sqstd/platform.nut")


gui_handlers.LoginWndHandlerXboxOne <- class (BaseGuiHandler) {
  sceneBlkName = "%gui/loginBoxSimple.blk"
  needAutoLogin = false
  isLoginInProcess = false
  shouldHideCursor = is_platform_xbox

  function initScreen() {
    if (this.shouldHideCursor) {
      this.guiScene.performDelayed(this, function () {
        forceHideCursor(true)
      })
    }
    animBgLoad()
    setVersionText(this.scene)
    setProjectAwards(this)
    showTitleLogo(this.scene, 128)
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    this.scene.findObject("user_notify_text").setValue(loc("xbox/reqInstantConnection"))

    let tipHint = stripTags(loc("ON_GAME_ENTER_YOU_APPLY_EULA", { sendShortcuts = "{{INPUT_BUTTON GAMEPAD_START}}"}))
    let hintBlk = "".concat("loadingHint{pos:t='50%(pw-w), 0.5ph-0.5h' position:t='absolute' width:t='2/3sw' behaviour:t='bhvHint' value:t='", tipHint, "'}")

    local buttons = [{
      id = "authorization_button"
      text = "#HUD_PRESS_A_CNT"
      shortcut = "AX"
      funcName = "onOk"
      delayed = true
      visualStyle = "noBgr"
      mousePointerCenteringBelowText = true
      actionParamsMarkup = "bigBoldFont:t='yes'; shadeStyle:t='shadowed'"
    },
    {
      id = "change_profile"
      text = "#mainmenu/btnProfileChange"
      shortcut = "Y"
      visualStyle = "noBgr"
      funcName = "onChangeGamertag"
      mousePointerCenteringBelowText = true
      actionParamsMarkup = "shadeStyle:t='shadowed'"
    }]

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
    this.updateGamertag()

    move_mouse_on_obj("authorization_button")
  }

  function onEulaButton() {
    openEulaWnd()
  }

  function onOk() {
    if (this.isLoginInProcess)
      return

    this.isLoginInProcess = true
    if (get_gamertag() == "") {
      this.needAutoLogin = true
      this.onChangeGamertag()
      return
    }

    this.performLogin()
  }

  function loginCallback(errCode) {
    closeWaitScreen()
    if (errCode == 0) { 
      if (this.shouldHideCursor)
        forceHideCursor(false)
      loadHandler(gui_handlers.UpdaterModal,
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

  function onChangeGamertag(_obj = null) {
    init_with_ui(null)
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
      forceHideCursor(false)
  }

  function goBack(_obj) {}
}
