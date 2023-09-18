//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let statsd = require("statsd")
let DataBlock = require("DataBlock")
let { get_authenticated_url_sso } = require("url")
let { registerPersistentData, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let penalties = require("%scripts/penitentiary/penalties.nut")
let tutorialModule = require("%scripts/user/newbieTutorialDisplay.nut")
let contentStateModule = require("%scripts/clientState/contentState.nut")
let checkUnlocksByAbTest = require("%scripts/unlocks/checkUnlocksByAbTest.nut")
let fxOptions = require("%scripts/options/fxOptions.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let onMainMenuReturnActions = require("%scripts/mainmenu/onMainMenuReturnActions.nut")
let { checkBadWeapons } = require("%scripts/weaponry/weaponryInfo.nut")
let { isPlatformSony, isPlatformSteamDeck, is_console, isPlatformShieldTv, isPlatformXboxOne
} = require("%scripts/clientState/platform.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { updatePlayerRankByCountries } = require("%scripts/ranks.nut")
let { PT_STEP_STATUS, startPseudoThread } = require("%scripts/utils/pseudoThread.nut")
let { PRICE, ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let { isNeedFirstCountryChoice,
  isFirstChoiceShown } = require("%scripts/firstChoice/firstChoice.nut")
let { havePlayerTag } = require("%scripts/user/userUtils.nut")
let { bqSendStart }    = require("%scripts/bigQuery/bigQueryClient.nut")
let { get_meta_missions_info } = require("guiMission")
let { forceUpdateGameModes } = require("%scripts/matching/matchingGameModes.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { disableMarkSeenAllResourcesForNewUser } = require("%scripts/seen/markSeenResources.nut")
let { resetBattleTasks } = require("%scripts/unlocks/battleTasks.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_charserver_time_sec } = require("chard")
let { LOCAL_AGREED_EULA_VERSION_SAVE_ID, getEulaVersion, openEulaWnd } = require("%scripts/eulaWnd.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { saveLocalSharedSettings, loadLocalSharedSettings, saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { shouldAgreeEula, getAgreedEulaVersion, setAgreedEulaVersion } = require("sqEulaUtils")
let { get_user_skins_blk, get_user_skins_profile_blk } = require("blkGetters")
let { is_running } = require("steam")

const EMAIL_VERIFICATION_SEEN_DATE_SETTING_PATH = "emailVerification/lastSeenDate"
let EMAIL_VERIFICATION_INTERVAL_SEC = 7 * 24 * 60 * 60

::my_user_id_str <- ""
::my_user_id_int64 <- -1
::my_user_name <- ""

registerPersistentData("LoginWTGlobals", getroottable(),
  [
    "my_user_id_str", "my_user_id_int64", "my_user_name"
  ])

::g_login.initOptionsPseudoThread <- null
::g_login.shouldRestartPseudoThread <- false
::g_login[PERSISTENT_DATA_PARAMS].append("initOptionsPseudoThread")

::gui_start_startscreen <- function gui_start_startscreen() {
  bqSendStart()

  log($"platformId is '{platformId }'")
  ::pause_game(false);

  if (::disable_network())
    ::g_login.setState(LOGIN_STATE.AUTHORIZED | LOGIN_STATE.ONLINE_BINARIES_INITED)
  ::g_login.startLoginProcess()
}

::gui_start_after_scripts_reload <- function gui_start_after_scripts_reload() {
  ::g_login.setState(LOGIN_STATE.AUTHORIZED) //already authorized to char
  ::g_login.startLoginProcess(true)
}

::on_sign_out <- function on_sign_out() {  //!!FIX ME: better to full replace this function by SignOut event
  if (!("resetChat" in getroottable())) //scripts not loaded
    return

  ::resetChat()
  ::SessionLobby.leaveRoom()
  if (::g_battle_tasks)
    resetBattleTasks()
  if (::g_recent_items)
    ::g_recent_items.reset()
  ::abandoned_researched_items_for_session = []
}

let function go_to_account_web_page(bqKey = "") {
  let urlBase = format("https://store.gaijin.net/user.php?skin_lang=%s", ::g_language.getShortName())
  openUrl(get_authenticated_url_sso(urlBase, "any").url, false, true, bqKey)
}

::g_login.loadLoginHandler <- function loadLoginHandler() {
  local hClass = gui_handlers.LoginWndHandler
  if (isPlatformSony)
    hClass = gui_handlers.LoginWndHandlerPs4
  else if (is_platform_xbox)
    hClass = gui_handlers.LoginWndHandlerXboxOne
  else if (::use_dmm_login())
    hClass = gui_handlers.LoginWndHandlerDMM
  else if (::steam_is_running())
    hClass = gui_handlers.LoginWndHandlerSteam
  else if (::epic_is_running())
    hClass = gui_handlers.LoginWndHandlerEpic
  handlersManager.loadHandler(hClass)
}

::g_login.onAuthorizeChanged <- function onAuthorizeChanged() {
  if (!this.isAuthorized()) {
    if (::g_login.initOptionsPseudoThread)
      ::g_login.initOptionsPseudoThread.clear()
    broadcastEvent("SignOut")
    return
  }

  if (!::disable_network())
    handlersManager.animatedSwitchScene(function() {
      handlersManager.loadHandler(gui_handlers.WaitForLoginWnd)
    })
}

::g_login.initConfigs <- function initConfigs(cb) {
  broadcastEvent("AuthorizeComplete")
  ::load_scripts_after_login_once()
  ::run_reactive_gui()
  ::my_user_id_str = ::get_player_user_id_str()
  ::my_user_id_int64 = ::my_user_id_str.tointeger()

  this.initOptionsPseudoThread =  [
    function() { ::initEmptyMenuChat() }
  ]
  this.initOptionsPseudoThread.extend(::init_options_steps)
  this.initOptionsPseudoThread.append(
    function() {
      if (!::g_login.hasState(LOGIN_STATE.PROFILE_RECEIVED | LOGIN_STATE.CONFIGS_RECEIVED))
        return PT_STEP_STATUS.SUSPEND

      PRICE.checkUpdate()
      ENTITLEMENTS_PRICE.checkUpdate()
      return null
    }
    function() {
      contentStateModule.updateConsoleClientDownloadStatus()
      ::get_profile_info() //update ::my_user_name
      ::init_selected_crews(true)
      ::set_show_attachables(hasFeature("AttachablesUse"))

      ::g_font.validateSavedConfigFonts()
      if (handlersManager.checkPostLoadCss(true))
        log("Login: forced to reload waitforLogin window.")
      return null
    }
    function() {
      if (!::g_login.hasState(LOGIN_STATE.MATCHING_CONNECTED))
        return PT_STEP_STATUS.SUSPEND

      ::shown_userlog_notifications.clear()
      ::collectOldNotifications()
      checkBadWeapons()
      return null
    }
    function() {
      ::ItemsManager.collectUserlogItemdefs()
      let arr = []
      foreach (unit in getAllUnits())
        if (unit.marketplaceItemdefId != null)
          arr.append(unit.marketplaceItemdefId)

      ::ItemsManager.requestItemsByItemdefIds(arr)
    }
    function() {
      ::g_discount.updateDiscountData(true)
    }
    function() {
     ::slotbarPresets.init()
    }
    function() {
      if (::steam_is_running())
        ::steam_process_dlc()

      if (::is_dev_version)
        ::checkShopBlk()

      updatePlayerRankByCountries()
    }
    function() {
      ::unlocked_countries = [] //reinit countries
      ::checkUnlockedCountries()
      ::checkUnlockedCountriesByAirs()

      if (isNeedFirstCountryChoice())
        broadcastEvent("AccountReset")
    }
    function() {
      checkUnlocksByAbTest()
    }
    function() {
      let currentEulaVersion = getEulaVersion()
      let agreedEulaVersion = getAgreedEulaVersion(::TEXT_EULA)
      let localAgreedEulaVersion = loadLocalSharedSettings(LOCAL_AGREED_EULA_VERSION_SAVE_ID, 0)

      if (agreedEulaVersion >= currentEulaVersion) {
        if (localAgreedEulaVersion < currentEulaVersion)
          saveLocalSharedSettings(LOCAL_AGREED_EULA_VERSION_SAVE_ID, currentEulaVersion)
      } else {
        if ((isPlatformSony || isPlatformXboxOne || is_running())
          && (agreedEulaVersion == 0 || localAgreedEulaVersion >= currentEulaVersion)) {
          setAgreedEulaVersion(currentEulaVersion, ::TEXT_EULA)
          sendBqEvent("CLIENT_GAMEPLAY_1", "eula_screen", "accept")
        } else {
          openEulaWnd({isNewEulaVersion = localAgreedEulaVersion > 0})
        }
      }
    }
    function() {
      let currentEulaVersion = getEulaVersion()
      if (shouldAgreeEula(currentEulaVersion, ::TEXT_EULA))
        return PT_STEP_STATUS.SUSPEND
      return null
    }
    function() {
      if (fxOptions.needShowHdrSettingsOnStart())
        fxOptions.openHdrSettings()
    }
    function() {
      if (fxOptions.needShowHdrSettingsOnStart())
        return PT_STEP_STATUS.SUSPEND
      return null
    }
    function() {
      if (isNeedFirstCountryChoice()) {
        disableMarkSeenAllResourcesForNewUser()
        forceUpdateGameModes()
        ::gui_start_countryChoice()
        gui_handlers.FontChoiceWnd.markSeen()
        tutorialModule.saveVersion()

        if(havePlayerTag("steamlogin"))
          saveLocalAccountSettings("disabledReloginSteamAccount", true)
      }
      else
        tutorialModule.saveVersion(0)
    }
    function() {
      if (isNeedFirstCountryChoice())
        return PT_STEP_STATUS.SUSPEND
      return null
    }
    function() {
      ::g_login.initOptionsPseudoThread = null
      cb()
    }
  )

  startPseudoThread(this.initOptionsPseudoThread, startLogout)
}

::g_login.onEventGuiSceneCleared <- function onEventGuiSceneCleared(_p) {
  //work only after scripts reload
  if (!this.shouldRestartPseudoThread)
    return
  this.shouldRestartPseudoThread = false
  if (!this.initOptionsPseudoThread)
    return

  get_cur_gui_scene().performDelayed(getroottable(),
    function() {
      handlersManager.loadHandler(gui_handlers.WaitForLoginWnd)
      startPseudoThread(::g_login.initOptionsPseudoThread, startLogout)
    })
}

::g_login.afterScriptsReload <- function afterScriptsReload() {
  if (this.initOptionsPseudoThread)
    this.shouldRestartPseudoThread = true
}

::g_login.onLoggedInChanged <- function onLoggedInChanged() {
  if (!this.isLoggedIn())
    return

  this.statsdOnLogin()
  this.bigQueryOnLogin()

  broadcastEvent("LoginComplete")

  //animatedSwitchScene sync function, so we need correct finish current call
  get_cur_gui_scene().performDelayed(getroottable(), function() {
    handlersManager.markfullReloadOnSwitchScene()
    handlersManager.animatedSwitchScene(function() {
      ::g_login.firstMainMenuLoad()
    })
  })
}

let function needAutoStartBattle() {
  if (!isFirstChoiceShown.value
      || !hasFeature("BattleAutoStart")
      || ::disable_network()
      || ::stat_get_value_respawns(0, 1) > 0
      || !::g_login.isProfileReceived()
      || !loadLocalAccountSettings("needAutoStartBattle", true))
    return false

  saveLocalAccountSettings("needAutoStartBattle", false)
  return true
}

::g_login.firstMainMenuLoad <- function firstMainMenuLoad() {
  let isAutoStart = needAutoStartBattle()
  let handler = isAutoStart
    ? handlersManager.loadHandler(gui_handlers.AutoStartBattleHandler)
    : ::gui_start_mainmenu(false)

  if (!handler)
    return //was error on load mainmenu, and was called signout on such error

  ::updateContentPacks()

  handler.doWhenActive(::checkAwardsOnStartFrom)
  handler.doWhenActive(@() ::tribunal.checkComplaintCounts())
  handler.doWhenActive(@() ::menu_chat_handler?.checkVoiceChatSuggestion())

  if (!::fetch_profile_inited_once()) {
    if (::get_num_real_devices() == 0 && !is_platform_android)
      ::setControlTypeByID("ct_mouse")
    else if (isPlatformShieldTv())
      ::setControlTypeByID("ct_xinput")
    else if (!isPlatformSteamDeck)
      handler.doWhenActive(function() { ::gui_start_controls_type_choice(false) })
  }
  else if (!::fetch_devices_inited_once() && !isPlatformSteamDeck)
    handler.doWhenActive(function() { ::gui_start_controls_type_choice() })

  if (showConsoleButtons.value) {
    if (::g_login.isProfileReceived() && gui_handlers.GampadCursorControlsSplash.shouldDisplay())
      handler.doWhenActive(@() gui_handlers.GampadCursorControlsSplash.open())
  }

  let curTime = get_charserver_time_sec()
  let verificationSeenDate = loadLocalAccountSettings(EMAIL_VERIFICATION_SEEN_DATE_SETTING_PATH, 0)
  if (
    !havePlayerTag("email_verified")
    && !::is_me_newbie()
    && !havePlayerTag("steam")
    && !is_console
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
      ::g_popups.add(
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

  ::queues.init()
  ::set_host_cb(null, function(p) { ::SessionLobby.hostCb(p) })

  ::init_coop_flags()

  ::update_gamercards()
  penalties.showBannedStatusMsgBox()

  if (isAutoStart)
    handler.doWhenActiveOnce("startBattle")
  else
    onMainMenuReturnActions.value?.onMainMenuReturn(handler, true)
}

::g_login.statsdOnLogin <- function statsdOnLogin() {
  statsd.send_counter("sq.game_start.login", 1)

  if (isPlatformSony) {
    if (!::ps4_is_chat_enabled())
      sendBqEvent("CLIENT_GAMEPLAY_1", "ps4.restrictions.chat", {})
    if (!::ps4_is_ugc_enabled())
      sendBqEvent("CLIENT_GAMEPLAY_1", "ps4.restrictions.ugc", {})
  }

  if (is_platform_windows) {
    local anyUG = false

    let mis_array = get_meta_missions_info(GM_SINGLE_MISSION)
    foreach (misBlk in mis_array)
      if (::is_user_mission(misBlk)) {
        statsd.send_counter("sq.ug.goodum", 1)
        anyUG = true
        log("statsd_on_login ug.goodum " + (misBlk?.name ?? "null"))
        break
      }

    let userSkins = get_user_skins_blk()
    local haveUserSkin = false
    for (local i = 0; i < userSkins.blockCount(); i++) {
      let air = userSkins.getBlock(i)
      let skins = air % "skin"
      foreach (skin in skins) {
        let folder = skin.name
        if (folder.indexof("template") == null) {
          haveUserSkin = true
          anyUG = true
          log("statsd_on_login ug.haveus " + folder + " for " + air.getBlockName())
          break
        }
      }
      if (haveUserSkin)
        break
    }
    if (haveUserSkin)
      statsd.send_counter("sq.ug.haveus", 1)

    let cdb = get_user_skins_profile_blk()
    for (local i = 0; i < cdb.paramCount(); i++) {
      let skin = cdb.getParamValue(i)
      if ((type(skin) == "string") && (skin != "") && (skin.indexof("template") == null)) {
        anyUG = true
        statsd.send_counter("sq.ug.useus", 1)
        log("statsd_on_login ug.useus " + skin)
        break;
      }
    }

    let lcfg = DataBlock()
    ::get_localization_blk_copy(lcfg)
    if (lcfg.locTable != null) {
      let files = lcfg.locTable % "file"
      foreach (file in files)
        if (file.indexof("usr_") != null) {
          anyUG = true
          log("statsd_on_login ug.langum " + file)
          statsd.send_counter("sq.ug.langum", 1)
          break
        }
    }

    if (anyUG) {
      log("statsd_on_login ug.any")
      statsd.send_counter("sq.ug.any", 1)
    }
  }
}

::g_login.init()
