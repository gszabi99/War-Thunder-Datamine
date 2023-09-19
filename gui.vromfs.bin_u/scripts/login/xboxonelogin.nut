//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { stripTags } = require("%sqstd/string.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { setGuiOptionsMode } = require("guiOptions")
let { forceHideCursor } = require("%scripts/controls/mousePointerVisibility.nut")
let { get_gamertag } = require("%xboxLib/impl/user.nut")
let { init_with_ui } = require("%xboxLib/user.nut")
let { login } = require("%scripts/xbox/auth.nut")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { openEulaWnd } = require("%scripts/eulaWnd.nut")

gui_handlers.LoginWndHandlerXboxOne <- class extends ::BaseGuiHandler {
  sceneBlkName = "%gui/loginBoxSimple.blk"
  needAutoLogin = false
  isLoginInProcess = false

  function initScreen() {
    this.guiScene.performDelayed(this, function () {
      forceHideCursor(true)
    })
    animBgLoad()
    setVersionText(this.scene)
    ::setProjectAwards(this)
    showTitleLogo(this.scene, 128)
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    this.scene.findObject("user_notify_text").setValue(loc("xbox/reqInstantConnection"))

    let tipHint = stripTags(loc("ON_GAME_ENTER_YOU_APPLY_EULA", { sendShortcuts = "{{INPUT_BUTTON GAMEPAD_START}}"}))
    let hintBlk = "".concat("loadingHint{pos:t='50%(pw-w), 0.5ph-0.5h' position:t='absolute' width:t='2/3sw' behaviour:t='bhvHint' value:t='", tipHint, "'}")

    let data = handyman.renderCached("%gui/commonParts/buttonsList.tpl", {buttons = [{
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
    this.updateGamertag()

    ::move_mouse_on_obj("authorization_button")
  }

  function onEulaButton() {
    openEulaWnd()
  }

  function onOk() {
    if (this.isLoginInProcess)
      return

    this.isLoginInProcess = true
    this.loginStep1_checkGamercard()
  }

  function loginStep1_checkGamercard() {
    if (get_gamertag() == "") {
      this.isLoginInProcess = false
      this.needAutoLogin = true
      this.onChangeGamertag()
      return
    }

    this.performLogin()
  }

  function performLogin() {
    this.needAutoLogin = false
    ::show_wait_screen("msgbox/please_wait")
    login(
      function(err_code) {
        ::close_wait_screen()
        if (err_code == 0) { // YU2_OK
          forceHideCursor(false)
          ::gui_start_modal_wnd(gui_handlers.UpdaterModal,
              {
                configPath = "updater.blk"
                onFinishCallback = ::xbox_complete_login
              })
        }
        else {
          this.msgBox("no_internet_connection", loc("xbox/noInternetConnection"), [["ok", function() {} ]], "ok")
          this.isLoginInProcess = false
          logerr($"XBOX: login failed with error - {err_code}")
        }
      }.bindenv(this)
    )
  }

  function onChangeGamertag(_obj = null) {
    init_with_ui(null)
  }

  function updateGamertag() {
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
    forceHideCursor(false)
  }

  function goBack(_obj) {}
}
