let statsd = require("statsd")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { targetPlatform } = require("%scripts/clientState/platform.nut")
let { requestPackageUpdateStatus } = require("sony")
local { setGuiOptionsMode } = ::require_native("guiOptions")

::gui_handlers.LoginWndHandlerPs4 <- class extends ::BaseGuiHandler
{
  sceneBlkName = "%gui/loginBoxSimple.blk"
  isLoggingIn = false
  isPendingPackageCheck = false
  isAutologin = false

  function initScreen()
  {
    animBgLoad()
    setVersionText(this.scene)
    ::setProjectAwards(this)
    showTitleLogo(this.scene, 128)
    setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)

    this.isAutologin = !(::getroottable()?.disable_autorelogin_once ?? false)

    let data = ::handyman.renderCached("%gui/commonParts/button", {
      id = "authorization_button"
      text = "#HUD_PRESS_A_CNT"
      shortcut = "A"
      funcName = "onOk"
      delayed = true
      isToBattle = true
      titleButtonFont = true
      isHidden = this.isAutologin
    })
    this.guiScene.prependWithBlk(this.scene.findObject("authorization_button_place"), data, this)
    this.updateButtons(false)

    this.guiScene.performDelayed(this, function() {
      ::ps4_initial_check_settings()
    })

    if (this.isAutologin)
      ::on_ps4_autologin()
  }

  function updateButtons(isUpdateAvailable = false) {
    this.showSceneBtn("authorization_button", !this.isAutologin)
    let text = "\n".join([isUpdateAvailable? ::colorize("warningTextColor", ::loc("ps4/updateAvailable")) : null,
      ::loc("ps4/reqInstantConnection")
    ], true)
    this.scene.findObject("user_notify_text").setValue(text)
  }

  function abortLogin(isUpdateAvailable)
  {
    this.isLoggingIn = false
    this.isAutologin = false
    this.updateButtons(isUpdateAvailable)
  }

  function onPackageUpdateCheckResult(isUpdateAvailable) {
    this.isPendingPackageCheck = false

    local loginStatus = 0
    if (!isUpdateAvailable && (::ps4_initial_check_network() >= 0) && (::ps4_init_trophies() >= 0))
    {
      statsd.send_counter("sq.game_start.request_login", 1, {login_type = "ps4"})
      ::dagor.debug("PS4 Login: ps4_login")
      this.isLoggingIn = true
      loginStatus = ::ps4_login();
      if (loginStatus >= 0)
      {
        let cfgName = ::ps4_is_production_env() ? "updater.blk" : "updater_dev.blk"

        ::gui_start_modal_wnd(::gui_handlers.UpdaterModal,
          {
            configPath = $"/app0/{targetPlatform}/{cfgName}"
            onFinishCallback = ::ps4_load_after_login
          })
        return
      }
    }

    if (this.isValid())
      this.abortLogin(isUpdateAvailable)
    if (isUpdateAvailable)
      this.msgBox("new_package_available", ::loc("ps4/updateAvailable"), [["ok", function() {}]], "ok")
    else if (loginStatus == -1)
      this.msgBox("no_internet_connection", ::loc("ps4/noInternetConnection"), [["ok", function() {} ]], "ok")
  }


  function onOk()
  {
    if (this.isLoggingIn || this.isPendingPackageCheck)
      return

    this.isPendingPackageCheck = true
    requestPackageUpdateStatus(this.onPackageUpdateCheckResult)
  }

  function onEventPs4AutoLoginRequested(p)
  {
    this.onOk()
  }

  function goBack(obj) {}
}

::on_ps4_autologin <- function on_ps4_autologin()
{
  ::broadcastEvent("Ps4AutoLoginRequested")
}
