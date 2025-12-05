from "%scripts/dagui_natives.nut" import stat_get_value_respawns, fetch_devices_inited_once,
  set_host_cb, get_num_real_devices, fetch_profile_inited_once
from "app" import pauseGame
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE

let { is_android, platformId, is_gdk } = require("%sqstd/platform.nut")
let { eventbus_subscribe } = require("eventbus")
let { deferOnce } = require("dagor.workcycle")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { showBannedStatusMsgBox } = require("%scripts/penitentiary/bannedStatusMsgBox.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let onMainMenuReturnActions = require("%scripts/mainmenu/onMainMenuReturnActions.nut")
let { isPlatformSteamDeck, is_console, isPlatformShieldTv
} = require("%scripts/clientState/platform.nut")
let { isFirstChoiceShown } = require("%scripts/firstChoice/firstChoice.nut")
let { bqSendNoAuthStart } = require("%scripts/bigQuery/bigQueryClient.nut")
let { get_charserver_time_sec } = require("chard")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { havePlayerTag } = require("%scripts/user/profileStates.nut")
let { getCurLangShortName } = require("%scripts/langUtils/language.nut")
let { isMeNewbie } = require("%scripts/myStats.nut")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { gui_start_controls_type_choice } = require("%scripts/controls/startControls.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { sessionLobbyHostCb } = require("%scripts/matchingRooms/sessionLobbyManager.nut")
let { startLoginProcess } = require("%scripts/login/loginProcess.nut")
let { setLoginState } = require("%scripts/login/loginManager.nut")
let { tribunal } = require("%scripts/penitentiary/tribunal.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")
let { updateContentPacks } = require("%scripts/clientState/contentPacks.nut")
let { setControlTypeByID } = require("%scripts/controls/controlsTypeUtils.nut")
let { disableNetwork } = require("%globalScripts/clientState/initialState.nut")

const EMAIL_VERIFICATION_SEEN_DATE_SETTING_PATH = "emailVerification/lastSeenDate"
let EMAIL_VERIFICATION_INTERVAL_SEC = 7 * 24 * 60 * 60

function gui_start_startscreen(_) {
  bqSendNoAuthStart()

  log($"platformId is '{platformId }'")
  pauseGame(false);

  if (disableNetwork)
    setLoginState(LOGIN_STATE.AUTHORIZED | LOGIN_STATE.ONLINE_BINARIES_INITED)
  startLoginProcess()
}

function gui_start_after_scripts_reload(_) {
  startLoginProcess(true)
}

eventbus_subscribe("gui_start_startscreen", gui_start_startscreen)
eventbus_subscribe("gui_start_after_scripts_reload", gui_start_after_scripts_reload)

function go_to_account_web_page(bqKey = "") {
  let urlBase = getCurCircuitOverride("accountWebPage",
    $"auto_login https://store.gaijin.net/user.php?skin_lang={getCurLangShortName()}")
  openUrl(urlBase, false, false, bqKey)
}

function needAutoStartBattle() {
  if (!isFirstChoiceShown.get()
      || !hasFeature("BattleAutoStart")
      || disableNetwork
      || stat_get_value_respawns(0, 1) > 0
      || !isProfileReceived.get()
      || !loadLocalAccountSettings("needAutoStartBattle", true))
    return false

  saveLocalAccountSettings("needAutoStartBattle", false)
  return true
}

function firstMainMenuLoad() {
  let isAutoStart = needAutoStartBattle()
  local handler = isAutoStart
    ? loadHandler(gui_handlers.AutoStartBattleHandler)
    : gui_start_mainmenu({ allowMainmenuActions = false })

  if (!handler)
    return 

  updateContentPacks()

  handler.doWhenActive(@() ::checkNewNotificationUserlogs(true))
  handler.doWhenActive(@() tribunal.checkComplaintCounts())
  handler.doWhenActive(@() broadcastEvent("ChatCheckVoiceChatSuggestion"))

  if (!fetch_profile_inited_once()) {
    if (get_num_real_devices() == 0 && !is_android)
      setControlTypeByID("ct_mouse")
    else if (isPlatformShieldTv())
      setControlTypeByID("ct_xinput")
    else if (!isPlatformSteamDeck)
      handler.doWhenActive(function() { gui_start_controls_type_choice() })
  }
  else if (!fetch_devices_inited_once() && !isPlatformSteamDeck)
    handler.doWhenActive(function() { gui_start_controls_type_choice() })

  if (showConsoleButtons.get()) {
    if (isProfileReceived.get() && gui_handlers.GampadCursorControlsSplash.shouldDisplay())
      handler.doWhenActive(@() gui_handlers.GampadCursorControlsSplash.open())
  }

  let curTime = get_charserver_time_sec()
  let verificationSeenDate = loadLocalAccountSettings(EMAIL_VERIFICATION_SEEN_DATE_SETTING_PATH, 0)
  if (
    !havePlayerTag("email_verified")
    && !isMeNewbie()
    && !havePlayerTag("steam")
    && !is_console
    && !is_gdk
    && curTime - verificationSeenDate > EMAIL_VERIFICATION_INTERVAL_SEC
  )
    handler.doWhenActive(function () {
      saveLocalAccountSettings(EMAIL_VERIFICATION_SEEN_DATE_SETTING_PATH, curTime)
      this.msgBox(
      "email_not_verified_msg_box",
      loc("mainmenu/email_not_verified"),
      [
        ["later", function() {} ],
        ["verify", function() { go_to_account_web_page("email_verification_popup") }]
      ],
      "later", { cancel_fn = function() {} }
    ) })

  if (hasFeature("CheckTwoStepAuth") && !havePlayerTag("2step"))
    handler.doWhenActive(function () {
      addPopup(
        loc("mainmenu/two_step_popup_header"),
        loc("mainmenu/two_step_popup_text"),
        null,
        [{
          id = "acitvate"
          text = loc("msgbox/btn_activate")
          func = function() { go_to_account_web_page("2step_auth_popup") }
        }]
      )
    })

  set_host_cb(null, function(p) { sessionLobbyHostCb(p) })

  updateGamercards()
  showBannedStatusMsgBox()

  if (isAutoStart)
    handler.doWhenActiveOnce("startBattle")
  else
    onMainMenuReturnActions.get()?.onMainMenuReturn(handler, true)
}


function loadMainMenuDefer() {
  handlersManager.markfullReloadOnSwitchScene()
  handlersManager.animatedSwitchScene(@() firstMainMenuLoad())
}

addListenersWithoutEnv({
  LoginComplete = @(_) deferOnce(loadMainMenuDefer)
})
