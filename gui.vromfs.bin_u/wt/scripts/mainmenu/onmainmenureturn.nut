local onMainMenuReturnActions = require("scripts/mainmenu/onMainMenuReturnActions.nut")

local time = require("scripts/time.nut")
local penalties = require("scripts/penitentiary/penalties.nut")
local itemNotifications = ::require("scripts/items/itemNotifications.nut")
local { systemOptionsMaintain } = require("scripts/options/systemOptions.nut")
local { checkJoystickThustmasterHotas } = require("scripts/controls/hotas.nut")
local { checkGaijinPassReminder } = require("scripts/mainmenu/reminderGaijinPass.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")

//called after all first mainmenu actions
onMainMenuReturnActions.onMainMenuReturn <- function(handler, isAfterLogin) {
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
      handler.doWhenActive(::g_user_utils.checkShowRateWnd)
      handler.doWhenActive(checkJoystickThustmasterHotas)
    }
  }

  ::check_logout_scheduled()

  systemOptionsMaintain()
  ::g_user_presence.init()

  handler.doWhenActive(@() ::checkNewNotificationUserlogs())
  handler.doWhenActive(@() ::checkNonApprovedResearches(true))

  if (isAllowPopups)
  {
    handler.doWhenActive(::gui_handlers.FontChoiceWnd.openIfRequired)

    handler.doWhenActive(@() ::g_psn_sessions.checkAfterFlight() )
    handler.doWhenActive(@() ::g_xbox_squad_manager.checkAfterFlight() )
    handler.doWhenActive(@() ::g_battle_tasks.checkNewSpecialTasks() )
    handler.doWhenActiveOnce("checkNonApprovedSquadronResearches")
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
        ::show_viral_acquisition_wnd()
      }
    }
  }

  if (!guiScene.hasModalObject() && isAllowPopups)
  {
    handler.doWhenActive(@() ::g_user_utils.checkAutoShowPS4EmailRegistration())
    handler.doWhenActive(@() ::g_user_utils.checkAutoShowSteamEmailRegistration())
  }

  if (isAllowPopups && !guiScene.hasModalObject() && !isPlatformSony && ::has_feature("Facebook"))
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

  handler.doWhenActive(::pop_gblk_error_popups)

  guiScene.initCursor("gui/cursor.blk", "normal")
}
