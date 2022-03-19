local { animBgLoad } = require("scripts/loading/animBg.nut")
local showTitleLogo = require("scripts/viewUtils/showTitleLogo.nut")
local { setVersionText } = require("scripts/viewUtils/objectTextUpdate.nut")
local { setGuiOptionsMode } = ::require_native("guiOptions")

class ::gui_handlers.LoginWndHandlerXboxOne extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loginBoxSimple.blk"
  needAutoLogin = false
  isLoginInProcess = false

  function initScreen()
  {
    animBgLoad()
    setVersionText(scene)
    ::setProjectAwards(this)
    showTitleLogo(scene, 128)
    setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)

    local buttonsView = [
      {
        id = "authorization_button"
        text = "#HUD_PRESS_A_CNT"
        shortcut = "X"
        funcName = "onOk"
        delayed = true
        isToBattle = true
        titleButtonFont = true
        mousePointerCenteringBelowText = true
      },
      {
        id = "change_profile"
        text = "#mainmenu/btnProfileChange"
        shortcut = "Y"
        visualStyle = "secondary"
        funcName = "onChangeGamertag"
        mousePointerCenteringBelowText = true
      }
    ]

    local data = ""
    foreach (view in buttonsView)
      data += ::handyman.renderCached("gui/commonParts/button", view)

    guiScene.prependWithBlk(scene.findObject("authorization_button_place"), data, this)
    scene.findObject("user_notify_text").setValue(::loc("xbox/reqInstantConnection"))
    updateGamertag()

    if (::xbox_is_game_started_by_invite())
    {
      onOk()
      return
    }

    ::move_mouse_on_obj("authorization_button")
  }

  function onOk()
  {
    if (isLoginInProcess)
      return

    isLoginInProcess = true
    loginStep1_checkGamercard()
  }

  function loginStep1_checkGamercard()
  {
    if (::xbox_get_active_user_gamertag() == "")
    {
      isLoginInProcess = false
      needAutoLogin = true
      onChangeGamertag()
      return
    }

    performLogin()
  }

  function performLogin()
  {
    needAutoLogin = false
    ::xbox_on_login(
      function(result, err_code)
      {
        if (result == XBOX_LOGIN_STATE_SUCCESS)
        {
          ::gui_start_modal_wnd(::gui_handlers.UpdaterModal,
              {
                configPath = "updater.blk"
                onFinishCallback = ::xbox_complete_login
              })
        }
        else if (result == XBOX_LOGIN_STATE_FAILED)
        {
          msgBox("no_internet_connection", ::loc("xbox/noInternetConnection"), [["ok", function() {} ]], "ok")
          isLoginInProcess = false
          ::dagor.logerr($"XBOX: login failed with error - {err_code}")
        }

      }.bindenv(this)
    )
  }

  function onChangeGamertag(obj = null)
  {
    ::xbox_account_picker()
  }

  function updateGamertag()
  {
    local text = ::xbox_get_active_user_gamertag()
    if (text != "")
      text = ::loc("xbox/playAs", {name = text})

    scene.findObject("xbox_active_usertag").setValue(text)
  }

  function onEventXboxActiveUserGamertagChanged(params)
  {
    updateGamertag()
    if (needAutoLogin && ::xbox_get_active_user_gamertag() != "")
      onOk()
  }

  function onEventXboxInviteAccepted(p)
  {
    onOk()
  }

  function goBack(obj) {}
}

//Calling from C++
::xbox_on_gamertag_changed <- @() ::broadcastEvent("XboxActiveUserGamertagChanged")
