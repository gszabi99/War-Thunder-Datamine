import "%scripts/mainmenu/onMainMenuReturnActions.nut" as onMainMenuReturnActions
import "%scripts/items/itemNotifications.nut" as itemNotifications
from "%scripts/options/fontChoiceWnd.nut" import FontChoiceWnd
from "%scripts/slotInfoPanel.nut" import createSlotInfoPanel
from "%scripts/userstat/userstatItemsRewards.nut" import claimRegionalUnlockRewards
from "%scripts/penitentiary/bannedStatusMsgBox.nut" import showBannedStatusMsgBox
from "%scripts/mainmenu/reminderGaijinPass.nut" import checkGaijinPassReminder
from "%scripts/options/systemOptions.nut" import systemOptionsMaintain, checkShowGraphicSettingsWasModified, checkShowFullscreenImeUnavailable
from "%scripts/controls/hotas.nut" import checkJoystickThustmasterHotas
from "%scripts/unlocks/battleTasks.nut" import checkNewSpecialTasks
from "%scripts/social/psnSessionManager/getPsnSessionManagerApi.nut" import checkInvitesAfterFlight
from "%scripts/matching/serviceNotifications/nuclearEventHandler.nut" import checkNuclearEvent
from "%scripts/user/suggestionRateGame.nut" import checkShowRateWnd
from "%scripts/user/suggestionEmailRegistration.nut" import checkShowEmailRegistration, checkShowGuestEmailRegistrationAfterLogin
from "%scripts/options/gpuBenchmarkWnd.nut" import checkShowGpuBenchmarkWnd
from "%scripts/social/xboxSquadManager/xboxSquadManager.nut" import checkAfterFlight
from "%scripts/user/personalOffers.nut" import checkShowPersonalOffers
from "%scripts/inventory/steamCheckNewItems.nut" import steamCheckNewItems
from "%scripts/tutorials.nut" import checkTutorialOnStart
from "%scripts/user/profileStates.nut" import isGuestLogin
from "%scripts/clientState/clientStates.nut" import getFromSettingsBlk
from "%scripts/firstChoice/firstChoice.nut" import checkUnlockedCountriesByAirs
from "%scripts/weaponry/weaponryPresetsRepair.nut" import searchAndRepairInvalidPresets
from "%scripts/customization/suggestionShowDecalsOnOtherPlayers.nut" import checkDecalsOnOtherPlayersOptions
from "%scripts/popups/popups.nut" import addPopup
from "%scripts/researches/researchActions.nut" import checkNonApprovedResearches
from "%scripts/matchingRooms/sessionLobbyActions.nut" import checkReconnect
from "%scripts/userPresence.nut" import initUserPresence
from "%scripts/options/tankSightMigrate.nut" import showUserSightMigrationPopupIfNeeded
from "%scripts/login/logout.nut" import checkLogoutScheduled
from "%scripts/utils/popupMessages.nut" import showPopupWndIfNeed
from "%scripts/userLog/userlogData.nut" import checkNewNotificationUserlogs
from "%scripts/user/newbieTutorialDisplay.nut" import needShowTutorial
from "%scripts/penitentiary/soundMods.nut" import showMsgboxIfSoundModsForceDisabled, showMsgboxIfSoundModsBanksCheckFailed
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/login/loginState.nut" import hasFullLoginState, isProfileReceived
from "%globalScripts/clientState/initialState.nut" import disableNetwork
from "hangar" import DM_VIEWER_ARMOR, DM_VIEWER_XRAY
from "string" import format
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_natives.nut" import copy_to_clipboard
from "%scripts/dagui_library.nut" import *


let dmViewer = require("%scripts/dmViewer/dmViewer.nut")
let ludeo = require_optional("acesludeo")


let delayed_gblk_error_popups = []
function showGblkErrorPopup(errCode, path) {
  if (!hasFullLoginState.get()) {
    delayed_gblk_error_popups.append({ type = errCode, path = path })
    return
  }

  let title = loc("gblk/saveError/title")
  let msg = loc(format("gblk/saveError/text/%d", errCode), { path = path })
  addPopup(title, msg, null, [{ id = "copy_button",
                              text = loc("gblk/saveError/copy"),
                              func = @() copy_to_clipboard(msg) }])
}
eventbus_subscribe("showGblkErrorPopupNative", @(params) showGblkErrorPopup(params.errorType, params.path))

