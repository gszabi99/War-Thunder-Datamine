let { format } = require("string")
let onMainMenuReturnActions = require("%scripts/mainmenu/onMainMenuReturnActions.nut")

let time = require("%scripts/time.nut")
let penalties = require("%scripts/penitentiary/penalties.nut")
let itemNotifications = require("%scripts/items/itemNotifications.nut")
let { checkGaijinPassReminder } = require("%scripts/mainmenu/reminderGaijinPass.nut")
let { systemOptionsMaintain } = require("%scripts/options/systemOptions.nut")
let { checkJoystickThustmasterHotas } = require("%scripts/controls/hotas.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { showViralAcquisitionWnd } = require("%scripts/user/viralAcquisition.nut")
let { isAvailableFacebook } = require("%scripts/social/facebookStates.nut")

let { checkInvitesAfterFlight } = require("%scripts/social/psnSessionManager/getPsnSessionManagerApi.nut")
let { checkNuclearEvent } = require("%scripts/matching/serviceNotifications/nuclearEventHandler.nut")
let { checkShowRateWnd } = require("%scripts/user/suggestionRateGame.nut")
let { checkAutoShowEmailRegistration, checkForceSuggestionEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")
let { checkShowGpuBenchmarkWnd } = require("%scripts/options/gpuBenchmarkWnd.nut")

let delayed_gblk_error_popups = []
let function showGblkErrorPopup(errCode, path) {
  if (!::g_login.isLoggedIn())
  {
    delayed_gblk_error_popups.append({ type = errCode, path = path })
    return
  }

  let title = ::loc("gblk/saveError/title")
  let msg = ::loc(format("gblk/saveError/text/%d", errCode), {path=path})
  ::g_popups.add(title, msg, null, [{id="copy_button",
                              text=::loc("gblk/saveError/copy"),
                              func=(@(msg) function() {::copy_to_clipboard(msg)})(msg)}])
}
::show_gblk_error_popup <- showGblkErrorPopup //called from the native code

let function popGblkErrorPopups() {
  if (!::g_login.isLoggedIn())
    return

  let total = delayed_gblk_error_popups.len()
  for(local i = 0; i < total; i++)
  {
    let data = delayed_gblk_error_popups[i]
    showGblkErrorPopup(data.type, data.path)
  }
  delayed_gblk_error_popups.clear()
}


//called after all first mainmenu actions
local function onMainMenuReturn(handler, isAfterLogin) {
  if (!handler)
    return
  local isAllowPopups = ::g_login.isProfileReceived() && !::getFromSettingsBlk("debug/skipPopups")
  local guiScene = handler.guiScene
  if (isAllowPopups)
    ::SessionLobby.checkSessionReconnect()

  if (!isAfterLogin)
  {
    ::g_warbonds_view.resetShowProgressBarFlag()
    ::checkUnlockedCountriesByAirs()
    penalties.showBannedStatusMsgBox(true)
    if (isAllowPopups && !::disable_network())
    {
      handler.doWhenActive(checkShowRateWnd)
      handler.doWhenActive(checkJoystickThustmasterHotas)
    }
  }

  ::check_logout_scheduled()

  systemOptionsMaintain()
  ::g_user_presence.init()

  if (isAllowPopups)
    handler.doWhenActive(@() checkShowGpuBenchmarkWnd())

  handler.doWhenActive(@() ::checkNewNotificationUserlogs())
  handler.doWhenActive(@() ::checkNonApprovedResearches(true))

  if (isAllowPopups)
  {
    handler.doWhenActive(@() checkNuclearEvent())

    handler.doWhenActive(::gui_handlers.FontChoiceWnd.openIfRequired)

    handler.doWhenActive(@() checkInvitesAfterFlight() )
    handler.doWhenActive(@() ::g_xbox_squad_manager.checkAfterFlight() )
    handler.doWhenActive(@() ::g_battle_tasks.checkNewSpecialTasks() )
    handler.doWhenActiveOnce("checkNonApprovedSquadronResearches")
    if (isAfterLogin)
      handler.doWhenActive(@() checkForceSuggestionEmailRegistration())
  }

  if(isAllowPopups && ::has_feature("Invites") && !guiScene.hasModalObject())
  {
    local invitedPlayersBlk = ::DataBlock()
    ::get_invited_players_info(invitedPlayersBlk)
    if(invitedPlayersBlk.blockCount() == 0)
    {
      local gmBlk = ::get_game_settings_blk()
      local reminderPeriod = gmBlk?.viralAcquisitionReminderPeriodDays ?? 10
      local today = time.getUtcDays()
      local never = 0
      local lastShowTime = ::load_local_account_settings("viralAcquisition/lastShowTime", never)
      local lastLoginDay = ::load_local_account_settings("viralAcquisition/lastLoginDay", today)

      // Game designers can force reset lastShowTime of all users by increasing this value in cfg:
      if (gmBlk?.resetViralAcquisitionDaysCounter)
      {
        local newResetVer = gmBlk.resetViralAcquisitionDaysCounter
        local knownResetVer = ::load_local_account_settings("viralAcquisition/resetDays", 0)
        if (newResetVer > knownResetVer)
        {
          ::save_local_account_settings("viralAcquisition/resetDays", newResetVer)
          lastShowTime = never
        }
      }

      ::save_local_account_settings("viralAcquisition/lastLoginDay", today)
      if ((lastLoginDay - lastShowTime) > reminderPeriod)
      {
        ::save_local_account_settings("viralAcquisition/lastShowTime", today)
        showViralAcquisitionWnd()
      }
    }
  }

  if (!guiScene.hasModalObject() && isAllowPopups)
    handler.doWhenActive(@() checkAutoShowEmailRegistration())

  if (isAllowPopups && !guiScene.hasModalObject() && !isPlatformSony && isAvailableFacebook())
    handler.doWhenActive(show_facebook_login_reminder)
  if (isAllowPopups)
    handler.doWhenActive(function () { ::checkRemnantPremiumAccount() })
  if (handler.unitInfoPanel == null)
  {
    handler.unitInfoPanel = ::create_slot_info_panel(handler.scene, true, "mainmenu")
    handler.registerSubHandler(handler.unitInfoPanel)
  }

  if (isAllowPopups)
  {
    handler.doWhenActiveOnce("checkShowChangelog")
    handler.doWhenActiveOnce("initPromoBlock")

    local hasModalObjectVal = guiScene.hasModalObject()
    handler.doWhenActive(@() ::g_popup_msg.showPopupWndIfNeed(hasModalObjectVal) )
    handler.doWhenActive(@() itemNotifications.checkOfferToBuyAtExpiration() )
    handler.doWhenActive(@() checkGaijinPassReminder())

    handler.doWhenActive(::check_tutorial_on_start)
    handler.doWhenActiveOnce("checkNoviceTutor")
    handler.doWhenActiveOnce("checkUpgradeCrewTutorial")
    handler.doWhenActiveOnce("checkNewUnitTypeToBattleTutor")
  }

  handler.doWhenActive(popGblkErrorPopups)

  guiScene.initCursor("%gui/cursor.blk", "normal")

  ::broadcastEvent("MainMenuReturn")
}

onMainMenuReturnActions.mutate(@(v) v.onMainMenuReturn <- onMainMenuReturn)
