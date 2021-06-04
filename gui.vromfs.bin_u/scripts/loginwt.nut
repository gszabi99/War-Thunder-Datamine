local statsd = require("statsd")
local penalties = require("scripts/penitentiary/penalties.nut")
local tutorialModule = require("scripts/user/newbieTutorialDisplay.nut")
local contentStateModule = require("scripts/clientState/contentState.nut")
local checkUnlocksByAbTest = require("scripts/unlocks/checkUnlocksByAbTest.nut")
local fxOptions = require("scripts/options/fxOptions.nut")
local { openUrl } = require("scripts/onlineShop/url.nut")
local onMainMenuReturnActions = require("scripts/mainmenu/onMainMenuReturnActions.nut")
local { checkBadWeapons } = require("scripts/weaponry/weaponryInfo.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")
local { startLogout } = require("scripts/login/logout.nut")

::my_user_id_str <- ""
::my_user_id_int64 <- -1
::my_user_name <- ""

::g_script_reloader.registerPersistentData("LoginWTGlobals", ::getroottable(),
  [
    "my_user_id_str", "my_user_id_int64", "my_user_name"
  ])

::g_login.initOptionsPseudoThread <- null
::g_login.shouldRestartPseudoThread <- false
::g_login[PERSISTENT_DATA_PARAMS].append("initOptionsPseudoThread")

::gui_start_startscreen <- function gui_start_startscreen()
{
  ::dagor.debug("target_platform is '" + ::target_platform + "'")
  ::pause_game(false);

  if (::disable_network())
    ::g_login.setState(LOGIN_STATE.AUTHORIZED | LOGIN_STATE.ONLINE_BINARIES_INITED)
  ::g_login.startLoginProcess()
}

::gui_start_after_scripts_reload <- function gui_start_after_scripts_reload()
{
  ::g_login.setState(LOGIN_STATE.AUTHORIZED) //already authorized to char
  ::g_login.startLoginProcess(true)
}

::on_sign_out <- function on_sign_out()  //!!FIX ME: better to full replace this function by SignOut event
{
  if (!("resetChat" in getroottable())) //scripts not loaded
    return

  ::resetChat()
  ::clear_contacts()
  ::SessionLobby.leaveRoom()
  if (::g_battle_tasks)
    ::g_battle_tasks.reset()
  if (::g_recent_items)
    ::g_recent_items.reset()
  ::abandoned_researched_items_for_session = []
}

::go_to_account_web_page <- function go_to_account_web_page(bqKey = "")
{
  local urlBase = ::format("/user.php?skin_lang=%s", ::g_language.getShortName())
  openUrl(::get_authenticated_url_sso(urlBase).url, false, false, bqKey)
}

g_login.loadLoginHandler <- function loadLoginHandler()
{
  local hClass = ::gui_handlers.LoginWndHandler
  if (isPlatformSony)
    hClass = ::gui_handlers.LoginWndHandlerPs4
  else if (::is_platform_xbox)
    hClass = ::gui_handlers.LoginWndHandlerXboxOne
  else if (::use_tencent_login())
    hClass = ::gui_handlers.LoginWndHandlerTencent
  else if (::use_dmm_login())
    hClass = ::gui_handlers.LoginWndHandlerDMM
  else if (::steam_is_running())
    hClass = ::gui_handlers.LoginWndHandlerSteam
  else if (::epic_is_running())
    hClass = ::gui_handlers.LoginWndHandlerEpic
  ::handlersManager.loadHandler(hClass)
}

g_login.onAuthorizeChanged <- function onAuthorizeChanged()
{
  if (!isAuthorized())
  {
    if (::g_login.initOptionsPseudoThread)
      ::g_login.initOptionsPseudoThread.clear()
    ::broadcastEvent("SignOut")
    return
  }

  if (!::disable_network())
    ::handlersManager.animatedSwitchScene(function() {
      ::handlersManager.loadHandler(::gui_handlers.WaitForLoginWnd)
    })
}

