from "%scripts/dagui_natives.nut" import ps4_initial_check_network, ps4_load_after_login, ps4_is_production_env, ps4_initial_check_settings, ps4_login
from "%scripts/dagui_library.nut" import *

let { get_disable_autorelogin_once } = require("loginState.nut")
let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { stripTags } = require("%sqstd/string.nut")
let statsd = require("statsd")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { targetPlatform } = require("%scripts/clientState/platform.nut")
let { requestPackageUpdateStatus } = require("sony")
let { setGuiOptionsMode } = require("guiOptions")
let { forceHideCursor } = require("%scripts/controls/mousePointerVisibility.nut")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { loadLocalSharedSettings } = require("%scripts/clientState/localProfile.nut")
let { LOCAL_AGREED_EULA_VERSION_SAVE_ID, openEulaWnd } = require("%scripts/eulaWnd.nut")
let { loadHandler, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { setProjectAwards } = require("%scripts/viewUtils/projectAwards.nut")
let { eventbus_subscribe } = require("eventbus")

eventbus_subscribe("PsnAutologin", function(_p) {
  let loginHandlerPs4 = handlersManager.findHandlerClassInScene(gui_handlers.LoginWndHandlerPs4)
  if (!loginHandlerPs4)
    return
  loginHandlerPs4.onOk()
})

gui_handlers.LoginWndHandlerPs4 <- class (BaseGuiHandler) {
  sceneBlkName = "%gui/loginBoxSimple.blk"
  isLoggingIn = false
  isPendingPackageCheck = false
  isAutologin = false

  function initScreen() {
    this.guiScene.performDelayed(this, function () {
      forceHideCursor.set(true)
    })
    animBgLoad()
    setVersionText(this.scene)
    setProjectAwards(this)
    showTitleLogo(this.scene, 128)
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    let haveAgreedEulaVersion = loadLocalSharedSettings(LOCAL_AGREED_EULA_VERSION_SAVE_ID, 0) > 0
    this.isAutologin = !get_disable_autorelogin_once() && haveAgreedEulaVersion

    let tipHint = stripTags(loc("ON_GAME_ENTER_YOU_APPLY_EULA", { sendShortcuts = "{{INPUT_BUTTON GAMEPAD_START}}"}))
    let hintBlk = "".concat("loadingHint{pos:t='50%(pw-w), 0.5ph-0.5h' position:t='absolute' width:t='2/3sw' behaviour:t='bhvHint' value:t='", tipHint, "'}")

    let data = handyman.renderCached("%gui/commonParts/buttonsList.tpl", {buttons = [{
      id = "authorization_button"
      text = "#HUD_PRESS_A_CNT"
      shortcut = "A"
      funcName = "onOk"
      delayed = true
      visualStyle = "noBgr"
      mousePointerCenteringBelowText = true
      actionParamsMarkup = "bigBoldFont:t='yes'; shadeStyle:t='shadowed'"
      isHidden = this.isAutologin
    },{
      id = "show_eula_button"
      shortcut = "start"
      funcName = "onEulaButton"
      delayed = true
      visualStyle = "noBgr"
      mousePointerCenteringBelowText = true
      actionParamsMarkup = $"bigBoldFont:t='yes'; shadeStyle:t='shadowed'; {hintBlk}"
      showOnSelect = "no"
    }]})

    this.guiScene.prependWithBlk(this.scene.findObject("authorization_button_place"), data, this)
    this.updateButtons(false)

    this.guiScene.performDelayed(this, function() {
      ps4_initial_check_settings()
    })

    if (this.isAutologin)
      this.onOk()
  }

  function updateButtons(isUpdateAvailable = false) {
    showObjById("authorization_button", !this.isAutologin, this.scene)
    let text = "\n".join([isUpdateAvailable ? colorize("warningTextColor", loc("ps4/updateAvailable")) : null,
      loc("ps4/reqInstantConnection")
    ], true)
    this.scene.findObject("user_notify_text").setValue(text)
  }

  function onEulaButton() {
    openEulaWnd()
  }

  function abortLogin(isUpdateAvailable) {
    this.isLoggingIn = false
    this.isAutologin = false
    this.updateButtons(isUpdateAvailable)
  }

  function onPackageUpdateCheckResult(isUpdateAvailable) {
    this.isPendingPackageCheck = false

    local loginStatus = 0
    if (!isUpdateAvailable && ps4_initial_check_network() >= 0) {
      statsd.send_counter("sq.game_start.request_login", 1, { login_type = "ps4" })
      log("PS4 Login: ps4_login")
      this.isLoggingIn = true
      loginStatus = ps4_login();
      if (loginStatus >= 0) {
        forceHideCursor.set(false)
        let cfgName = ps4_is_production_env() ? "updater.blk" : "updater_dev.blk"

        loadHandler(gui_handlers.UpdaterModal,
          {
            configPath = $"/app0/{targetPlatform}/{cfgName}"
            onFinishCallback = ps4_load_after_login
          })
        return
      }
    }

    if (this.isValid())
      this.abortLogin(isUpdateAvailable)
    if (isUpdateAvailable)
      this.msgBox("new_package_available", loc("ps4/updateAvailable"), [["ok", function() {}]], "ok")
    else if (loginStatus == -1)
      this.msgBox("no_internet_connection", loc("ps4/noInternetConnection"), [["ok", function() {} ]], "ok")
  }


  function onOk() {
    if (this.isLoggingIn || this.isPendingPackageCheck)
      return

    this.isPendingPackageCheck = true
    requestPackageUpdateStatus(@(isUpdateAvailable) broadcastEvent("PackageUpdateStatusReceived", { isUpdateAvailable }))
  }

  function onEventPackageUpdateStatusReceived(p) {
    this.onPackageUpdateCheckResult(p.isUpdateAvailable)
  }

  function onDestroy() {
    forceHideCursor.set(false)
  }

  function goBack(_obj) {}
}