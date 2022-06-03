let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
local { setGuiOptionsMode } = ::require_native("guiOptions")

::gui_handlers.LoginWndHandlerXboxOne <- class extends ::BaseGuiHandler
{
  sceneBlkName = "%gui/loginBoxSimple.blk"
  needAutoLogin = false
  isLoginInProcess = false

  function initScreen()
  {
    animBgLoad()
    setVersionText(this.scene)
    ::setProjectAwards(this)
    showTitleLogo(this.scene, 128)
    setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)

    let buttonsView = [
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
      data += ::handyman.renderCached("%gui/commonParts/button", view)

    this.guiScene.prependWithBlk(this.scene.findObject("authorization_button_place"), data, this)
    this.scene.findObject("user_notify_text").setValue(::loc("xbox/reqInstantConnection"))
    this.updateGamertag()

    if (::xbox_is_game_started_by_invite())
    {
      this.onOk()
      return
    }

    ::move_mouse_on_obj("authorization_button")
  }

  function onOk()
  {
    if (this.isLoginInProcess)
      return

    this.isLoginInProcess = true
    this.loginStep1_checkGamercard()
  }

  function loginStep1_checkGamercard()
  {
    if (::xbox_get_active_user_gamertag() == "")
    {
      this.isLoginInProcess = false
      this.needAutoLogin = true
      this.onChangeGamertag()
      return
    }

    this.performLogin()
  }

  function performLogin()
  {
    this.needAutoLogin = false
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
          this.msgBox("no_internet_connection", ::loc("xbox/noInternetConnection"), [["ok", function() {} ]], "ok")
          this.isLoginInProcess = false
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

    this.scene.findObject("xbox_active_usertag").setValue(text)
  }

  function onEventXboxActiveUserGamertagChanged(params)
  {
    this.updateGamertag()
    if (this.needAutoLogin && ::xbox_get_active_user_gamertag() != "")
      this.onOk()
  }

  function onEventXboxInviteAccepted(p)
  {
    this.onOk()
  }

  function goBack(obj) {}
}

//Calling from C++
::xbox_on_gamertag_changed <- @() ::broadcastEvent("XboxActiveUserGamertagChanged")
