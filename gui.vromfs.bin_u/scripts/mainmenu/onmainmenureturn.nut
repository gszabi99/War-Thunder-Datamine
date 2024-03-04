from "%scripts/dagui_natives.nut" import disable_network, copy_to_clipboard
from "%scripts/dagui_library.nut" import *

//checked for explicitness
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { createSlotInfoPanel } = require("%scripts/slotInfoPanel.nut")
let { claimRegionalUnlockRewards } = require("%scripts/unlocks/regionalUnlocks.nut")
let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let onMainMenuReturnActions = require("%scripts/mainmenu/onMainMenuReturnActions.nut")
let penalties = require("%scripts/penitentiary/penalties.nut")
let itemNotifications = require("%scripts/items/itemNotifications.nut")
let { checkGaijinPassReminder } = require("%scripts/mainmenu/reminderGaijinPass.nut")
let { systemOptionsMaintain } = require("%scripts/options/systemOptions.nut")
let { checkJoystickThustmasterHotas } = require("%scripts/controls/hotas.nut")
let { checkNewSpecialTasks } = require("%scripts/unlocks/battleTasks.nut")
let { checkInvitesAfterFlight } = require("%scripts/social/psnSessionManager/getPsnSessionManagerApi.nut")
let { checkNuclearEvent } = require("%scripts/matching/serviceNotifications/nuclearEventHandler.nut")
let { checkShowRateWnd } = require("%scripts/user/suggestionRateGame.nut")
let { checkShowEmailRegistration,
  checkShowGuestEmailRegistrationAfterLogin } = require("%scripts/user/suggestionEmailRegistration.nut")
let { checkShowGpuBenchmarkWnd } = require("%scripts/options/gpuBenchmarkWnd.nut")
let { checkAfterFlight } = require("%scripts/social/xboxSquadManager/xboxSquadManager.nut")
let { checkShowPersonalOffers } = require("%scripts/user/personalOffers.nut")
let { steamCheckNewItems } = require("%scripts/inventory/steamCheckNewItems.nut")
let { checkTutorialOnStart } = require("%scripts/tutorials.nut")
let { isGuestLogin } = require("%scripts/user/profileStates.nut")
let { getFromSettingsBlk } = require("%scripts/clientState/clientStates.nut")
let { checkUnlockedCountriesByAirs } = require("%scripts/firstChoice/firstChoice.nut")
let { searchAndRepairInvalidPresets } = require("%scripts/weaponry/weaponryPresetsRepair.nut")
let { checkDecalsOnOtherPlayersOptions }  = require("%scripts/customization/suggestionShowDecalsOnOtherPlayers.nut")
let { addPopup } = require("%scripts/popups/popups.nut")

let delayed_gblk_error_popups = []
function showGblkErrorPopup(errCode, path) {
  if (!::g_login.isLoggedIn()) {
    delayed_gblk_error_popups.append({ type = errCode, path = path })
    return
  }

  let title = loc("gblk/saveError/title")
  let msg = loc(format("gblk/saveError/text/%d", errCode), { path = path })
  addPopup(title, msg, null, [{ id = "copy_button",
                              text = loc("gblk/saveError/copy"),
                              func = @() copy_to_clipboard(msg) }])
}
::show_gblk_error_popup <- showGblkErrorPopup //called from the native code

function popGblkErrorPopups() {
  if (!::g_login.isLoggedIn())
    return

  let total = delayed_gblk_error_popups.len()
  for (local i = 0; i < total; i++) {
    let data = delayed_gblk_error_popups[i]
    showGblkErrorPopup(data.type, data.path)
  }
  delayed_gblk_error_popups.clear()
}


//called after all first mainmenu actions
local function onMainMenuReturn(handler, isAfterLogin) {
  if (!handler)
    return
  local isAllowPopups = ::g_login.isProfileReceived() && !getFromSettingsBlk("debug/skipPopups")
  local guiScene = handler.guiScene
  if (isAfterLogin && isAllowPopups)
    ::SessionLobby.checkReconnect()

  if (!isAfterLogin) {
    checkUnlockedCountriesByAirs()
    penalties.showBannedStatusMsgBox(true)
    if (isAllowPopups && !disable_network()) {
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

  if (isAllowPopups) {
    handler.doWhenActive(@() checkNuclearEvent())

    handler.doWhenActive(gui_handlers.FontChoiceWnd.openIfRequired)

    handler.doWhenActive(@() checkInvitesAfterFlight())
    handler.doWhenActive(checkAfterFlight)
    handler.doWhenActive(@() checkNewSpecialTasks())
    handler.doWhenActiveOnce("checkNonApprovedSquadronResearches")
  }

  if (isAllowPopups && hasFeature("Invites") && !isGuestLogin.value && !guiScene.hasModalObject())
    handler.doWhenActiveOnce("checkShowViralAcquisition")

  if (isAllowPopups && !guiScene.hasModalObject())
    handler.doWhenActive(@() checkShowEmailRegistration())

  if (isAfterLogin && isAllowPopups && !guiScene.hasModalObject())
    handler.doWhenActive(@() checkShowGuestEmailRegistrationAfterLogin())

  if (handler.unitInfoPanel == null) {
    handler.unitInfoPanel = createSlotInfoPanel(handler.scene, true, "mainmenu")
    handler.registerSubHandler(handler.unitInfoPanel)
  }

  if (isAllowPopups) {
    handler.doWhenActiveOnce("checkShowChangelog")
    handler.doWhenActiveOnce("initPromoBlock")

    local hasModalObjectVal = guiScene.hasModalObject()
    handler.doWhenActive(@() ::g_popup_msg.showPopupWndIfNeed(hasModalObjectVal))
    handler.doWhenActive(@() itemNotifications.checkOfferToBuyAtExpiration())
    handler.doWhenActive(@() checkGaijinPassReminder())

    handler.doWhenActive(checkTutorialOnStart)
    handler.doWhenActiveOnce("checkNoviceTutor")
    handler.doWhenActiveOnce("checkUpgradeCrewTutorial")
    handler.doWhenActiveOnce("checkNewUnitTypeToBattleTutor")
    handler.doWhenActive(steamCheckNewItems)
    handler.doWhenActive(checkShowPersonalOffers)
    handler.doWhenActive(@() claimRegionalUnlockRewards())
    handler.doWhenActiveOnce("checkShowDynamicLutSuggestion")
    handler.doWhenActive(checkDecalsOnOtherPlayersOptions)
  }

  if (!isAfterLogin && isAllowPopups) {
    handler.doWhenActive(@() ::dmViewer.checkShowViewModeTutor(DM_VIEWER_XRAY))
    handler.doWhenActive(@() ::dmViewer.checkShowViewModeTutor(DM_VIEWER_ARMOR))
  }

  if (isAfterLogin && isAllowPopups) {
    searchAndRepairInvalidPresets()
  }

  handler.doWhenActive(popGblkErrorPopups)

  guiScene.initCursor("%gui/cursor.blk", "normal")

  broadcastEvent("MainMenuReturn")
}

onMainMenuReturnActions.mutate(@(v) v.onMainMenuReturn <- onMainMenuReturn)