g_login.initConfigs <- function initConfigs(cb)
{
  ::broadcastEvent("AuthorizeComplete")
  ::load_scripts_after_login_once()
  ::run_reactive_gui()
  ::my_user_id_str = ::get_player_user_id_str()
  ::my_user_id_int64 = ::my_user_id_str.tointeger()

  initOptionsPseudoThread =  [
    function() { ::initEmptyMenuChat() }
  ]
  initOptionsPseudoThread.extend(::init_options_steps)
  initOptionsPseudoThread.append(
    function() {
      if (!::g_login.hasState(LOGIN_STATE.PROFILE_RECEIVED | LOGIN_STATE.CONFIGS_RECEIVED))
        return PT_STEP_STATUS.SUSPEND

      ::configs.PRICE.checkUpdate()
      ::configs.ENTITLEMENTS_PRICE.checkUpdate()
      return null
    }
    function() {
      contentStateModule.updateConsoleClientDownloadStatus()
      ::get_profile_info() //update ::my_user_name
      ::init_selected_crews(true)
      ::set_show_attachables(::has_feature("AttachablesUse"))

      ::g_font.validateSavedConfigFonts()
      if (::handlersManager.checkPostLoadCss(true))
        dagor.debug("Login: forced to reload waitforLogin window.")
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
      local arr = []
      foreach(unit in ::all_units)
        if(unit.marketplaceItemdefId != null)
          arr.append(unit.marketplaceItemdefId)

      ::ItemsManager.requestItemsByItemdefIds(arr)
    }
    function() {
      ::g_discount.updateDiscountData(true)
    }
    function() {
     ::slotbarPresets.init()
     ::g_chat.onCharConfigsLoaded()
    }
    function() {
      if (::steam_is_running())
        ::steam_process_dlc()

      if (::is_dev_version)
        ::checkShopBlk()

      foreach(c in ::shopCountriesList)
        ::debriefing_countries[c] <- ::get_player_rank_by_country(c)
    }
    function()
    {
      ::unlocked_countries = [] //reinit countries
      ::checkUnlockedCountries()
      ::checkUnlockedCountriesByAirs()

      if (::is_need_first_country_choice())
        ::broadcastEvent("AccountReset")
    }
    function()
    {
      checkUnlocksByAbTest()
    }
    function()
    {
      // FIXME: it is better to get string from NDA text!
      local versions = ["nda_version", "nda_version_tanks", "eula_version"]
      foreach (sver in versions)
      {
        local l = ::loc(sver, "-1")
        try { getroottable()[sver] = l.tointeger() }
        catch(e) { dagor.assertf(0, "can't convert '"+l+"' to version "+sver) }
      }

      ::nda_version = ::has_feature("Tanks") ? ::nda_version_tanks : ::nda_version

      if (should_agree_eula(::nda_version, ::TEXT_NDA))
        ::gui_start_eula(::TEXT_NDA)
      else
      if (should_agree_eula(::eula_version, ::TEXT_EULA))
        ::gui_start_eula(::TEXT_EULA)
    }
    function()
    {
      if (should_agree_eula(::nda_version, ::TEXT_NDA) || should_agree_eula(::eula_version, ::TEXT_EULA))
        return PT_STEP_STATUS.SUSPEND
      return null
    }
    function()
    {
      if (fxOptions.needShowHdrSettingsOnStart())
        fxOptions.openHdrSettings()
    }
    function()
    {
      if (fxOptions.needShowHdrSettingsOnStart())
        return PT_STEP_STATUS.SUSPEND
      return null
    }
    function()
    {
      if (::is_need_first_country_choice())
      {
        ::g_matching_game_modes.forceUpdateGameModes()
        ::gui_start_countryChoice()
        ::gui_handlers.FontChoiceWnd.markSeen()
        tutorialModule.saveVersion()
      }
      else
        tutorialModule.saveVersion(0)
    }
    function()
    {
      if (::is_need_first_country_choice())
        return PT_STEP_STATUS.SUSPEND
      return null
    }
    function()
    {
      ::g_login.initOptionsPseudoThread = null
      cb()
    }
  )

  ::start_pseudo_thread(initOptionsPseudoThread, startLogout)
}

g_login.onEventGuiSceneCleared <- function onEventGuiSceneCleared(p)
{
  //work only after scripts reload
  if (!shouldRestartPseudoThread)
    return
  shouldRestartPseudoThread = false
  if (!initOptionsPseudoThread)
    return

  ::get_cur_gui_scene().performDelayed(::getroottable(),
    function()
    {
      ::handlersManager.loadHandler(::gui_handlers.WaitForLoginWnd)
      ::start_pseudo_thread(::g_login.initOptionsPseudoThread, startLogout)
    })
}

g_login.afterScriptsReload <- function afterScriptsReload()
{
  if (initOptionsPseudoThread)
    shouldRestartPseudoThread = true
}

g_login.onLoggedInChanged <- function onLoggedInChanged()
{
  if (!isLoggedIn())
    return

  statsdOnLogin()
  bigQueryOnLogin()

  ::broadcastEvent("LoginComplete")

  //animatedSwitchScene sync function, so we need correct finish current call
  ::get_cur_gui_scene().performDelayed(::getroottable(), function()
  {
    ::handlersManager.markfullReloadOnSwitchScene()
    ::handlersManager.animatedSwitchScene(function() {
      ::g_login.firstMainMenuLoad()
    })
  })
}

