from "%scripts/dagui_natives.nut" import disable_network
from "%scripts/dagui_library.nut" import *

log($"onScriptLoadAfterLogin: wt")


let { loadOnce } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

require("unit/initUnitTypes.nut")
require("controls/shortcutsList/updateShortcutsModulesList.nut")
require("slotInfoPanel/updateSlotInfoPanelButtons.nut")
require("%scripts/warbonds/warbondAwardType.nut")
require("mainmenu/instantActionHandler.nut")
require("mainmenu/mainMenuHandler.nut")
require("hud/updateHudConfig.nut")
require("flightMenu/updateFlightMenuButtonTypes.nut")
require("mainmenu/autoStartBattleHandler.nut")
require("%scripts/items/itemsClasses/itemsClasses.nut")

foreach (fn in [
  "%scripts/money.nut"
  "%scripts/ranks.nut"
  "%scripts/difficulty.nut"
  "%scripts/teams.nut"
  "%scripts/airInfo.nut"
  "%scripts/options/optionsExt.nut"
  "%scripts/options/initOptions.nut"

  "%scripts/gamercard.nut"
  "%scripts/popups/popups.nut"

  "%scripts/wheelmenu/wheelmenu.nut"
  "%scripts/guiTutorial.nut"
  "%scripts/wndLib/multiSelectMenu.nut"
  "%scripts/showImage.nut"
  "%scripts/chooseImage.nut"
  "%scripts/wndLib/infoWnd.nut"
  "%scripts/wndLib/skipableMsgBox.nut"
  "%scripts/wndWidgets/navigationPanel.nut"

  "%scripts/timeBar.nut"

  "%scripts/postFxSettings.nut"
  "%scripts/artilleryMap.nut"

  "%scripts/firstChoice/countryChoiceWnd.nut"

  "%scripts/measureType.nut"
  "%scripts/genericOptions.nut"
  "%scripts/options/framedOptionsWnd.nut"
  "%scripts/options/optionsCustomDifficulty.nut"
  "%scripts/options/fontChoiceWnd.nut"

  "%scripts/leaderboard/leaderboardCategoryType.nut"
  "%scripts/leaderboard/leaderboardTable.nut"
  "%scripts/leaderboard/leaderboard.nut"

  "%scripts/queue/queueManager.nut"

  "%scripts/events/eventDisplayType.nut"
  "%scripts/events/eventsChapter.nut"
  "%scripts/events/eventsManager.nut"
  "%scripts/events/eventsHandler.nut"
  "%scripts/events/eventRoomsHandler.nut"
  "%scripts/events/eventRewardsWnd.nut"
  "%scripts/events/rewardProgressManager.nut"
  "%scripts/events/eventDescriptionWindow.nut"
  "%scripts/vehiclesWindow.nut"

  "%scripts/gameModes/gameModeSelect.nut"
  "%scripts/changeCountry.nut"
  "%scripts/promo/promoViewUtils.nut"
  "%scripts/unlocks/battleTasks.nut"
  "%scripts/mainmenu/topMenuSectionsConfigs.nut"
  "%scripts/mainmenu/topMenuButtonsHandler.nut"

  "%scripts/slotbar/crewsList.nut"
  "%scripts/weaponry/weaponryPresetsRepair.nut"
  "%scripts/slotbar/slotbarWidget.nut"
  "%scripts/slotbar/selectCrew.nut"
  "%scripts/slotbar/slotbarPresetsList.nut"

  "%scripts/user/presenceType.nut"
  "%scripts/squads/squadManager.nut"
  "%scripts/squads/squadUtils.nut"
  "%scripts/squads/squadInviteListWnd.nut"
  "%scripts/squads/squadWidgetCustomHandler.nut"

  "%scripts/chat/chatRoomType.nut"
  "%scripts/chat/chat.nut"
  "%scripts/chat/chatCategories.nut"
  "%scripts/chat/menuChat.nut"
  "%scripts/chat/createRoomWnd.nut"
  "%scripts/chat/chatThreadInfoTags.nut"
  "%scripts/chat/chatThreadInfo.nut"
  "%scripts/chat/chatThreadsListView.nut"
  "%scripts/chat/chatThreadHeader.nut"
  "%scripts/chat/modifyThreadWnd.nut"
  "%scripts/chat/mpChatMode.nut"
  "%scripts/chat/mpChat.nut"

  "%scripts/invites/inviteChatRoom.nut"
  "%scripts/invites/inviteSessionRoom.nut"
  "%scripts/invites/inviteTournamentBattle.nut"
  "%scripts/invites/inviteSquad.nut"
  "%scripts/invites/inviteFriend.nut"
  "%scripts/invites/invitesWnd.nut"

  "%scripts/controls/controls.nut"
  "%scripts/controls/controlsConsole.nut"
  "%scripts/controls/input/combination.nut"
  "%scripts/controls/input/axis.nut"
  "%scripts/controls/input/doubleAxis.nut"
  "%scripts/controls/input/image.nut"
  "%scripts/controls/input/keyboardAxis.nut"
  "%scripts/help/rwrThreatTypesWnd.nut"
  "%scripts/controls/controlsWizard.nut"
  "%scripts/controls/controlsType.nut"
  "%scripts/controls/AxisControls.nut"
  "%scripts/controls/aircraftHelpers.nut"
  "%scripts/controls/gamepadCursorControlsSplash.nut"
  "%scripts/help/helpInfoHandlerModal.nut"

  "%scripts/loading/loadingHangar.nut"
  "%scripts/loading/loadingBrief.nut"
  "%scripts/missions/missionType.nut"
  "%scripts/missions/missionsUtils.nut"
  "%scripts/missions/loadingUrlMissionModal.nut"
  "%scripts/missions/urlMissionsList.nut"
  "%scripts/missions/misListType.nut"
  "%scripts/missions/missionDescription.nut"
  "%scripts/tutorialsManager.nut"
  "%scripts/missions/campaignChapter.nut"
  "%scripts/missions/modifyUrlMissionWnd.nut"
  "%scripts/missions/chooseMissionsListWnd.nut"
  "%scripts/dynCampaign/dynamicChapter.nut"
  "%scripts/dynCampaign/campaignPreview.nut"
  "%scripts/dynCampaign/campaignResults.nut"
  "%scripts/briefing.nut"
  "%scripts/missionBuilder/testFlight.nut"
  "%scripts/missionBuilder/missionBuilder.nut"
  "%scripts/missionBuilder/missionBuilderTuner.nut"
  "%scripts/missionBuilder/changeAircraftForBuilder.nut"

  "%scripts/events/createEventRoomWnd.nut"

  "%scripts/replays/replayScreen.nut"
  "%scripts/replays/replayPlayer.nut"

  "%scripts/customization/types.nut"
  "%scripts/customization/decorator.nut"
  "%scripts/customization/customizationWnd.nut"

  "%scripts/myStats.nut"
  "%scripts/user/chooseTitle.nut"

  "%scripts/contacts/contacts.nut"

  "%scripts/unlocks/unlocks.nut"
  "%scripts/unlocks/unlocksView.nut"
  "%scripts/debriefing/rankUpModal.nut"
  "%scripts/unlocks/showUnlockHandler.nut"
  "%scripts/promo/battleTasksPromoHandler.nut"
  "%scripts/unlocks/battleTasksHandler.nut"
  "%scripts/unlocks/battleTasksSelectNewTask.nut"
  "%scripts/unlocks/favoriteUnlocksListView.nut"

  "%scripts/onlineShop/onlineShopModel.nut"
  "%scripts/onlineShop/onlineShop.nut"
  "%scripts/onlineShop/reqPurchaseWnd.nut"

  "%scripts/shop/shop.nut"
  "%scripts/shop/shopCheckResearch.nut"
  "%scripts/shop/shopViewWnd.nut"
  "%scripts/convertExpHandler.nut"

  "%scripts/weaponry/weaponryTypes.nut"
  "%scripts/weaponry/weaponrySelectModal.nut"
  "%scripts/weaponry/weaponryPresetsWnd.nut"

  "%scripts/weaponry/unitWeaponsHandler.nut"
  "%scripts/weaponry/weapons.nut"
  "%scripts/weaponry/weaponWarningHandler.nut"
  "%scripts/researches/finishedResearches.nut"
  "%scripts/modificationsTierResearched.nut"

  "%scripts/matchingRooms/sessionsListHandler.nut"
  "%scripts/mplayerParamType.nut"
  "%scripts/matchingRooms/mRoomPlayersListWidget.nut"
  "%scripts/matchingRooms/mpLobby.nut"
  "%scripts/matchingRooms/mRoomMembersWnd.nut"

  "%scripts/flightMenu/flightMenu.nut"
  "%scripts/statistics/mpStatistics.nut"
  "%scripts/statistics/mpStatisticsModal.nut"
  "%scripts/respawn/misLoadingState.nut"
  "%scripts/respawn/respawn.nut"
  "%scripts/respawn/teamUnitsLeftView.nut"
  "%scripts/misObjectives/objectiveStatus.nut"
  "%scripts/tacticalMap.nut"

  "%scripts/debriefing/debriefingModal.nut"
  "%scripts/debriefing/tournamentRewardReceivedModal.nut"
  "%scripts/mainmenu/benchmarkResultModal.nut"

  "%scripts/clans/clanType.nut"
  "%scripts/clans/clanLogType.nut"
  "%scripts/clans/clans.nut"
  "%scripts/clans/clanTagDecorator.nut"
  "%scripts/clans/modify/modifyClanModalHandler.nut"
  "%scripts/clans/clanChangeMembershipReqWnd.nut"
  "%scripts/clans/clanPageModal.nut"
  "%scripts/clans/clansModalHandler.nut"
  "%scripts/clans/clanChangeRoleModal.nut"
  "%scripts/clans/clanActivityModal.nut"
  "%scripts/clans/clanAverageActivityModal.nut"
  "%scripts/clans/clanSquadsModal.nut"
  "%scripts/clans/clanSquadInfoWnd.nut"
  "%scripts/clans/clanRequestsModal.nut"

  "%scripts/penitentiary/tribunal.nut"

  "%scripts/gamercardDrawer.nut"

  "%scripts/discounts/discounts.nut"
  "%scripts/discounts/discountUtils.nut"

  "%scripts/items/itemsManager.nut"
  "%scripts/items/prizesView.nut"
  "%scripts/items/recentItems.nut"
  "%scripts/items/recentItemsHandler.nut"
  "%scripts/items/ticketBuyWindow.nut"
  "%scripts/items/itemsShop.nut"
  "%scripts/items/trophyGroupShopWnd.nut"
  "%scripts/items/trophyRewardWnd.nut"
  "%scripts/items/trophyRewardList.nut"
  "%scripts/items/orderAwardMode.nut"
  "%scripts/items/orderType.nut"
  "%scripts/items/orderUseResult.nut"
  "%scripts/items/orderActivationWindow.nut"

  "%scripts/userLog/userlogData.nut"
  "%scripts/userLog/userlogViewData.nut"
  "%scripts/userLog/userLog.nut"

  "%scripts/crew/crewShortCache.nut"
  "%scripts/crew/skillParametersRequestType.nut"
  "%scripts/crew/skillParametersColumnType.nut"
  "%scripts/crew/skillsPageStatus.nut"
  "%scripts/crew/crewPoints.nut"
  "%scripts/crew/crewBuyPointsHandler.nut"
  "%scripts/crew/crewUnitSpecHandler.nut"
  "%scripts/crew/crewSpecType.nut"
  "%scripts/crew/crew.nut"
  "%scripts/crew/unitCrewCache.nut"
  "%scripts/crew/skillParametersType.nut"

  "%scripts/slotbar/slotbarPresets.nut"
  "%scripts/vehicleRequireFeatureWindow.nut"
  "%scripts/unit/unitInfoType.nut"
  "%scripts/unit/unitInfoExporter.nut"

  "%scripts/hud/hudEventManager.nut"
  "%scripts/hud/hudVisMode.nut"
  "%scripts/hud/baseUnitHud.nut"
  "%scripts/hud/hud.nut"
  "%scripts/hud/hudActionBarType.nut"
  "%scripts/replays/spectator.nut"
  "%scripts/hud/hudTankDebuffs.nut"
  "%scripts/hud/hudCrewState.nut"
  "%scripts/hud/hudEnemyDebuffsType.nut"
  "%scripts/hud/hudEnemyDamage.nut"
  "%scripts/hud/hudRewardMessage.nut"
  "%scripts/hud/hudMessages.nut"
  "%scripts/hud/hudMessageStack.nut"
  "%scripts/hud/hudBattleLog.nut"
  "%scripts/hud/hudLiveStats.nut"
  "%scripts/hud/hudTutorialElements.nut"
  "%scripts/streaks.nut"
  "%scripts/wheelmenu/voicemenu.nut"
  "%scripts/wheelmenu/multifuncmenu.nut"
  "%scripts/hud/hudHintTypes.nut"
  "%scripts/hud/hudHints.nut"
  "%scripts/hud/hudHintsManager.nut"

  "%scripts/warbonds/warbondsManager.nut"
  "%scripts/warbonds/warbondShop.nut"

  "%scripts/utils/popupMessages.nut"
  "%scripts/fileDialog/fileDialog.nut"
  "%scripts/fileDialog/saveDataDialog.nut"
  "%scripts/controls/controlsBackupManager.nut"

  "%scripts/matching/serviceNotifications/mlogin.nut"
  "%scripts/matching/serviceNotifications/mrpc.nut"
  "%scripts/matching/serviceNotifications/msquad.nut"

  "%scripts/items/buyAndOpenChestWnd.nut"
  "%scripts/gamepadSceneSettings.nut"

  "%scripts/user/profileOpener.nut"
]) {
  loadOnce(fn)
}

