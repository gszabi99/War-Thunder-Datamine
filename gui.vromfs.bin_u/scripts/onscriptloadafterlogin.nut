//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

log($"onScriptLoadAfterLogin: wt")

// Please don't move paths from the main list here anymore. Instead, just edit paths in the main list below.
let { loadOnce, loadIfExist } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

require("unit/initUnitTypes.nut")
require("controls/shortcutsList/updateShortcutsModulesList.nut")
require("slotInfoPanel/updateSlotInfoPanelButtons.nut")
require("mainmenu/instantActionHandler.nut")
require("mainmenu/mainMenuHandler.nut")
require("hud/updateHudConfig.nut")
require("flightMenu/updateFlightMenuButtonTypes.nut")
require("mainmenu/autoStartBattleHandler.nut")

foreach (fn in [
  "%scripts/money.nut"

  "%scripts/ranks.nut"
  "%scripts/difficulty.nut"
  "%scripts/teams.nut"
  "%scripts/unit/unit.nut"
  "%scripts/airInfo.nut"
  "%scripts/options/optionsExt.nut"
  "%scripts/options/initOptions.nut"

  "%scripts/gamercard.nut"
  "%scripts/popups/popups.nut"

  "%scripts/wheelmenu/wheelmenu.nut"
  "%scripts/guiLines.nut"
  "%scripts/guiTutorial.nut"
  "%scripts/wndLib/multiSelectMenu.nut"
  "%scripts/showImage.nut"
  "%scripts/chooseImage.nut"
  "%scripts/newIconWidget.nut"
  "%scripts/wndLib/commentModal.nut"
  "%scripts/wndLib/infoWnd.nut"
  "%scripts/wndLib/skipableMsgBox.nut"
  "%scripts/wndWidgets/navigationPanel.nut"

  "%scripts/timeBar.nut"

  "%scripts/dataBlockAdapter.nut"

  "%scripts/postFxSettings.nut"
  "%scripts/artilleryMap.nut"

  "%scripts/utils/genericTooltip.nut"

  "%scripts/eulaWnd.nut"
  "%scripts/firstChoice/countryChoiceWnd.nut"

  "%scripts/measureType.nut"
  "%scripts/genericOptions.nut"
  "%scripts/options/framedOptionsWnd.nut"
  "%scripts/options/optionsCustomDifficulty.nut"
  "%scripts/options/fontChoiceWnd.nut"

  "%scripts/leaderboard/leaderboardDataType.nut"
  "%scripts/leaderboard/leaderboardCategoryType.nut"
  "%scripts/leaderboard/leaderboardTable.nut"
  "%scripts/leaderboard/leaderboard.nut"

  "%scripts/queue/queueManager.nut"

  "%scripts/events/eventDisplayType.nut"
  "%scripts/events/eventsChapter.nut"
  "%scripts/events/eventsManager.nut"
  "%scripts/events/eventsHandler.nut"
  "%scripts/events/eventRoomsHandler.nut"
  "%scripts/events/eventsLeaderboards.nut"
  "%scripts/events/eventRewards.nut"
  "%scripts/events/eventRewardsWnd.nut"
  "%scripts/events/rewardProgressManager.nut"
  "%scripts/events/eventDescription.nut"
  "%scripts/events/eventTicketBuyOfferProcess.nut"
  "%scripts/events/eventDescriptionWindow.nut"
  "%scripts/vehiclesWindow.nut"
  "%scripts/events/eventJoinProcess.nut"

  "%scripts/gameModes/gameModeSelect.nut"
  "%scripts/gameModes/gameModeManager.nut"
  "%scripts/changeCountry.nut"
  "%scripts/instantAction.nut"
  "%scripts/promo/promoViewUtils.nut"
  "%scripts/unlocks/battleTaskDifficulty.nut"
  "%scripts/unlocks/battleTasks.nut"
  "%scripts/promo/promo.nut"
  "%scripts/promo/promoHandler.nut"
  "%scripts/mainmenu/topMenuSections.nut"
  "%scripts/mainmenu/topMenuSectionsConfigs.nut"
  "%scripts/mainmenu/topMenuButtonsHandler.nut"
  "%scripts/mainmenu/guiStartMainmenu.nut"
  "%scripts/credits.nut"

  "%scripts/slotbar/crewsList.nut"
  "%scripts/slotbar/slotbar.nut"
  "%scripts/weaponry/editWeaponryPreset.nut"
  "%scripts/weaponry/weaponryPresetsRepair.nut"
  "%scripts/slotbar/slotbarWidget.nut"
  "%scripts/slotbar/selectCrew.nut"
  "%scripts/slotbar/slotbarPresetsList.nut"

  "%scripts/onlineInfo/onlineInfo.nut"
  "%scripts/onlineInfo/clustersManagement.nut"
  "%scripts/matching/matchingGameModes.nut"

  "%scripts/user/presenceType.nut"
  "%scripts/squads/msquadService.nut"
  "%scripts/squads/squadMember.nut"
  "%scripts/squads/squadManager.nut"
  "%scripts/squads/squadUtils.nut"
  "%scripts/squads/squadInviteListWnd.nut"
  "%scripts/squads/squadWidgetCustomHandler.nut"

  "%scripts/chat/chatRoomType.nut"
  "%scripts/chat/chat.nut"
  "%scripts/chat/chatLatestThreads.nut"
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

  "%scripts/invites/invites.nut"
  "%scripts/invites/inviteBase.nut"
  "%scripts/invites/inviteChatRoom.nut"
  "%scripts/invites/inviteSessionRoom.nut"
  "%scripts/invites/inviteTournamentBattle.nut"
  "%scripts/invites/inviteSquad.nut"
  "%scripts/invites/inviteFriend.nut"
  "%scripts/invites/invitesWnd.nut"

  "%scripts/controls/controlsPresets.nut"
  "%scripts/controls/controls.nut"
  "%scripts/controls/assignButtonWnd.nut"
  "%scripts/controls/controlsConsole.nut"
  "%scripts/controls/input/button.nut"
  "%scripts/controls/input/combination.nut"
  "%scripts/controls/input/axis.nut"
  "%scripts/controls/input/doubleAxis.nut"
  "%scripts/controls/input/image.nut"
  "%scripts/controls/input/keyboardAxis.nut"
  "%scripts/help/helpWnd.nut"
  "%scripts/controls/controlsWizard.nut"
  "%scripts/controls/controlsType.nut"
  "%scripts/controls/AxisControls.nut"
  "%scripts/controls/aircraftHelpers.nut"
  "%scripts/controls/gamepadCursorControlsSplash.nut"
  "%scripts/help/helpInfoHandlerModal.nut"
  "%scripts/joystickInterface.nut"

  "%scripts/loading/loadingHangar.nut"
  "%scripts/loading/loadingBrief.nut"
  "%scripts/missions/mapPreview.nut"
  "%scripts/missions/missionType.nut"
  "%scripts/missions/missionsUtils.nut"
  "%scripts/missions/urlMission.nut"
  "%scripts/missions/loadingUrlMissionModal.nut"
  "%scripts/missions/missionsManager.nut"
  "%scripts/missions/urlMissionsList.nut"
  "%scripts/missions/misListType.nut"
  "%scripts/missions/missionDescription.nut"
  "%scripts/tutorialsManager.nut"
  "%scripts/missions/campaignChapter.nut"
  "%scripts/missions/remoteMissionModalHandler.nut"
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

  "%scripts/events/eventRoomCreationContext.nut"
  "%scripts/events/createEventRoomWnd.nut"

  "%scripts/replays/replayScreen.nut"
  "%scripts/replays/replayPlayer.nut"

  "%scripts/customization/types.nut"
  "%scripts/customization/decorator.nut"
  "%scripts/customization/customizationWnd.nut"

  "%scripts/myStats.nut"
  "%scripts/user/partnerUnlocks.nut"
  "%scripts/user/userCard.nut"
  "%scripts/user/profileHandler.nut"
  "%scripts/user/viralAcquisition.nut"
  "%scripts/user/chooseTitle.nut"

  "%scripts/contacts/contacts.nut"
  "%scripts/userPresence.nut"

  "%scripts/unlocks/unlocksConditions.nut"
  "%scripts/unlocks/unlocks.nut"
  "%scripts/unlocks/unlocksView.nut"
  "%scripts/unlocks/showUnlock.nut"
  "%scripts/promo/battleTasksPromoHandler.nut"
  "%scripts/unlocks/personalUnlocks.nut"
  "%scripts/unlocks/battleTasksHandler.nut"
  "%scripts/unlocks/battleTasksSelectNewTask.nut"
  "%scripts/unlocks/favoriteUnlocksListView.nut"
  "%scripts/unlocks/unlockSmoke.nut"

  "%scripts/onlineShop/onlineShopModel.nut"
  "%scripts/onlineShop/onlineShop.nut"
  "%scripts/onlineShop/reqPurchaseWnd.nut"
  "%scripts/paymentHandler.nut"

  "%scripts/shop/shop.nut"
  "%scripts/shop/shopCheckResearch.nut"
  "%scripts/shop/shopViewWnd.nut"
  "%scripts/convertExpHandler.nut"

  "%scripts/weaponry/dmgModel.nut"
  "%scripts/weaponry/unitBulletsGroup.nut"
  "%scripts/weaponry/unitBulletsManager.nut"
  "%scripts/dmViewer/dmViewer.nut"
  "%scripts/weaponry/weaponryTypes.nut"
  "%scripts/weaponry/weaponrySelectModal.nut"
  "%scripts/weaponry/unitWeaponsHandler.nut"
  "%scripts/weaponry/weapons.nut"
  "%scripts/weaponry/weaponWarningHandler.nut"
  "%scripts/weaponry/weaponsPurchase.nut"
  "%scripts/finishedResearches.nut"
  "%scripts/modificationsTierResearched.nut"

  "%scripts/matchingRooms/sessionLobby.nut"
  "%scripts/matchingRooms/mRoomsList.nut"
  "%scripts/matchingRooms/mRoomInfo.nut"
  "%scripts/matchingRooms/mRoomInfoManager.nut"
  "%scripts/matchingRooms/sessionsListHandler.nut"
  "%scripts/mplayerParamType.nut"
  "%scripts/matchingRooms/mRoomPlayersListWidget.nut"
  "%scripts/matchingRooms/mpLobby.nut"
  "%scripts/matchingRooms/mRoomMembersWnd.nut"

  "%scripts/flightMenu/flightMenu.nut"
  "%scripts/misCustomRules/missionCustomState.nut"
  "%scripts/statistics/mpStatistics.nut"
  "%scripts/statistics/mpStatisticsModal.nut"
  "%scripts/respawn/misLoadingState.nut"
  "%scripts/respawn/respawn.nut"
  "%scripts/respawn/teamUnitsLeftView.nut"
  "%scripts/misObjectives/objectiveStatus.nut"
  "%scripts/misObjectives/misObjectivesView.nut"
  "%scripts/tacticalMap.nut"

  "%scripts/debriefing/debriefingModal.nut"
  "%scripts/debriefing/tournamentRewardReceivedModal.nut"
  "%scripts/mainmenu/benchmarkResultModal.nut"

  "%scripts/clans/clanType.nut"
  "%scripts/clans/clanLogType.nut"
  "%scripts/clans/clans.nut"
  "%scripts/clans/clanSeasons.nut"
  "%scripts/clans/clanTagDecorator.nut"
  "%scripts/clans/modify/modifyClanModalHandler.nut"
  "%scripts/clans/modify/createClanModalHandler.nut"
  "%scripts/clans/modify/editClanModalhandler.nut"
  "%scripts/clans/modify/upgradeClanModalHandler.nut"
  "%scripts/clans/clanChangeMembershipReqWnd.nut"
  "%scripts/clans/clanPageModal.nut"
  "%scripts/clans/clansModalHandler.nut"
  "%scripts/clans/clanChangeRoleModal.nut"
  "%scripts/clans/clanBlacklistModal.nut"
  "%scripts/clans/clanActivityModal.nut"
  "%scripts/clans/clanAverageActivityModal.nut"
  "%scripts/clans/clanRequestsModal.nut"
  "%scripts/clans/clanLogModal.nut"
  "%scripts/clans/clanSeasonInfoModal.nut"
  "%scripts/clans/clanSquadsModal.nut"
  "%scripts/clans/clanSquadInfoWnd.nut"

  "%scripts/penitentiary/banhammer.nut"
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
  "%scripts/items/trophyReward.nut"
  "%scripts/items/trophyGroupShopWnd.nut"
  "%scripts/items/trophyRewardWnd.nut"
  "%scripts/items/trophyRewardList.nut"
  "%scripts/items/everyDayLoginAward.nut"
  "%scripts/items/orderAwardMode.nut"
  "%scripts/items/orderType.nut"
  "%scripts/items/orderUseResult.nut"
  "%scripts/items/orders.nut"
  "%scripts/items/orderActivationWindow.nut"

  "%scripts/userLog/userlogData.nut"
  "%scripts/userLog/userlogViewData.nut"
  "%scripts/userLog/userLog.nut"

  "%scripts/crew/crewShortCache.nut"
  "%scripts/crew/skillParametersRequestType.nut"
  "%scripts/crew/skillParametersColumnType.nut"
  "%scripts/crew/crewModalHandler.nut"
  "%scripts/crew/skillsPageStatus.nut"
  "%scripts/crew/crewPoints.nut"
  "%scripts/crew/crewBuyPointsHandler.nut"
  "%scripts/crew/crewUnitSpecHandler.nut"
  "%scripts/crew/crewSkillsPageHandler.nut"
  "%scripts/crew/crewSpecType.nut"
  "%scripts/crew/crew.nut"
  "%scripts/crew/crewSkills.nut"
  "%scripts/crew/unitCrewCache.nut"
  "%scripts/crew/crewSkillParameters.nut"
  "%scripts/crew/skillParametersType.nut"
  "%scripts/crew/crewTakeUnitProcess.nut"

  "%scripts/slotbar/slotbarPresets.nut"
  "%scripts/slotbar/slotbarPresetsWnd.nut"
  "%scripts/vehicleRequireFeatureWindow.nut"
  "%scripts/slotbar/slotbarPresetsTutorial.nut"
  "%scripts/slotInfoPanel.nut"
  "%scripts/unit/unitInfoType.nut"
  "%scripts/unit/unitInfoExporter.nut"

  "%scripts/hud/hudEventManager.nut"
  "%scripts/hud/hudVisMode.nut"
  "%scripts/hud/baseUnitHud.nut"
  "%scripts/hud/hud.nut"
  "%scripts/hud/hudActionBarType.nut"
  "%scripts/hud/hudActionBar.nut"
  "%scripts/replays/spectator.nut"
  "%scripts/hud/hudTankDebuffs.nut"
  "%scripts/hud/hudDisplayTimers.nut"
  "%scripts/hud/hudCrewState.nut"
  "%scripts/hud/hudEnemyDebuffsType.nut"
  "%scripts/hud/hudEnemyDamage.nut"
  "%scripts/hud/hudRewardMessage.nut"
  "%scripts/hud/hudMessages.nut"
  "%scripts/hud/hudMessageStack.nut"
  "%scripts/hud/hudBattleLog.nut"
  "%scripts/hud/hudLiveStats.nut"
  "%scripts/hud/hudTutorialElements.nut"
  "%scripts/hud/hudTutorialObject.nut"
  "%scripts/streaks.nut"
  "%scripts/wheelmenu/voicemenu.nut"
  "%scripts/wheelmenu/multifuncmenu.nut"
  "%scripts/hud/hudHintTypes.nut"
  "%scripts/hud/hudHints.nut"
  "%scripts/hud/hudHintsManager.nut"

  "%scripts/warbonds/warbondAwardType.nut"
  "%scripts/warbonds/warbondAward.nut"
  "%scripts/warbonds/warbond.nut"
  "%scripts/warbonds/warbondsManager.nut"
  "%scripts/warbonds/warbondsView.nut"
  "%scripts/warbonds/warbondShop.nut"

  "%scripts/statsd/missionStats.nut"
  "%scripts/utils/popupMessages.nut"
  "%scripts/utils/soundManager.nut"
  "%scripts/fileDialog/fileDialog.nut"
  "%scripts/fileDialog/saveDataDialog.nut"
  "%scripts/controls/controlsBackupManager.nut"

  "%scripts/matching/serviceNotifications/match.nut"
  "%scripts/matching/serviceNotifications/mlogin.nut"
  "%scripts/matching/serviceNotifications/mrpc.nut"
  "%scripts/matching/serviceNotifications/msquad.nut"

  "%scripts/gamepadSceneSettings.nut"
]) {
  loadOnce(fn)
}

require("%scripts/controls/controlsFootballNy2021Hack.nut")
require("%scripts/slotbar/elems/unlockMarkerElem.nut")
require("%scripts/items/trophyShowTime.nut")
require("%scripts/dlcontent/dlContent.nut")
require("%scripts/dynamic/mainMissionGenerator.nut")
require("%scripts/mainmenu/hideMainMenuUi.nut")
require("%scripts/wheelmenu/chooseVehicleWheelMenu.nut")
require("%scripts/login/loginContacts.nut")
require("%scripts/mainmenu/onMainMenuReturn.nut")

require("%scripts/debugTools/dbgCheckContent.nut")
require("%scripts/debugTools/dbgUnlocks.nut")
require("%scripts/debugTools/dbgClans.nut")
require("%scripts/debugTools/dbgHudObjects.nut")
require("%scripts/debugTools/dbgVoiceChat.nut")


if (::g_login.isAuthorized() || ::disable_network()) //load scripts from packs only after login
  loadIfExist("%scripts/worldWar/worldWar.nut")
