local { animBgLoad } = require("scripts/loading/animBg.nut")

class ::gui_handlers.LoginWndHandlerPs4 extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loginBoxSimple.blk"
  isLoggingIn = false

  function initScreen()
  {
    animBgLoad()
    ::setVersionText(scene)
    ::setProjectAwards(this)
    ::show_title_logo(true, scene, "128")
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)

    local data = ::handyman.renderCached("gui/commonParts/button", {
      id = "authorization_button"
      text = "#HUD_PRESS_A_CNT"
      shortcut = "A"
      funcName = "onOk"
      delayed = true
      isToBattle = true
      titleButtonFont = true
    })
    guiScene.prependWithBlk(scene.findObject("authorization_button_place"), data, this)
    scene.findObject("user_notify_text").setValue(::loc("ps4/reqInstantConnection"))

    guiScene.performDelayed(this, function() {
      ::ps4_initial_check_settings()
    })
  }

  function onOk()
  {
    if (isLoggingIn)
      return

    if ((::ps4_initial_check_network() >= 0) && (::ps4_init_trophies() >= 0))
    {
      ::statsd_counter("gameStart.request_login.ps4")
      ::dagor.debug("PS4 Login: ps4_login")
      isLoggingIn = true
      local ret = ::ps4_login();
      if (ret >= 0)
      {
        local isProd = ::ps4_is_production_env()

        ::gui_start_modal_wnd(::gui_handlers.UpdaterModal,
          {
            configPath = isProd ? "/app0/ps4/updater.blk" : "/app0/ps4/updater_dev.blk"
            onFinishCallback = ::ps4_load_after_login
          })
      }
      else
      {
        isLoggingIn = false
        if (ret == -1)
          msgBox("no_internet_connection", ::loc("ps4/noInternetConnection"), [["ok", function() {} ]], "ok")
      }
    }
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
