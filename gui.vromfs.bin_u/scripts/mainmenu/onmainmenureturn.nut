from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let onMainMenuReturnActions = require("%scripts/mainmenu/onMainMenuReturnActions.nut")
let penalties = require("%scripts/penitentiary/penalties.nut")
let itemNotifications = require("%scripts/items/itemNotifications.nut")
let { checkGaijinPassReminder } = require("%scripts/mainmenu/reminderGaijinPass.nut")
let { systemOptionsMaintain } = require("%scripts/options/systemOptions.nut")
let { checkJoystickThustmasterHotas } = require("%scripts/controls/hotas.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { isAvailableFacebook } = require("%scripts/social/facebookStates.nut")

let { checkInvitesAfterFlight } = require("%scripts/social/psnSessionManager/getPsnSessionManagerApi.nut")
let { checkNuclearEvent } = require("%scripts/matching/serviceNotifications/nuclearEventHandler.nut")
let { checkShowRateWnd } = require("%scripts/user/suggestionRateGame.nut")
let { checkAutoShowEmailRegistration } = require("%scripts/user/suggestionEmailRegistration.nut")
let { checkShowGpuBenchmarkWnd } = require("%scripts/options/gpuBenchmarkWnd.nut")
let { checkAfterFlight } = require("%scripts/social/xboxSquadManager/xboxSquadManager.nut")

let delayed_gblk_error_popups = []
let function showGblkErrorPopup(errCode, path) {
  if (!::g_login.isLoggedIn())
  {
    delayed_gblk_error_popups.append({ type = errCode, path = path })
    return
  }

  let title = loc("gblk/saveError/title")
  let msg = loc(format("gblk/saveError/text/%d", errCode), {path=path})
  ::g_popups.add(title, msg, null, [{id="copy_button",
                              text=loc("gblk/saveError/copy"),
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
    handler.doWhenActive(checkAfterFlight)
    handler.doWhenActive(@() ::g_battle_tasks.checkNewSpecialTasks() )
    handler.doWhenActiveOnce("checkNonApprovedSquadronResearches")
  }

  if(isAllowPopups && hasFeature("Invites") && !guiScene.hasModalObject())
    handler.doWhenActiveOnce("checkShowViralAcquisition")

  if (!guiScene.hasModalObject() && isAllowPopups)
    handler.doWhenActive(@() checkAutoShowEmailRegistration())

  if (isAllowPopups && !guiScene.hasModalObject() && !isPlatformSony && isAvailableFacebook())
    handler.doWhenActive(function () { ::show_facebook_login_reminder() })
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
