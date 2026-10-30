import "%scripts/mainmenu/onMainMenuReturnActions.nut" as onMainMenuReturnActions
from "%scripts/mainmenu/autoStartBattleHandler.nut" import AutoStartBattleHandler
from "%scripts/login/waitForLoginWnd.nut" import WaitForLoginWnd
from "%scripts/controls/gamepadCursorControlsSplash.nut" import GampadCursorControlsSplash
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/penitentiary/bannedStatusMsgBox.nut" import showBannedStatusMsgBox
from "%scripts/onlineShop/url.nut" import openUrl
from "%sqstd/platform.nut" import is_android, platformId, is_gdk, is_steam_deck, is_console
from "%appGlobals/clientState/platform.nut" import isPlatformShieldTv
from "%scripts/firstChoice/firstChoice.nut" import isFirstChoiceShown
from "%scripts/bigQuery/bigQueryClient.nut" import bqSendNoAuthStart
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/langUtils/language.nut" import getCurLangShortName
from "%scripts/myStats.nut" import isMeNewbie, isNewbieInited
from "%scripts/mainmenu/guiStartMainmenu.nut" import gui_start_mainmenu
from "%scripts/controls/startControls.nut" import gui_start_controls_type_choice
from "%scripts/popups/popups.nut" import addPopup
from "%scripts/matchingRooms/sessionLobbyManager.nut" import sessionLobbyHostCb
from "%scripts/login/loginProcess.nut" import startLoginProcess
from "%scripts/login/loginManager.nut" import setLoginState
from "%scripts/gamercard/gamercard.nut" import updateGamercards
from "%scripts/clientState/contentPacks.nut" import updateContentPacks
from "%scripts/controls/controlsTypeUtils.nut" import setControlTypeByID
from "%scripts/clientState/clientStates.nut" import getFromSettingsBlk
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "%appGlobals/login/loginState.nut" import isProfileReceived, isAuthorized, isLoggedIn, hasFullLoginState
from "%globalScripts/clientState/initialState.nut" import disableNetwork
from "eventbus" import eventbus_subscribe
from "dagor.workcycle" import deferOnce
from "chard" import get_charserver_time_sec
from "%scripts/dagui_natives.nut" import stat_get_value_respawns, fetch_devices_inited_once, set_host_cb, get_num_real_devices, fetch_profile_inited_once
from "app" import pauseGame
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE
from "%scripts/user/profileStates.nut" import havePlayerTag, haveAnyPlayerTag

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { tribunal } = require("%scripts/penitentiary/tribunal.nut")

const EMAIL_VERIFICATION_SEEN_DATE_SETTING_PATH = "emailVerification/lastSeenDate"
const EMAIL_VERIFICATION_INTERVAL_SEC = 7 * 24 * 60 * 60

function gui_start_startscreen(_) {
  bqSendNoAuthStart()

  log($"platformId is '{platformId }'")
  pauseGame(false);

  if (disableNetwork)
    setLoginState(LOGIN_STATE.AUTHORIZED)
  startLoginProcess()
}

eventbus_subscribe("gui_start_startscreen", gui_start_startscreen)
eventbus_subscribe("gui_start_after_scripts_reload", function(_) {
  if (!disableNetwork && isAuthorized.get() && !hasFullLoginState.get())
    loadHandler(WaitForLoginWnd)
})

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

let setHostCb = @() set_host_cb(null, sessionLobbyHostCb)

function firstMainMenuLoad() {
  let isAutoStart = needAutoStartBattle()
  local handler = isAutoStart
    ? loadHandler(AutoStartBattleHandler)
    : gui_start_mainmenu({ allowMainmenuActions = false })

  if (!handler)
    return 

  updateContentPacks()

  handler.doWhenActive(@() broadcastEvent("FirstMainMenuLoaded"))
  handler.doWhenActive(@() tribunal.checkComplaintCounts())

  if (!fetch_profile_inited_once()) {
    if (get_num_real_devices() == 0 && !is_android)
      setControlTypeByID("ct_mouse")
    else if (isPlatformShieldTv())
      setControlTypeByID("ct_xinput")
    else if (!is_steam_deck)
      handler.doWhenActive(function() { gui_start_controls_type_choice() })
  }
  else if (!fetch_devices_inited_once() && !is_steam_deck)
    handler.doWhenActive(function() { gui_start_controls_type_choice() })

  if (showConsoleButtons.get()) {
    if (isProfileReceived.get() && GampadCursorControlsSplash.shouldDisplay())
      handler.doWhenActive(@() GampadCursorControlsSplash.open())
  }

  let curTime = get_charserver_time_sec()
  let verificationSeenDate = loadLocalAccountSettings(EMAIL_VERIFICATION_SEEN_DATE_SETTING_PATH, 0)
  let skipPopups = getFromSettingsBlk("debug/skipPopups", false)
  if (
    !haveAnyPlayerTag(["email_verified", "guestlogin", "steam", "xbone", "ps4"])
    && isNewbieInited() && !isMeNewbie()
    && !is_console
    && !is_gdk
    && curTime - verificationSeenDate > EMAIL_VERIFICATION_INTERVAL_SEC
    && !skipPopups
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

  if (hasFeature("CheckTwoStepAuth") && !havePlayerTag("2step") && !skipPopups)
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

  setHostCb()

  updateGamercards()
  showBannedStatusMsgBox()

  if (isAutoStart)
    handler.doWhenActiveOnce("startBattle")
  else
    onMainMenuReturnActions.get()?.onMainMenuReturn(handler, true)
}


function loadMainMenuDefer() {
  handlersManager.markfullReloadOnSwitchScene()
  handlersManager.animatedSwitchScene(firstMainMenuLoad)
}

addListenersWithoutEnv({
  LoginComplete = @(_) deferOnce(loadMainMenuDefer)
})


if (isLoggedIn.get())
  setHostCb()