require("%scripts/controls/controlsFootballNy2021Hack.nut")
require("%scripts/slotbar/elems/unlockMarkerElem.nut")
require("%scripts/slotbar/elems/nationBonusMarkerElem.nut")
require("%scripts/slotbar/elems/discountIconElem.nut")
require("%scripts/items/trophyShowTime.nut")
require("%scripts/dlcontent/dlContent.nut")
require("%scripts/dynamic/mainMissionGenerator.nut")
require("%scripts/mainmenu/hideMainMenuUi.nut")
require("%scripts/wheelmenu/chooseVehicleWheelMenu.nut")
require("%scripts/login/loginContacts.nut")
require("%scripts/mainmenu/onMainMenuReturn.nut")
require("%scripts/unlocks/regionalUnlocksPromo.nut")
require("%scripts/user/suggestionEmailRegistrationPromo.nut")
require("%scripts/statsd/missionStats.nut")
require("%scripts/misCustomRules/ruleSharedPool.nut")
require("%scripts/misCustomRules/ruleEnduringConfrontation.nut")
require("%scripts/misCustomRules/ruleNumSpawnsByUnitType.nut")
require("%scripts/misCustomRules/ruleUnitsDeck.nut")
require("%scripts/misCustomRules/ruleAdditionalUnits.nut")
require("%scripts/items/roulette/bhvRoulette.nut")
require("%scripts/items/discountItemSortMethod.nut")
require("%scripts/items/trophyMultiAward.nut")
require("%scripts/items/listPopupWnd/itemsListWndBase.nut")
require("%scripts/items/listPopupWnd/universalSpareApplyWnd.nut")
require("%scripts/items/listPopupWnd/modUpgradeApplyWnd.nut")
require("%scripts/items/roulette/itemsRoulette.nut")
require("%scripts/matchingRooms/joiningGameWaitBox.nut")
require("%scripts/matching/serviceNotifications/mroomsNotifications.nut")

require("%scripts/debugTools/dbgCheckContent.nut")
require("%scripts/debugTools/dbgUnlocks.nut")
require("%scripts/debugTools/dbgClans.nut")
require("%scripts/debugTools/dbgHudObjects.nut")
require("%scripts/debugTools/dbgVoiceChat.nut")
require("%scripts/debugTools/dbgDumpTools.nut")
require("%scripts/debugTools/dbgUtilsAfterLogin.nut")
require("%scripts/debugTools/dbgMarketplace.nut")
require("%scripts/dmViewer/modeXrayDebugExport.nut")

require("%scripts/exportInfo/skinsLocExporter.nut")
require("%scripts/onlineShop/buyPremiumHandler.nut")
require("%scripts/unlocks/requestInventoryUnlocks.nut")

let { isAuthorized } = require("%appGlobals/login/loginState.nut")
if (isAuthorized.get() || disable_network()) 
  require("%scripts/worldWar/worldWar.nut")
