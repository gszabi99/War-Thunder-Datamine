local statsd = require("statsd")
local { animBgLoad } = require("scripts/loading/animBg.nut")
local showTitleLogo = require("scripts/viewUtils/showTitleLogo.nut")
local { setVersionText } = require("scripts/viewUtils/objectTextUpdate.nut")
local { targetPlatform } = require("scripts/clientState/platform.nut")
local { requestPackageUpdateStatus } = require("sony")
local { setGuiOptionsMode } = ::require_native("guiOptions")

class ::gui_handlers.LoginWndHandlerPs4 extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loginBoxSimple.blk"
  isLoggingIn = false
  isPendingPackageCheck = false
  isAutologin = false

  function initScreen()
  {
    animBgLoad()
    setVersionText(scene)
    ::setProjectAwards(this)
    showTitleLogo(scene, 128)
    setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)

    isAutologin = !(::getroottable()?.disable_autorelogin_once ?? false)

    local data = ::handyman.renderCached("gui/commonParts/button", {
      id = "authorization_button"
      text = "#HUD_PRESS_A_CNT"
      shortcut = "A"
      funcName = "onOk"
      delayed = true
      isToBattle = true
      titleButtonFont = true
      isHidden = isAutologin
    })
    guiScene.prependWithBlk(scene.findObject("authorization_button_place"), data, this)
    updateButtons(false)

    guiScene.performDelayed(this, function() {
      ::ps4_initial_check_settings()
    })

    if (isAutologin)
      ::on_ps4_autologin()
  }

  function updateButtons(isUpdateAvailable = false) {
    showSceneBtn("authorization_button", !isAutologin)
    local text = "\n".join([isUpdateAvailable? ::colorize("warningTextColor", ::loc("ps4/updateAvailable")) : null,
      ::loc("ps4/reqInstantConnection")
    ], true)
    scene.findObject("user_notify_text").setValue(text)
  }

  function abortLogin(isUpdateAvailable)
  {
    isLoggingIn = false
    isAutologin = false
    updateButtons(isUpdateAvailable)
  }

  function onPackageUpdateCheckResult(isUpdateAvailable) {
    isPendingPackageCheck = false

    local loginStatus = 0
    if (!isUpdateAvailable && (::ps4_initial_check_network() >= 0) && (::ps4_init_trophies() >= 0))
    {
      statsd.send_counter("sq.game_start.request_login", 1, {login_type = "ps4"})
      ::dagor.debug("PS4 Login: ps4_login")
      isLoggingIn = true
      loginStatus = ::ps4_login();
      if (loginStatus >= 0)
      {
        local cfgName = ::ps4_is_production_env() ? "updater.blk" : "updater_dev.blk"

        ::gui_start_modal_wnd(::gui_handlers.UpdaterModal,
          {
            configPath = $"/app0/{targetPlatform}/{cfgName}"
            onFinishCallback = ::ps4_load_after_login
          })
        return
      }
    }

    abortLogin(isUpdateAvailable)
    if (isUpdateAvailable)
      msgBox("new_package_available", ::loc("ps4/updateAvailable"), [["ok", function() {}]], "ok")
    else if (loginStatus == -1)
      msgBox("no_internet_connection", ::loc("ps4/noInternetConnection"), [["ok", function() {} ]], "ok")
  }


  function onOk()
  {
    if (isLoggingIn || isPendingPackageCheck)
      return

    isPendingPackageCheck = true
    requestPackageUpdateStatus(onPackageUpdateCheckResult)
  }

  function onEventPs4AutoLoginRequested(p)
  {
    onOk()
  }

  function goBack(obj) {}
}

::on_ps4_autologin <- function on_ps4_autologin()
{
  broadcastEvent("Ps4AutoLoginRequested")
}