function popGblkErrorPopups() {
  if (!hasFullLoginState.get())
    return

  let total = delayed_gblk_error_popups.len()
  for (local i = 0; i < total; i++) {
    let data = delayed_gblk_error_popups[i]
    showGblkErrorPopup(data.type, data.path)
  }
  delayed_gblk_error_popups.clear()
}



function onMainMenuReturn(handler, isAfterLogin) {
  if (!handler)
    return
  local isAllowPopups = isProfileReceived.get() && !getFromSettingsBlk("debug/skipPopups")
  local guiScene = handler.guiScene
  if (isAfterLogin && isAllowPopups)
    checkReconnect()

  if (!isAfterLogin) {
    checkUnlockedCountriesByAirs()
    showBannedStatusMsgBox(true)
    if (isAllowPopups && !disableNetwork) {
      handler.doWhenActive(checkShowRateWnd)
      handler.doWhenActive(checkJoystickThustmasterHotas)
    }
  }

  checkLogoutScheduled()

  systemOptionsMaintain()
  initUserPresence()

  if (isAllowPopups)
    handler.doWhenActive(@() checkShowGpuBenchmarkWnd())

  handler.doWhenActive(@() checkNewNotificationUserlogs())
  handler.doWhenActive(@() checkNonApprovedResearches(true))

  if (isAllowPopups) {
    handler.doWhenActive(@() checkNuclearEvent())

    handler.doWhenActive(FontChoiceWnd.openIfRequired)

    handler.doWhenActive(@() checkInvitesAfterFlight())
    handler.doWhenActive(checkAfterFlight)
    handler.doWhenActive(@() checkNewSpecialTasks())
    handler.doWhenActiveOnce("checkNonApprovedSquadronResearches")
  }

  if (isAllowPopups && hasFeature("Invites") && !isGuestLogin.get())
    handler.doWhenActiveOnce("checkShowViralAcquisition")

  if (isAllowPopups)
    handler.doWhenActive(@() checkShowEmailRegistration())

  if (isAfterLogin && isAllowPopups)
    handler.doWhenActive(@() checkShowGuestEmailRegistrationAfterLogin())

  if (handler.unitInfoPanel == null) {
    handler.unitInfoPanel = createSlotInfoPanel(handler.scene, {showTabs = true, configSaveId = "infantry_camouflage"})
    handler.registerSubHandler(handler.unitInfoPanel)
  }

  if (isAllowPopups) {
    handler.doWhenActiveOnce("checkShowChangelog")
    handler.doWhenActiveOnce("initPromoBlock")

    local hasModalObjectVal = guiScene.hasModalObject()
    handler.doWhenActive(@() showPopupWndIfNeed(hasModalObjectVal))
    handler.doWhenActive(@() itemNotifications.checkOfferToBuyAtExpiration())
    handler.doWhenActive(@() checkGaijinPassReminder())

    handler.doWhenActive(checkTutorialOnStart)
    handler.doWhenActiveOnce("checkCountrySelect")
    if (!needShowTutorial("takeUnit", 1))
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
    handler.doWhenActive(@() dmViewer.checkShowViewModeTutor(DM_VIEWER_XRAY))
    handler.doWhenActive(@() dmViewer.checkShowViewModeTutor(DM_VIEWER_ARMOR))
  }

  if (isAfterLogin && isAllowPopups) {
    checkShowGraphicSettingsWasModified()
    searchAndRepairInvalidPresets()
    showUserSightMigrationPopupIfNeeded()
    showMsgboxIfSoundModsForceDisabled()
    showMsgboxIfSoundModsBanksCheckFailed()
  }

  if (isAfterLogin && ludeo?.is_running())
    ludeo?.activate_session()

  handler.doWhenActive(popGblkErrorPopups)

  if (isAfterLogin && isAllowPopups)
    handler.doWhenActive(checkShowFullscreenImeUnavailable)

  guiScene.initCursor("%gui/cursor.blk", "normal")

  broadcastEvent("MainMenuReturn")
}

onMainMenuReturnActions.mutate(@(v) v.onMainMenuReturn <- onMainMenuReturn)
