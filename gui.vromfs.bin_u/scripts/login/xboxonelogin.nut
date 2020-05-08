local { animBgLoad } = require("scripts/loading/animBg.nut")
local showTitleLogo = require("scripts/viewUtils/showTitleLogo.nut")

local multiplayerSessionPrivelegeCallback = null
local function checkMultiplayerSessionsPrivilegeSq(showMarket, cb)
{
  multiplayerSessionPrivelegeCallback = cb
  ::check_multiplayer_sessions_privilege(showMarket)
}

::check_multiplayer_sessions_privilege_callback <- function check_multiplayer_sessions_privilege_callback(isAllowed)
{
  if (multiplayerSessionPrivelegeCallback)
    multiplayerSessionPrivelegeCallback(isAllowed)
  multiplayerSessionPrivelegeCallback = null
}

class ::gui_handlers.LoginWndHandlerXboxOne extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loginBoxSimple.blk"
  needAutoLogin = false
  isLoginInProcess = false

  function initScreen()
  {
    animBgLoad()
    ::setVersionText(scene)
    ::setProjectAwards(this)
    showTitleLogo(scene, 128)
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)

    local buttonsView = [
      {
        id = "authorization_button"
        text = "#HUD_PRESS_A_CNT"
        shortcut = "A"
        funcName = "onOk"
        delayed = true
        isToBattle = true
        titleButtonFont = true
      },
      {
        id = "change_profile"
        text = "#mainmenu/btnProfileChange"
        shortcut = "Y"
        visualStyle = "secondary"
        funcName = "onChangeGamertag"
      }
    ]

    local data = ""
    foreach (view in buttonsView)
      data += ::handyman.renderCached("gui/commonParts/button", view)

    guiScene.prependWithBlk(scene.findObject("authorization_button_place"), data, this)
    scene.findObject("user_notify_text").setValue(::loc("xbox/reqInstantConnection"))
    updateGamertag()

    if (::xbox_is_game_started_by_invite())
      onOk()
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

    loginStep2_checkMultiplayerPrivelege()
  }

  function loginStep2_checkMultiplayerPrivelege()
  {
    checkMultiplayerSessionsPrivilegeSq(true,
      ::Callback(function(res)
      {
        if (res)
          ::get_gui_scene().performDelayed(this, performLogin)
        else
          isLoginInProcess = false
      }, this))
    //callback check_multiplayer_sessions_privilege_callback
    //will call checkCrossPlay if allowed
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