g_login.firstMainMenuLoad <- function firstMainMenuLoad()
{
  local handler = ::gui_start_mainmenu(false)
  if (!handler)
    return //was error on load mainmenu, and was called signout on such error

  ::updateContentPacks()

  handler.doWhenActive(checkAwardsOnStartFrom)
  handler.doWhenActive(@() ::tribunal.checkComplaintCounts())
  handler.doWhenActive(@() ::menu_chat_handler?.checkVoiceChatSuggestion())

  if (!fetch_profile_inited_once())
  {
    if (get_num_real_devices() == 0 && !::is_platform_android)
      setControlTypeByID("ct_mouse")
    else if (::is_platform_shield_tv())
      setControlTypeByID("ct_xinput")
    else
    {
      local onlyDevicesChoice = !::has_feature("Profile")
      handler.doWhenActive(function() { ::gui_start_controls_type_choice(onlyDevicesChoice) })
    }
  }
  else if (!fetch_devices_inited_once())
    handler.doWhenActive(function() { ::gui_start_controls_type_choice() })

  if (::g_login.isProfileReceived() && ::g_controls_presets.isNewerControlsPresetVersionAvailable())
  {
    local patchNoteText = ::g_controls_presets.getPatchNoteTextForCurrentPreset()
    ::scene_msg_box("new_controls_version_msg_box", null,
      ::loc("mainmenu/new_controls_version_msg_box", { patchnote = patchNoteText }),
      [["yes", function () { ::g_controls_presets.setHighestVersionOfCurrentPreset() }],
       ["no", function () { ::g_controls_presets.rejectHighestVersionOfCurrentPreset() }]
      ], "yes", { cancel_fn = function () { ::g_controls_presets.rejectHighestVersionOfCurrentPreset() }})
  }

  if (::show_console_buttons)
  {
    if (::g_login.isProfileReceived() && ::gui_handlers.GampadCursorControlsSplash.shouldDisplay())
      handler.doWhenActive(@() ::gui_handlers.GampadCursorControlsSplash.open())
  }

  if (::has_feature("CheckEmailVerified") && !::g_user_utils.haveTag("email_verified"))
    handler.doWhenActive(function () {
      msgBox(
      "email_not_verified_msg_box",
      ::loc("mainmenu/email_not_verified"),
      [
        ["later", function() {} ],
        ["verify", function() {::go_to_account_web_page("email_verification_popup")}]
      ],
      "later", { cancel_fn = function() {}}
    )})

  if (::has_feature("CheckTwoStepAuth") && !::g_user_utils.haveTag("2step"))
    handler.doWhenActive(function () {
      ::g_popups.add(
        ::loc("mainmenu/two_step_popup_header"),
        ::loc("mainmenu/two_step_popup_text"),
        null,
        [{
          id = "acitvate"
          text = ::loc("msgbox/btn_activate")
          func = function() {::go_to_account_web_page("2step_auth_popup")}
        }]
      )
    })

  ::queues.init()
  ::set_host_cb(null, function(p) { ::SessionLobby.hostCb(p) })

  ::init_coop_flags()

  ::update_gamercards()
  penalties.showBannedStatusMsgBox()

  onMainMenuReturnActions.value?.onMainMenuReturn(handler, true)
}

g_login.statsdOnLogin <- function statsdOnLogin()
{
  statsd.send_counter("sq.game_start.login", 1)

  if (::g_controls_manager.getCurPreset().getBasePresetFileName() == "")
  {
    ::dagor.debug("statsd_on_login customcontrols")
    statsd.send_counter("sq.customcontrols", 1)
  }

  if (isPlatformSony)
  {
    if (!::ps4_is_chat_enabled())
      ::add_big_query_record("ps4.restrictions.chat", "")
    if (!::ps4_is_ugc_enabled())
      ::add_big_query_record("ps4.restrictions.ugc", "")
  }

  if (::is_platform_windows)
  {
    local anyUG = false

    local mis_array = ::get_meta_missions_info(::GM_SINGLE_MISSION)
    foreach (misBlk in mis_array)
      if (::is_user_mission(misBlk))
      {
        statsd.send_counter("sq.ug.goodum", 1)
        anyUG = true
        ::dagor.debug("statsd_on_login ug.goodum " + (misBlk?.name ?? "null"))
        break
      }

    local userSkins = ::get_user_skins_blk()
    local haveUserSkin = false
    for (local i = 0; i < userSkins.blockCount(); i++)
    {
      local air = userSkins.getBlock(i)
      local skins = air % "skin"
      foreach (skin in skins)
      {
        local folder = skin.name
        if (folder.indexof("template") == null)
        {
          haveUserSkin = true
          anyUG = true
          ::dagor.debug("statsd_on_login ug.haveus " + folder + " for " + air.getBlockName())
          break
        }
      }
      if (haveUserSkin)
        break
    }
    if (haveUserSkin)
      statsd.send_counter("sq.ug.haveus", 1)

    local cdb = ::get_user_skins_profile_blk()
    for (local i = 0; i < cdb.paramCount(); i++)
    {
      local skin = cdb.getParamValue(i)
      if ((typeof(skin) == "string") && (skin != "") && (skin.indexof("template")==null))
      {
        anyUG = true
        statsd.send_counter("sq.ug.useus", 1)
        dagor.debug("statsd_on_login ug.useus "+skin)
        break;
      }
    }

    local lcfg = DataBlock()
    ::get_localization_blk_copy(lcfg)
    if (lcfg.locTable != null)
    {
      local files = lcfg.locTable % "file"
      foreach (file in files)
        if (file.indexof("usr_") != null)
        {
          anyUG = true
          ::dagor.debug("statsd_on_login ug.langum " + file)
          statsd.send_counter("sq.ug.langum", 1)
          break
        }
    }

    if (anyUG)
    {
      ::dagor.debug("statsd_on_login ug.any")
      statsd.send_counter("sq.ug.any", 1)
    }
  }
}

::g_login.init()
