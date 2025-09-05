from "app" import is_dev_version
from "%scripts/dagui_natives.nut" import stop_gui_sound, show_highlights, get_premium_reward_wp, is_online_available, start_gui_sound, set_presence_to_player, get_session_warpoints, set_char_cb, is_highlights_inited, get_premium_reward_xp, purchase_entitlement_and_get_award, get_mission_progress
from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/debriefing/debriefingConsts.nut" import debrState
from "%scripts/items/itemsConsts.nut" import itemsTab, itemType
from "%scripts/social/psConsts.nut" import bit_activity, ps4_activity_feed
from "chard" import save_profile

let { USERLOG_POPUP } = require("%scripts/userLog/userlogConsts.nut")
let { getSessionLobbyMissionName } = require("%scripts/missions/missionsUtilsModule.nut")
let { HudBattleLog } = require("%scripts/hud/hudBattleLog.nut")
let { eventbus_subscribe } = require("eventbus")
let { deferOnce } = require("dagor.workcycle")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { get_pve_trophy_name, get_mission_mode } = require("%appGlobals/ranks_common_shared.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { toPixels, move_mouse_on_child } = require("%sqDagui/daguiUtil.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let DataBlock = require("DataBlock")
let { format, split_by_chars } = require("string")
let { ceil, floor } = require("math")
let stdMath = require("%sqstd/math.nut")
let time = require("%scripts/time.nut")
let { get_game_version, get_game_version_str } = require("app")
let { is_mplayer_host } = require("multiplayer")
let workshop = require("%scripts/items/workshop/workshop.nut")
let { updateModItem } = require("%scripts/weaponry/weaponryVisual.nut")
let workshopPreview = require("%scripts/items/workshop/workshopPreview.nut")
let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let { getShopPriceBlk } = require("%scripts/onlineShop/onlineShopState.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { setDoubleTextToButton, setColoredDoubleTextToButton,
  placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isModResearched, getModificationByName, findAnyNotResearchedMod
} = require("%scripts/weaponry/modificationInfo.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { needLogoutAfterSession, startLogout } = require("%scripts/login/logout.nut")
let activityFeedPostFunc = require("%scripts/social/activityFeed/activityFeedPostFunc.nut")
let { MODIFICATION } = require("%scripts/weaponry/weaponryTooltips.nut")
let { getBoostersEffects, getActiveBoostersDescription } = require("%scripts/items/boosterEffect.nut")
let { boosterEffectType } = require("%scripts/items/boosterEffectTypes.nut")
let { fillItemDescr } = require("%scripts/items/itemVisual.nut")
let { getToBattleLocId } = require("%scripts/viewUtils/interfaceCustomization.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { setNeedShowRate } = require("%scripts/user/suggestionRateGame.nut")
let { sourcesConfig } = require("%scripts/debriefing/rewardSources.nut")
let { minValuesToShowRewardPremium, MAX_COUNTRY_RANK
} = require("%scripts/ranks.nut")
let { getDebriefingResult, getDynamicResult, debriefingRows, isDebriefingResultFull,
  gatherDebriefingResult, getCountedResultId, debriefingAddVirtualPremAcc, getTableNameById,
  updateDebriefingResultGiftItemsInfo, setDebriefingResult, rewardsBonusTypes
} = require("%scripts/debriefing/debriefingFull.nut")
let { isMissionExtrByName, selectNextAvailCampaignMission,
  addMissionListFull } = require("%scripts/missions/missionsUtils.nut")
let { locCurrentMissionName } = require("%scripts/missions/missionsText.nut")
let { needCheckForVictory, guiStartMenuCampaign, guiStartMenuSingleMissions,
  guiStartMenuUserMissions, guiStartDynamicSummary, guiStartDynamicSummaryF
} = require("%scripts/missions/startMissionsList.nut")
let { getTournamentRewardData, getUserLogsList } = require("%scripts/userLog/userlogUtils.nut")
let { goToBattleAction,
  openLastTournamentWnd } = require("%scripts/debriefing/toBattleAction.nut")
let { checkRankUpWindow } = require("%scripts/debriefing/checkRankUpWindow.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { havePremium, getRemainingPremiumTime } = require("%scripts/user/premium.nut")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")
let { hasEveryDayLoginAward } = require("%scripts/items/everyDayLoginAward.nut")
let { is_replay_turned_on, is_replay_saved, is_replay_present,
  on_save_replay, on_view_replay } = require("replays")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { is_benchmark_game_mode, get_game_mode, get_cur_game_mode_name, GET_MPLAYERS_LIST
} = require("mission")
let { MISSION_STATUS_RUNNING, select_mission_full, stat_get_benchmark } = require("guiMission")
let { openBattlePassWnd } = require("%scripts/battlePass/battlePassWnd.nut")
let { dynamicGetLayout, dynamicGetList } = require("dynamicMission")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { stripTags, capitalize } = require("%sqstd/string.nut")
let { reqUnlockByClient, getFakeUnlockData, combineSimilarAwards
} = require("%scripts/unlocks/unlocksModule.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { sendFinishTestFlightToBq } = require("%scripts/missionBuilder/testFlightBQInfo.nut")
let { isBattleTask, isSpecialBattleTask, isBattleTasksAvailable, isBattleTaskDone,
  getBattleTaskRerollCost, canGetBattleTaskReward, canGetAnyBattleTaskReward,
  getBattleTaskById, getCurBattleTasksByGm, requestBattleTaskReward,
  rerollBattleTask, rerollSpecialTask, getBattleTaskNameById
} = require("%scripts/unlocks/battleTasks.nut")
let { setBattleTasksUpdateTimer, getBattleTaskView, mkUnlockConfigByBattleTask
} = require("%scripts/unlocks/battleTasksView.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { blendProp } = require("%sqDagui/guiBhv/guiBhvUtils.nut")
let { create_ObjMoveToOBj } = require("%sqDagui/guiBhv/bhvAnim.nut")
let { getUnitName, image_for_air } = require("%scripts/unit/unitInfo.nut")
let { isUnitInResearch } = require("%scripts/unit/unitStatus.nut")
let { get_current_mission_info_cached, get_warpoints_blk, get_ranks_blk, get_game_settings_blk
} = require("blkGetters")
let { isInSessionRoom, sessionLobbyStatus, hasSessionInLobby, getSessionLobbyMissionData,
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { getPlayerRankByCountry, getPlayerExpByCountry, playerRankByCountries
} = require("%scripts/user/userInfoStats.nut")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { openTrophyRewardsList } = require("%scripts/items/trophyRewardList.nut")
let { WwBattleResults } = require("%scripts/worldWar/inOperation/model/wwBattleResults.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { launchOnlineShop } = require("%scripts/onlineShop/onlineShopModel.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let { isCountryAvailable, unlockCountry } = require("%scripts/firstChoice/firstChoice.nut")
let { get_last_called_gui_testflight } = require("%scripts/missionBuilder/testFlightState.nut")
let { eventsTableConfig } = require("%scripts/leaderboard/leaderboardCategoryType.nut")
let { isNewbieInited, getMissionsComplete, isMeNewbie, markStatsReset
} = require("%scripts/myStats.nut")
let { findItemByUid, getInventoryItemById, findItemById } = require("%scripts/items/itemsManager.nut")
let { getUnlockIconConfig, buildConditionsConfig } = require("%scripts/unlocks/unlocksViewModule.nut")
let { gui_start_mainmenu, gui_start_mainmenu_reload
} = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { gui_start_decals } = require("%scripts/customization/contentPreview.nut")
let { gui_start_items_list } = require("%scripts/items/startItemsShop.nut")
let { closeCurVoicemenu } = require("%scripts/wheelmenu/voiceMessages.nut")
let { autosaveReplay, guiModalNameAndSaveReplay } = require("%scripts/replays/replayScreen.nut")
let { guiStartOpenTrophy } = require("%scripts/items/trophyRewardWnd.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getTooltipObjId } = require("%scripts/utils/genericTooltip.nut")
let { invalidateCrewsList } = require("%scripts/slotbar/crewsList.nut")
let { canOpenHitsAnalysisWindow, openHitsAnalysisWindow } = require("%scripts/dmViewer/hitsAnalysis.nut")
let { getLbDiff, getLeaderboardItemView, getLeaderboardItemWidgets
} = require("%scripts/leaderboard/leaderboardHelpers.nut")
let { isWorldWarEnabled, saveLastPlayed } = require("%scripts/globalWorldWarScripts.nut")
let { isLoggedIn, isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { updateOperationPreviewAndDo, openOperationsOrQueues, isLastFlightWasWwBattle,
  openWWMainWnd } = require("%scripts/globalWorldwarUtils.nut")
let { currentCampaignId, currentCampaignMission, get_mission_settings, get_mutable_mission_settings, set_mission_settings,
  is_user_mission, isCustomMissionFlight
} = require("%scripts/missions/missionsStates.nut")
let { checkNonApprovedResearches } = require("%scripts/researches/researchActions.nut")
let { gui_modal_userCard } = require("%scripts/user/userCard/userCardView.nut")
let { haveLobby } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { isUsedPlayersOwnUnit } = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")
let { getCurMpTitle, getLocalTeamForMpStats } = require("%scripts/statistics/mpStatisticsUtil.nut")
let { showUnlockWnd } = require("%scripts/unlocks/showUnlockWnd.nut")
let { getWPIcon, getPrizeImageByConfig } = require("%scripts/items/prizesView.nut")
let { fill_unlock_block, build_log_unlock_data,
  build_unlock_tooltip_by_config } = require("%scripts/unlocks/unlocks.nut")
let { showSessionPlayerRClickMenu } = require("%scripts/user/playerContextMenu.nut")
let { isAnyQueuesActive } = require("%scripts/queue/queueState.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")
let { isFirstGeneration } = require("%scripts/missions/dynCampaingState.nut")
let { guiStartMpLobby, goForwardSessionLobbyAfterDebriefing, checkLeaveRoomInDebriefing
} = require("%scripts/matchingRooms/sessionLobbyManager.nut")
let { updateMyCountryData } = require("%scripts/squads/squadUtils.nut")
let destroySessionScripted = require("%scripts/matchingRooms/destroySessionScripted.nut")
let { disableNetwork } = require("%globalScripts/clientState/initialState.nut")
let { MIS_PROGRESS } = require("%scripts/missions/missionProgress.nut")

const DEBR_LEADERBOARD_LIST_COLUMNS = 2
const DEBR_AWARDS_LIST_COLUMNS = 3
const DEBR_MYSTATS_TOP_BAR_GAP_MAX = 6
const LAST_WON_VERSION_SAVE_ID = "lastWonInVersion"
const VISIBLE_GIFT_NUMBER = 4
const KG_TO_TONS = 0.001
const NOTIFY_EXPIRE_PREMIUM_ACCOUNT = 15

enum DEBR_THEME {
  WIN       = "win"
  LOSE      = "lose"
  PROGRESS  = "progress"
}

let statTooltipColumnParamByType = {
  time = @(rowConfig) {
    pId = rowConfig.hideUnitSessionTimeInTooltip ? "" : "sessionTime"
    paramType = "tim"
    showEmpty = !rowConfig.hideUnitSessionTimeInTooltip
  }
  value = @(rowConfig) {
    pId = rowConfig.customValueName ?? $"{rowConfig.rowType}{rowConfig.id}"
    paramType = rowConfig.rowType
  }
  reward = @(rowConfig) {
    pId = $"{rowConfig.rewardType}{rowConfig.id}"
    paramType = rowConfig.rewardType
  }
  info = @(rowConfig) {
    pId = rowConfig?.infoName ?? ""
    paramType = rowConfig?.infoType ?? ""
  }
}

let viewByRowType = {
   wp = {
     image = "#ui/gameuiskin#item_type_warpoints.svg"
     getText = @(value) Cost(value).toStringWithParams({ isWpAlwaysShown = true, needIcon = false })
   }
   gold = {
     image = "#ui/gameuiskin#item_type_eagles.svg"
     getText = @(value) Cost(0, value).toStringWithParams({ isGoldAlwaysShown = true, needIcon = false })
   }
   exp = {
     image = "#ui/gameuiskin#item_type_RP.svg"
     getText = @(value) Cost().setRp(value).toStringWithParams({ needIcon = false })
   }
   frp = {
     image = "#ui/gameuiskin#item_type_Free_RP.svg"
     getText = @(value) Cost().setFrp(value).toStringWithParams({ needIcon = false })
   }
   num = {
     getText = @(value) value.tostring()
   }
   sec = {
     getText = @(value) $"{value}{loc("debriefing/timeSec")}"
   }
   mul = {
     getText = @(value) $"x{value}"
   }
   pct = {
     getText = @(value) $"{(100.0 * value + 0.5).tointeger()}%"
   }
   tim = {
     getText = @(value) time.secondsToString(value, false)
   }
   ptm = {
     getText = @(value) time.getRaceTimeFromSeconds(value)
   }
   tnt = {
     getText = @(value) stdMath.roundToDigits(value * KG_TO_TONS, 3).tostring()
   }
}

function getViewByType(value, paramType, showEmpty = false) {
  if (!showEmpty && (value == 0 || (value == 1 && paramType == "mul")))
    return {
      text = ""
      image = ""
    }

  let text = viewByRowType?[paramType].getText(value) ?? ""
  return {
    text
    image = text == "" ? "" : viewByRowType?[paramType].image ?? ""
  }
}

function checkRemnantPremiumAccount() {
  if (!isProfileReceived.get() || !hasFeature("EnablePremiumPurchase")
      || !hasFeature("SpendGold"))
    return

  let currDays = time.getUtcDays()
  let expire = getRemainingPremiumTime()
  if (expire > 0)
    saveLocalByAccount("premium/lastDayHavePremium", currDays)
  if (expire >= NOTIFY_EXPIRE_PREMIUM_ACCOUNT)
    return

  let lastDaysReminder = loadLocalByAccount("premium/lastDayBuyPremiumReminder", 0)
  if (lastDaysReminder == currDays)
    return

  let lastDaysHavePremium = loadLocalByAccount("premium/lastDayHavePremium", 0)
  local msgText = ""
  if (expire > 0)
    msgText = loc("msgbox/ending_premium_account")
  else if (lastDaysHavePremium != 0) {
    let deltaDaysReminder = currDays - lastDaysReminder
    let deltaDaysHavePremium = currDays - lastDaysHavePremium
    let gmBlk = get_game_settings_blk()
    let daysCounter = gmBlk?.reminderBuyPremiumDays ?? 7
    if (2 * deltaDaysReminder >= deltaDaysHavePremium || deltaDaysReminder >= daysCounter)
      msgText = loc("msgbox/ended_premium_account")
  }

  if (msgText != "") {
    saveLocalByAccount("premium/lastDayBuyPremiumReminder", currDays)
    scene_msg_box("no_premium", null,  msgText,
          [
            ["ok", @() launchOnlineShop(null, "premium")],
            ["cancel", @() null ]
          ], "ok",
          { saved = true })
  }
}

local goDebriefingNextFunc = null

function guiStartDebriefingFull(params = {}) {
  loadHandler(gui_handlers.DebriefingModal, params)
}

function gui_start_debriefing(_) {
  if (needLogoutAfterSession.get()) {
    destroySessionScripted("on needLogoutAfterSession from gui_start_debriefing")
    
    deferOnce(startLogout)
    return
  }

  let gm = get_game_mode()
  if (::back_from_replays != null) {
     log("gui_nav gui_start_debriefing back_from_replays");
     let temp_func = ::back_from_replays
     log("gui_nav back_from_replays = null");
     ::back_from_replays = null
     temp_func()
     updateGamercards()
     return
  }
  else
    log("gui_nav gui_start_debriefing back_from_replays is null");

  if (is_benchmark_game_mode()) {
    let title = locCurrentMissionName()
    let benchmark_data = stat_get_benchmark()
    gui_start_mainmenu()
    loadHandler(gui_handlers.BenchmarkResultModal, { title = title benchmark_data = benchmark_data })
    return
  }
  if (gm == GM_CREDITS || gm == GM_TRAINING) {
     gui_start_mainmenu()
     return
  }
  if (gm == GM_TEST_FLIGHT) {
    sendFinishTestFlightToBq()
    if (get_last_called_gui_testflight() != null)
      handlersManager.callStartFunc(get_last_called_gui_testflight())
    else
      gui_start_decals()
    updateGamercards()
    return
  }
  if (isCustomMissionFlight.get()) {
    isCustomMissionFlight.set(false)
    gui_start_mainmenu()
    return
  }

  guiStartDebriefingFull()
}

eventbus_subscribe("gui_start_debriefing", gui_start_debriefing)

gui_handlers.DebriefingModal <- class (gui_handlers.MPStatistics) {
  sceneBlkName = "%gui/debriefing/debriefing.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  static awardsListsConfig = {
    streaks = {
      filter = {
          show = [EULT_NEW_STREAK]
          unlocks = [UNLOCKABLE_STREAK]
          filters = { popupInDebriefing = [false, null] }
          currentRoomOnly = true
          disableVisible = true
        }
      align = ALIGN.TOP
      listObjId = "awards_list_streaks"
      startplaceObId = "start_award_place_streaks"
    }
    challenges = {
      filter = {
        show = [EULT_NEW_UNLOCK]
        unlocks = [UNLOCKABLE_CHALLENGE, UNLOCKABLE_ACHIEVEMENT]
        filters = { popupInDebriefing = [false, null] }
        currentRoomOnly = true
        disableVisible = true
        checkFunc = function(userlog) { return getUnlockById(userlog.body.unlockId)?.battlePassSeason != null }
      }
      align = ALIGN.CENTER
      listObjId = "awards_list_challenges"
      startplaceObId = "start_award_place_unlocks"
    }
    unlocks = {
      filter = {
        show = [EULT_NEW_UNLOCK]
        unlocks = [UNLOCKABLE_AIRCRAFT, UNLOCKABLE_SKIN, UNLOCKABLE_DECAL, UNLOCKABLE_ATTACHABLE,
                   UNLOCKABLE_WEAPON, UNLOCKABLE_DIFFICULTY, UNLOCKABLE_ENCYCLOPEDIA, UNLOCKABLE_PILOT,
                   UNLOCKABLE_MEDAL, UNLOCKABLE_CHALLENGE, UNLOCKABLE_ACHIEVEMENT, UNLOCKABLE_TITLE, UNLOCKABLE_AWARD]
        filters = { popupInDebriefing = [false, null] }
        currentRoomOnly = true
        disableVisible = true
        checkFunc = function(userlog) { return getUnlockById(userlog.body.unlockId)?.battlePassSeason == null }
      }
      align = ALIGN.TOP
      listObjId = "awards_list_unlocks"
      startplaceObId = "start_award_place_unlocks"
    }
  }

  static armyStateAfterBattle = {
    EASAB_UNKNOWN = "unknown"
    EASAB_UNCHANGED = "unchanged"
    EASAB_RETREATING = "retreating"
    EASAB_DEAD = "dead"
  }

  isTeamplay = false
  isSpectator = false
  gameType = null
  gm = null
  roomEvent = null
  playersInfo = null 

  pveRewardInfo = null
  battleTasksConfigs = {}
  battleTasksConfigsSorted = []
  shouldBattleTasksListUpdate = false

  giftItems = null
  isAllGiftItemsKnown = false

  isFirstWinInMajorUpdate = false

  debugUnlocks = 0  
  debriefingResult = null

  callbackOnDebriefingClose = null

  function initScreen() {
    this.debriefingResult = getDebriefingResult()
    if (this.debriefingResult == null) {
      script_net_assert_once("not inited debriefing result", "try to get debriefing data")
      gatherDebriefingResult()
      this.debriefingResult = getDebriefingResult()
    }
    this.gm = this.debriefingResult.gm
    this.roomEvent = this.debriefingResult.roomEvent
    this.gameType = this.debriefingResult.gameType
    this.isTeamplay = this.debriefingResult.isTeamplay
    this.isSpectator = this.debriefingResult.isSpectator
    this.playersInfo = this.debriefingResult.playersInfo
    this.isMp = this.debriefingResult.isMp
    this.isReplay = this.debriefingResult.isReplay
    this.isCurMissionExtr = isMissionExtrByName(this.debriefingResult?.roomEvent.name ?? "")

    if (disableNetwork) 
      updateGamercards()

    this.showTab("") 

    set_presence_to_player("menu")
    this.initStatsMissionParams()
    checkLeaveRoomInDebriefing()
    closeCurVoicemenu()

    
    
    this.guiScene.performDelayed(this, function() { handlersManager.updateSceneBgBlur(true) })

    if (this.isInited)
      this.scene.findObject("debriefing_timer").setUserData(this)

    this.playerStatsObj = this.scene.findObject("stat_table")
    this.numberOfWinningPlaces = getTblValue("numberOfWinningPlaces", this.debriefingResult, -1)
    this.pveRewardInfo = getTblValue("pveRewardInfo", this.debriefingResult)
    this.giftItems = this.groupGiftsById(this.debriefingResult?.giftItemsInfo)
    foreach (idx, row in debriefingRows)
      if (row.show) {
        this.curStatsIdx = idx
        break
      }

    this.handleActiveWager()
    this.handlePveReward()

    
    local resTitle = ""
    let resReward = {
      title = ""
      textWp = ""
      textRp = ""
    }
    local resTheme = DEBR_THEME.PROGRESS

    if (this.isMp) {
      let mpResult = this.debriefingResult.exp.result
      resTitle = loc("MISSION_IN_PROGRESS")

      if (this.isSpectator
           && (this.gameType & GT_VERSUS)
           && (mpResult == STATS_RESULT_SUCCESS
                || mpResult == STATS_RESULT_FAIL)) {
        if (this.isTeamplay) {
          local myTeam = Team.A
          foreach (player in this.debriefingResult.mplayers_list)
            if (getTblValue("isLocal", player, false)) {
              myTeam = player.team
              break
            }
          let winner = ((myTeam == Team.A) == this.debriefingResult.isSucceed) ? "A" : "B"
          resTitle = "".concat(loc("multiplayer/team_won"), loc("ui/colon"),
            loc($"multiplayer/team{winner}"))
          resTheme = DEBR_THEME.WIN
        }
        else {
          resTitle = loc("MISSION_FINISHED")
          resTheme = DEBR_THEME.WIN
        }
      }
      else if (mpResult == STATS_RESULT_SUCCESS) {
        resTitle = this.isCurMissionExtr ? loc("MISSION_FINISHED") : loc("MISSION_SUCCESS")
        resTheme = DEBR_THEME.WIN

        let victoryBonus = (!this.isCurMissionExtr && this.isMp && isDebriefingResultFull())
          ? this.getMissionBonus() : {}
        if ((victoryBonus?.textWp ?? "") != "" || (victoryBonus?.textRp ?? "") != "") {
          resReward.__update(victoryBonus)
          resReward.title = "".concat(loc("debriefing/MissionWinReward"), loc("ui/colon"))
        }

        let currentMajorVersion = get_game_version() >> 16
        let lastWinVersion = loadLocalAccountSettings(LAST_WON_VERSION_SAVE_ID, 0)
        this.isFirstWinInMajorUpdate = currentMajorVersion > lastWinVersion
        saveLocalAccountSettings(LAST_WON_VERSION_SAVE_ID, currentMajorVersion)
      }
      else if (mpResult == STATS_RESULT_FAIL) {
        resTitle = this.isCurMissionExtr ? loc("MISSION_FINISHED") : loc("MISSION_FAIL")
        resTheme = DEBR_THEME.LOSE

        let loseBonus = (!this.isCurMissionExtr && this.isMp && isDebriefingResultFull()) ? this.getMissionBonus() : {}
        if ((loseBonus?.textWp ?? "") != "" || (loseBonus?.textRp ?? "") != "") {
          resReward.__update(loseBonus)
          resReward.title = "".concat(loc("debriefing/MissionLoseReward"), loc("ui/colon"))
        }
      }
      else if (mpResult == STATS_RESULT_ABORTED_BY_KICK) {
        resReward.title = colorize("badTextColor", loc("MISSION_ABORTED_BY_KICK"))
        resTheme = DEBR_THEME.LOSE
      }
      else if (mpResult == STATS_RESULT_ABORTED_BY_ANTICHEAT) {
        resReward.title = colorize("badTextColor", this.getKickReasonLocText())
        resTheme = DEBR_THEME.LOSE
      }
    }
    else {
      resTitle = this.isCurMissionExtr
        ? loc("MISSION_FINISHED")
        : loc(this.debriefingResult.isSucceed ? "MISSION_SUCCESS" : "MISSION_FAIL")
      resTheme = this.debriefingResult.isSucceed ? DEBR_THEME.WIN : DEBR_THEME.LOSE
    }

    this.scene.findObject("result_title").setValue(resTitle)
    let rewardObj = this.scene.findObject("result_reward_title")
    rewardObj.setValue(resReward.title)
    let { textWp, textRp } = resReward
    let isVisibleWp = textWp != ""
    let isVisibleRp = textRp != ""
    let wpRewardObj = showObjById("result_reward_wp", isVisibleWp, this.scene)
    if (isVisibleWp)
      wpRewardObj.findObject("text").setValue(textWp)
    let rpRewardObj = showObjById("result_reward_rp", isVisibleRp, this.scene)
    if (isVisibleRp)
      rpRewardObj.findObject("text").setValue(textRp)
    showObjById("result_reward_comma", isVisibleWp && isVisibleRp, this.scene)

    this.gatherAwardsLists()

    
    this.needPlayersTbl = this.isMp && !(this.gameType & GT_COOPERATIVE) && isDebriefingResultFull()
    this.setSceneTitle(getCurMpTitle(), null, "dbf_title")

    if (!isDebriefingResultFull()) {
      foreach (tName in ["no_air_text", "research_list_text"]) {
        let obj = this.scene.findObject(tName)
        if (checkObj(obj))
          obj.setValue(loc("MISSION_IN_PROGRESS"))
      }
    }

    if (!this.isReplay) {
      this.setGoNext()
      if (this.gm == GM_DYNAMIC) {
        save_profile(true)
        if (getDynamicResult() > MISSION_STATUS_RUNNING)
          destroySessionScripted("on iniScreen debriefing on finish dynCampaign")
        else
          g_squad_manager.setReadyFlag(true)
      }
    }
    isFirstGeneration.value = false 
    this.isInited = false
    ::check_logout_scheduled()

    updateMyCountryData() 

    this.handleNoAwardsCaption()

    if (!this.isSpectator && !this.isReplay)
      sendBqEvent("CLIENT_BATTLE_2", "show_debriefing_screen", {
        gm = this.gm
        economicName = getEventEconomicName(this.roomEvent)
        difficulty = this.roomEvent?.difficulty ?? getSessionLobbyMissionData()?.difficulty ?? ""
        sessionId = this.debriefingResult?.sessionId ?? ""
        sessionTime = this.debriefingResult?.exp.sessionTime ?? 0
        originalMissionName = getSessionLobbyMissionName(true)
        missionsComplete = getMissionsComplete()
        result = resTheme
      })
    let sessionIdObj = this.scene.findObject("txt_session_id")
    if (sessionIdObj?.isValid())
      sessionIdObj.setValue(this.debriefingResult?.sessionId ?? "")

    markStatsReset()
  }

  function gatherAwardsLists() {
    this.awardsList = []

    this.streakAwardsList = this.getAwardsList(this.awardsListsConfig.streaks.filter)

    let wpBattleTrophy = getTblValue("wpBattleTrophy", this.debriefingResult.exp, 0)
    if (wpBattleTrophy > 0)
      this.streakAwardsList.append(this.getFakeUnlockDataByWpBattleTrophy(wpBattleTrophy))

    this.challengesAwardsList = this.getAwardsList(this.awardsListsConfig.challenges.filter)
    this.unlocksAwardsList = this.getAwardsList(this.awardsListsConfig.unlocks.filter)

    showObjectsByTable(this.scene, {
      [this.awardsListsConfig.streaks.listObjId] = this.streakAwardsList.len() > 0,
      [this.awardsListsConfig.challenges.listObjId] = this.challengesAwardsList.len() > 0,
      [this.awardsListsConfig.unlocks.listObjId] = this.unlocksAwardsList.len() > 0,
    })

    if(this.unlocksAwardsList.len() == 0) {
      let listObj = this.scene.findObject(this.awardsListsConfig.streaks.listObjId)
      listObj["margin-left"] = "pw/2 - w/2"
    }

    if(this.streakAwardsList.len() == 0) {
      let listObj = this.scene.findObject(this.awardsListsConfig.unlocks.listObjId)
      listObj["margin-left"] = "pw/2 - w/2"
    }

    this.awardsList.extend(this.streakAwardsList)
    this.awardsList.extend(this.challengesAwardsList)
    this.awardsList.extend(this.unlocksAwardsList)

    this.awardsData = []
    if (this.streakAwardsList.len() > 0)
      this.awardsData.append({
        list = this.streakAwardsList
        config = this.awardsListsConfig.streaks
      })

    if (this.unlocksAwardsList.len() > 0)
      this.awardsData.append({
        list = this.unlocksAwardsList
        config = this.awardsListsConfig.unlocks
      })

    if (this.challengesAwardsList.len() > 0)
      this.awardsData.append({
        list = this.challengesAwardsList
        config = this.awardsListsConfig.challenges
      })

    if (this.awardsData.len() == 0)
      return

    let awardsItem = this.awardsData.pop()
    this.currentAwardsList = awardsItem.list
    this.currentAwardsListConfig = awardsItem.config
  }

  getFakeUnlockDataByWpBattleTrophy = @(wpBattleTrophy) getFakeUnlockData({
    iconStyle = getWPIcon(wpBattleTrophy)
    title = loc("debriefing/BattleTrophy"),
    desc = loc("debriefing/BattleTrophy/desc"),
    rewardText = Cost(wpBattleTrophy).toStringWithParams({ isWpAlwaysShown = true }),
  })

  function getAwardsList(filter) {
    let res = []
    local logsList = getUserLogsList(filter)
    logsList = combineSimilarAwards(logsList)
    for (local i = logsList.len() - 1; i >= 0; i--)
      res.append(build_log_unlock_data(logsList[i]))

    
    if (!is_dev_version() || this.debugUnlocks <= res.len())
      return res

    let dbgFilter = clone filter
    dbgFilter.currentRoomOnly = false
    logsList = getUserLogsList(dbgFilter)
    if (!logsList.len()) {
      dlog("Not found any unlocks in userlogs for debug") 
      return res
    }

    let addAmount = this.debugUnlocks - res.len()
    for (local i = 0; i < addAmount; i++)
      res.append(build_log_unlock_data(logsList[i % logsList.len()]))

    return res
  }

  function handleNoAwardsCaption() {
    local text = ""
    local color = ""

    if (getTblValue("haveTeamkills", this.debriefingResult, false)) {
      text = loc("debriefing/noAwardsCaption")
      color = "bad"
    }
    else if (this.debriefingResult?.exp.eacKickMessage != null) {
      text = "".concat(this.getKickReasonLocText(), "\n",
        loc("multiplayer/reason"), loc("ui/colon"),
        colorize("activeTextColor", this.debriefingResult.exp.eacKickMessage))

      if (hasFeature("AllowExternalLink"))
        showObjById("btn_no_awards_info", true, this.scene)
      else
        text = "".concat(text, "\n",
          loc("msgbox/error_link_format_game"), loc("ui/colon"), loc("url/support/easyanticheat"))

      color = "bad"
    }
    else if (this.pveRewardInfo && this.pveRewardInfo.warnLowActivity) {
      text = loc("debriefing/noAwardsCaption/noMinActivity")
      color = "userlog"
    }

    if (text == "")
      return

    let blockObj = showObjById("no_awards_block", true, this.scene)
    let captionObj = blockObj && blockObj.findObject("no_awards_caption")
    if (!checkObj(captionObj))
      return
    captionObj.setValue(text)
    captionObj.overlayTextColor = color
  }

  function getKickReasonLocText() {
    return loc("MISSION_ABORTED_BY_KICK/AC")
  }

  function onNoAwardsInfoBtn() {
    if (this.debriefingResult?.exp.eacKickMessage != null)
      openUrl(loc("url/support/easyanticheat/kick_reasons"), false, false, "support_eac")
  }

  function reinitTotal() {
    if (this.isCurMissionExtr)
      return

    if (!this.is_show_my_stats())
      return

    if (this.state != debrState.showMyStats && this.state != debrState.showBonuses)
      return

    
    this.totalRow = this.getDebriefingRowById("Total")
    if (!this.totalRow)
      return

    let premTeaser = this.getPremTeaserInfo()

    this.totalCurValues = this.totalCurValues ?? {}
    this.totalTarValues = {}

    foreach (currency in [ "exp", "wp" ]) {
      foreach (suffix in [ "", "Teaser" ]) {
        let finalName = $"{currency}{suffix}"
        if (!(finalName in this.totalCurValues))
          this.totalCurValues[finalName] <- 0
      }

      let totalKey = getCountedResultId(this.totalRow, this.state, currency)
      this.totalCurValues[currency] <- getTblValue(currency, this.totalCurValues, 0)
      this.totalTarValues[currency] <- getTblValue(totalKey, this.debriefingResult.counted_result_by_debrState, 0)
      this.totalCurValues[$"{currency}Teaser"] <- getTblValue($"{currency}Teaser", this.totalCurValues, 0)
      this.totalTarValues[$"{currency}Teaser"] <- premTeaser[currency]
    }

    let canSuggestPrem = this.canSuggestBuyPremium()

    local tooltip = ""
    if (canSuggestPrem) {
      let currencies = []
      if (premTeaser.exp > 0)
        currencies.append(Cost().setRp(premTeaser.exp).tostring())
      if (premTeaser.wp  > 0)
        currencies.append(Cost(premTeaser.wp).tostring())
      tooltip = "".concat(loc("debriefing/PremiumNotEarned"), loc("ui/colon"), "\n",
        loc("ui/comma").join(currencies, true))
    }

    this.totalObj = this.scene.findObject("wnd_total")
    let markup = handyman.renderCached("%gui/debriefing/debriefingTotals.tpl", {
      showTeaser = canSuggestPrem && premTeaser.isPositive
      canSuggestPrem = canSuggestPrem
      exp = Cost().setRp(this.totalCurValues["exp"]).toStringWithParams({ needIcon = false })
      wp  = Cost(this.totalCurValues["wp"]).toStringWithParams({ needIcon = false })
      expTeaser = Cost().setRp(premTeaser.exp).toStringWithParams({ isColored = false, needIcon = false })
      wpTeaser  = Cost(premTeaser.wp).toStringWithParams({ isColored = false, needIcon = false })
      teaserTooltip = tooltip
    })
    this.guiScene.replaceContentFromText(this.totalObj, markup, markup.len(), this)
    this.updateTotal(0.0)
  }

  function handleActiveWager() {
    let activeWagerData = getTblValue("activeWager", this.debriefingResult, null)
    if (!activeWagerData)
      return

    let wager = findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
      findItemById(activeWagerData.wagerShopId)
    if (wager == null) 
      return

    let containerObj = this.scene.findObject("active_wager_container")
    if (!checkObj(containerObj))
      return

    containerObj.show(true)

    let iconObj = containerObj.findObject("active_wager_icon")
    if (checkObj(iconObj))
      wager.setIcon(iconObj)

    let wagerResult = activeWagerData.wagerResult
    let isWagerHasResult = wagerResult != null
    let isResultSuccess = wagerResult == "WagerWin" || wagerResult == "WagerStageWin"
    let isWagerEnded = wagerResult == "WagerWin" || wagerResult == "WagerFail"

    if (isWagerHasResult)
      this.showActiveWagerResultIcon(isResultSuccess)

    let tooltipObj = containerObj.findObject("active_wager_tooltip")
    if (checkObj(tooltipObj)) {
      tooltipObj.setUserData(activeWagerData)
      tooltipObj.enable(!isWagerEnded && isWagerHasResult)
    }

    if (!isWagerHasResult)
      containerObj.tooltip = loc("debriefing/wager_result_will_be_later")
    else if (isWagerEnded) {
      let endedWagerText = [
        activeWagerData.wagerText,
        loc("items/wager/numWins", {
          numWins = activeWagerData.wagerNumWins,
          maxWins = wager.maxWins
        }),
        loc("items/wager/numFails", {
          numFails = activeWagerData.wagerNumFails,
          maxFails = wager.maxFails
        })
      ]
      containerObj.tooltip = "\n".join(endedWagerText)
    }

    this.handleActiveWagerText(activeWagerData)
    this.updateMyStatsTopBarArrangement()
  }

  function handleActiveWagerText(activeWagerData) {
    let wager = findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
      findItemById(activeWagerData.wagerShopId)
    if (wager == null)
      return
    let wagerResult = activeWagerData.wagerResult
    if (wagerResult != "WagerWin" && wagerResult != "WagerFail")
      return
    let textObj = this.scene.findObject("active_wager_text")
    if (checkObj(textObj))
      textObj.setValue(activeWagerData.wagerText)
  }

  function onWagerTooltipOpen(obj) {
    if (!checkObj(obj))
      return
    let activeWagerData = obj.getUserData()
    if (activeWagerData == null)
      return
    let wager = findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
      findItemById(activeWagerData.wagerShopId)
    if (wager == null)
      return
    this.guiScene.replaceContent(obj, "%gui/items/itemTooltip.blk", this)
    fillItemDescr(wager, obj, this)
  }

  function showActiveWagerResultIcon(success) {
    let iconObj = this.scene.findObject("active_wager_result_icon")
    if (!checkObj(iconObj))
      return
    iconObj["background-image"] = success ? "#ui/gameuiskin#favorite" : "#ui/gameuiskin#icon_primary_fail.svg"
  }

  function handlePveReward() {
    let isVisible = !!this.pveRewardInfo && this.pveRewardInfo.isVisible

    showObjById("pve_trophy_block", isVisible, this.scene)
    if (! isVisible)
      return

    let trophyItemReached =  findItemById(this.pveRewardInfo.reachedTrophyName)
    let trophyItemReceived = findItemById(this.pveRewardInfo.receivedTrophyName)

    this.fillPveRewardProgressBar()
    this.fillPveRewardTrophyChest(trophyItemReached)
    this.fillPveRewardTrophyContent(trophyItemReceived, this.pveRewardInfo.isRewardReceivedEarlier)
  }

  function hasGiftItem() {
    if (!this.giftItems)
      return false

    foreach (itemData in this.giftItems) {
      let item = findItemById(itemData.item)
      if (item)
        return true
    }

    return false
  }

  function handleGiftItems() {
    if (!this.giftItems || this.isAllGiftItemsKnown)
      return

    if (this.isCurMissionExtr) {
      let resourcesObj = this.scene.findObject("full_width_resources")
      let view = { items = [] }
      foreach (itemData in this.giftItems) {
        let item = findItemById(itemData.item)
        if (!item)
          continue

        view.items.append(item.getViewData({
          count = itemData.count
          enableBackground = false
          border = true
          bigPicture = true
          margin = "4@blockInterval"
        }))
      }

      if (view.items.len() > 0) {
        let markup = handyman.renderCached("%gui/items/item.tpl", view)
        this.guiScene.replaceContentFromText(resourcesObj, markup, markup.len(), this)
      }
      return
    }

    let obj = this.scene.findObject("inventory_gift_icon")
    let leftBlockHeight = this.scene.findObject("left_block").getSize()[1]
    let itemHeight = toPixels(this.guiScene, "1@itemHeight")

    obj.smallItems = this.challengesAwardsList.len() > 0 ? "yes"
      : (itemHeight * this.giftItems.len() > leftBlockHeight / 2) ? "yes"
      : "no"

    local giftsMarkup = ""
    let showLen = min(this.giftItems.len(), VISIBLE_GIFT_NUMBER)
    this.isAllGiftItemsKnown = true
    for (local i = 0; i < showLen; i++) {
      let markup = getPrizeImageByConfig(this.giftItems[i], false)
      this.isAllGiftItemsKnown = this.isAllGiftItemsKnown && markup != ""
      giftsMarkup = $"{giftsMarkup}{markup}"
    }
    this.guiScene.replaceContentFromText(obj, giftsMarkup, giftsMarkup.len(), this)
  }

  function onEventItemsShopUpdate(_p) {
    if (this.state >= debrState.showMyStats)
      this.handleGiftItems()
    if (this.state >= debrState.done)
      this.updateInventoryButton()
  }

  function onViewRewards() {
    openTrophyRewardsList({ rewardsArray = this.giftItems })
  }

  function groupGiftsById(items) {
    if (!items)
      return null

    let res = [items[0]]
    for (local i = 1; i < items.len(); i++) {
      local isRepeated = false
      foreach (r in res)
        if (items[i].item == r.item) {
          r.count += items[i].count
          isRepeated = true
        }

      if (!isRepeated)
        res.append(items[i])
    }
    return res
  }

  function openGiftTrophy() {
    if (!this.giftItems?[0]?.needOpen)
      return

    let trophyItemId = this.giftItems[0].item
    let filteredLogs = getUserLogsList({
      show = [EULT_OPEN_TROPHY]
      currentRoomOnly = true
      disableVisible = true
      needStackItems = false
      checkFunc = function(userlog) { return trophyItemId == userlog.body.id }
    })

    if (filteredLogs.len() == 0)
      return

    guiStartOpenTrophy({ [trophyItemId] = filteredLogs })
    this.skipRoulette = true
  }

  function onEventTrophyContentVisible(params) {
    if (this.giftItems?[0].item && this.giftItems[0].item == params?.trophyItem.id)
      this.fillTrophyContentDiv(params.trophyItem, "inventory_gift_icon")
  }

  function fillPveRewardProgressBar() {
    let pveTrophyPlaceObj = showObjById("pve_trophy_progress", true, this.scene)
    if (!pveTrophyPlaceObj)
      return

    let receivedTrophyName = this.pveRewardInfo.receivedTrophyName
    let rewardTrophyStages = this.pveRewardInfo.stagesTime
    let showTrophiesOnBar  = ! this.pveRewardInfo.isRewardReceivedEarlier
    let maxValue = this.pveRewardInfo.victoryStageTime

    let stage = []

    foreach (_stageIndex, val in rewardTrophyStages) {
      let isVictoryStage = val == maxValue

      let text = isVictoryStage ? loc("debriefing/victory")
       : time.secondsToString(val, true, true)

      let trophyName = get_pve_trophy_name(val, isVictoryStage)
      let isReceivedInLastBattle = trophyName && trophyName == receivedTrophyName
      let trophy = showTrophiesOnBar && trophyName ?
        findItemById(trophyName) : null

      stage.append({
        posX = val.tofloat() / maxValue
        text = text
        trophy = trophy ? trophy.getNameMarkup(0, false) : null
        isReceived = isReceivedInLastBattle
      })
    }

    let view = {
      maxValue = maxValue
      value = 0
      stage = stage.len() > 0 ? stage : null
    }

    let data = handyman.renderCached("%gui/debriefing/pveReward.tpl", view)
    this.guiScene.replaceContentFromText(pveTrophyPlaceObj, data, data.len(), this)
  }

  function fillPveRewardTrophyChest(trophyItem) {
    let isVisible = !!trophyItem
    let trophyPlaceObj = showObjById("pve_trophy_chest", isVisible, this.scene)
    if (!isVisible || !trophyPlaceObj)
      return

    let imageData = trophyItem.getOpenedBigIcon()
    this.guiScene.replaceContentFromText(trophyPlaceObj, imageData, imageData.len(), this)
  }

  function fillPveRewardTrophyContent(trophyItem, isRewardReceivedEarlier) {
    showObjById("pve_award_already_received", isRewardReceivedEarlier, this.scene)
    this.fillTrophyContentDiv(trophyItem, "pve_trophy_content")
  }

  function fillTrophyContentDiv(trophyItem, containerObjId) {
    let trophyContentPlaceObj = showObjById(containerObjId, !!trophyItem, this.scene)
    if (!trophyItem || !trophyContentPlaceObj)
      return

    local layersData = ""
    let filteredLogs = getUserLogsList({
      show = [EULT_OPEN_TROPHY]
      currentRoomOnly = true
      needStackItems = false
      checkFunc = function(userlog) { return trophyItem.id == userlog.body.id }
    })

    foreach (logObj in filteredLogs) {
      let layer = getPrizeImageByConfig(logObj, false)
      if (layer != "") {
        layersData = $"{layersData}{layer}"
        break
      }
    }

    let layerId = "item_place_container"
    local layerCfg = LayersIcon.findLayerCfg($"{trophyItem.iconStyle}_{layerId}")
    if (!layerCfg)
      layerCfg = LayersIcon.findLayerCfg(layerId)

    let data = LayersIcon.genDataFromLayer(layerCfg, layersData)
    this.guiScene.replaceContentFromText(trophyContentPlaceObj, data, data.len(), this)
  }

  function updatePvEReward(dt) {
    if (!this.pveRewardInfo)
      return
    let pveTrophyPlaceObj = this.scene.findObject("pve_trophy_progress")
    if (!checkObj(pveTrophyPlaceObj))
      return

    let newSliderObj = pveTrophyPlaceObj.findObject("new_progress_box")
    if (!checkObj(newSliderObj))
      return

    let targetValue = this.pveRewardInfo.sessionTime
    local newValue = 0
    if (this.skipAnim)
      newValue = targetValue
    else
      newValue = blendProp(newSliderObj.getValue(), targetValue, this.statsTime, dt).tointeger()

    newSliderObj.setValue(newValue)
  }

  function switchTab(tabName) {
    if (this.state != debrState.done)
      return
    let tabsObj = this.scene.findObject("tabs_list")
    if (!checkObj(tabsObj))
      return
    for (local i = 0; i < tabsObj.childrenCount(); i++)
      if (tabsObj.getChild(i).id == tabName)
        return tabsObj.setValue(i)
  }

  function showTab(tabName) {
    if (this.curTab == tabName)
      return
    foreach (name in this.tabsList) {
      let obj = this.scene.findObject($"{name}_tab")
      if (!obj)
        continue
      let isShow = name == tabName
      obj.show(isShow)
      this.updateScrollableObjects(obj, name, isShow)
    }
    this.curTab = tabName
    this.updateListsButtons()

    if (this.state == debrState.done)
      this.isModeStat = tabName == "players_stats"
  }

  function onUpdate(_obj, dt) {
    this.needPlayCount = false
    if (this.isSceneActiveNoModals() && this.debriefingResult) {
      if (this.state != debrState.done && !this.updateState(dt))
        this.switchState()
      this.updateTotal(dt)
    }
    this.playCountSound(this.needPlayCount)
  }

  function playCountSound(play) {
    if (isPlatformSony)
      return

    play = play && !this.isInProgress
    if (play != this.isCountSoundPlay) {
      if (play)
        start_gui_sound("deb_count")
      else
        stop_gui_sound("deb_count")
      this.isCountSoundPlay = play
    }
  }

  function updateState(dt) {
    let state = this.state
    if (state == debrState.showPlayers)
      return this.updatePlayersTable(dt)

    if (state == debrState.showAwards)
      return this.updateAwards(dt)

    if (state == debrState.showMyStats)
      return this.updateMyStats(dt)

    if (state == debrState.showBonuses)
      return this.updateBonusStats(dt)

    return false
  }

  function updateMyStatObjects() {
    this.showTab("my_stats")

    showObjectsByTable(this.scene, {
      left_block              = this.is_show_left_block()
      inventory_gift_block    = this.is_show_inventory_gift()
      my_stats_awards_block   = this.is_show_awards_list()
      right_block             = this.is_show_right_block()
      battle_tasks_block      = this.is_show_battle_tasks_list()
      researches_scroll_block = this.is_show_research_list()
    })
    if (this.isCurMissionExtr)
      this.showCollectedResourcesTitle()
    else
      this.showMyPlaceInTable()

    this.updateMyStatsTopBarArrangement()
    this.handleGiftItems()
  }

  function switchState() {
    if (this.state >= debrState.done)
      return

    this.state++
    this.statsTimer = 0
    this.reinitTotal()

    if (this.state == debrState.showPlayers) {
      this.loadAwardsList()
      this.loadBattleTasksList()

      if (!this.needPlayersTbl)
        return this.switchState()

      this.showTab("players_stats")
      if (!this.skipAnim)
        this.guiScene.playSound("deb_players_on")
      this.initPlayersTable()
      this.loadBattleLog()
      this.loadChatHistory()
      this.loadWwCasualtiesHistory()
    }
    else if (this.state == debrState.showAwards) {
      if (!this.isCurMissionExtr)
        showObjById("btn_show_all", this.giftItems != null && this.giftItems.len() > VISIBLE_GIFT_NUMBER, this.scene)

      if (!this.is_show_my_stats() || !this.is_show_awards_list())
        return this.switchState()

      if (this.awardDelay * this.awardsList.len() > this.awardsAppearTime)
        this.awardDelay = this.awardsAppearTime / this.awardsList.len()
    }
    else if (this.state == debrState.showMyStats) {
      if (!this.is_show_my_stats())
        return this.switchState()

      this.updateMyStatObjects()
    }
    else if (this.state == debrState.showBonuses) {
      this.statsTimer = this.statsBonusDelay

      if (!this.is_show_my_stats())
        return this.switchState()
      if (!this.totalRow)
        return this.switchState()

      let objPlace = this.scene.findObject("bonus_ico_place")
      if (!checkObj(objPlace))
        return this.switchState()

      
      let textArray = []

      if (this.debriefingResult.mulsList.len())
        textArray.append(loc("bonus/xpFirstWinInDayMul/tooltip"))

      let bonusNames = {
        premAcc = "charServer/chapter/premium"
        premMod = "modification/premExpMul"
        booster = "itemTypes/booster"
      }
      let tblTotal = getTblValue("tblTotal", this.debriefingResult.exp, {})
      let bonusesTotal = []
      foreach (bonusType in [ "premAcc", "premMod", "booster" ]) {
        let bonusExp = getTblValue($"{bonusType}Exp", tblTotal, 0)
        let bonusWp  = getTblValue($"{bonusType}Wp",  tblTotal, 0)
        if (!bonusExp && !bonusWp)
          continue
        bonusesTotal.append("".concat(loc(getTblValue(bonusType, bonusNames, "")), loc("ui/colon"),
          Cost(bonusWp, 0, bonusExp).tostring()))
      }
      if (!u.isEmpty(bonusesTotal))
        textArray.append("\n".join(bonusesTotal, true))

      let boostersText = this.getBoostersText()
      if (!u.isEmpty(boostersText))
        textArray.append(boostersText)

      if (u.isEmpty(textArray)) 
        return this.switchState()

      if (!isDebriefingResultFull() &&
          !((this.gameType & GT_RACE) &&
            this.debriefingResult.exp.result == STATS_RESULT_IN_PROGRESS))
        textArray.append(loc("debriefing/most_award_after_battle"))

      textArray.insert(0, loc("charServer/chapter/bonuses"))

      objPlace.show(true)
      this.updateMyStatsTopBarArrangement()

      let objTarget = objPlace.findObject("bonus_ico")
      if (checkObj(objTarget)) {
        objTarget["background-image"] = havePremium.value ?
          "#ui/gameuiskin#medal_premium.svg" : "#ui/gameuiskin#medal_bonus.svg"
        objTarget.tooltip = "\n\n".join(textArray, true)
      }

      if (!this.skipAnim) {
        let objStart = this.scene.findObject("start_bonus_place")
        create_ObjMoveToOBj(this.scene, objStart, objTarget, { time = this.statsBonusTime })
        this.guiScene.playSound("deb_medal")
      }
    }
    else if (this.state == debrState.done) {
      showObjectsByTable(this.scene, {
        btn_skip = false
        skip_button   = false
        start_bonus_place = false
      })

      this.updateStartButton()
      this.fillLeaderboardChanges()
      this.updateInfoText()
      this.updateBuyPremiumAwardButton()
      this.showTabsList()
      this.updateListsButtons()
      this.fillResearchingMods()
      this.fillResearchingUnits()
      this.updateShortBattleTask()
      this.updateInventoryButton()

      this.checkPopupWindows()
      this.throwBattleEndEvent()
      this.guiScene.performDelayed(this, function() { this.ps4SendActivityFeed() })
      let tabsObj = this.getObj("tabs_list")
      move_mouse_on_child(tabsObj, tabsObj.getValue())
    }
  }

  function ps4SendActivityFeed() {
    if (!isPlatformSony
      || !this.isMp
      || !this.debriefingResult
      || this.debriefingResult.exp.result != STATS_RESULT_SUCCESS)
      return

    let config = {
      locId = "win_session"
      subType = ps4_activity_feed.MISSION_SUCCESS
    }
    let customConfig = {
      blkParamName = "VICTORY"
    }

    if (this.isFirstWinInMajorUpdate) {
      config.locId = "win_session_after_update"
      config.subType = ps4_activity_feed.MISSION_SUCCESS_AFTER_UPDATE
      customConfig.blkParamName = "MAJOR_UPDATE"
      let ver = split_by_chars(get_game_version_str(), ".")
      customConfig.version <- $"{ver[0]}.{ver[1]}"
      customConfig.imgSuffix <- $"_{ver[0]}_{ver[1]}"
      customConfig.shouldForceLogo <- true
    }

    activityFeedPostFunc(config, customConfig, bit_activity.PS4_ACTIVITY_FEED)
  }

  function updateMyStats(dt) {
    if (this.curStatsIdx < 0)
      return false 

    this.statsTimer -= dt

    this.updatePvEReward(dt)

    local haveChanges = false
    let upTo = min(this.curStatsIdx, debriefingRows.len() - 1)
    for (local i = 0; i <= upTo; i++)
      if (debriefingRows[i].show)
        haveChanges = !this.updateStat(debriefingRows[i], this.playerStatsObj, this.skipAnim ? 10 * dt : dt, i == upTo) || haveChanges

    if (haveChanges || this.curStatsIdx < debriefingRows.len()) {
      if ((this.statsTimer < 0 || this.skipAnim) && this.curStatsIdx < debriefingRows.len()) {
        do
          this.curStatsIdx++
        while (this.curStatsIdx < debriefingRows.len() && !debriefingRows[this.curStatsIdx].show)
        this.statsTimer += this.statsNextTime
      }
      return true
    }
    return false
  }

  function updateBonusStats(dt) {
    this.statsTimer -= dt
    if (this.statsTimer < 0 || this.skipAnim) {
      local haveChanges = false
      foreach (row in debriefingRows)
        if (row.show)
          haveChanges = !this.updateStat(row, this.playerStatsObj, this.skipAnim ? 10 * dt : dt, false) || haveChanges
      return haveChanges
    }
    return true
  }

  function updateStat(row, tblObj, dt, needScroll) {
    local finished = true
    local justCreated = false
    let rowId =$"row_{row.id}"
    local rowObj = tblObj.findObject(rowId)

    if (!("curValues" in row) || !checkObj(rowObj))
      row.curValues <- { value = 0, reward = 0 }
    if (!checkObj(rowObj)) {
      this.guiScene.setUpdatesEnabled(false, false)
      rowObj = this.guiScene.createElementByObject(tblObj, "%gui/debriefing/statRow.blk", "tr", this)
      rowObj.id = rowId
      rowObj.findObject("tooltip_").id =$"tooltip_{row.id}"
      rowObj.findObject("name").setValue(row.getName())
      if (row.getNameIcon) {
        rowObj.findObject("name_icon")["background-image"] = row.getNameIcon()
      }

      if (!this.debriefingResult.needRewardColumn)
        this.guiScene.destroyElement(rowObj.findObject(row.canShowRewardAsValue ? "td_value" : "td_reward"))
      justCreated = true

      if ("tooltip" in row)
        rowObj.title = loc(row.tooltip)

      local rowProps = getTblValue("rowProps", row, null)
      if (u.isFunction(rowProps))
        rowProps = rowProps()

      if (rowProps != null)
        foreach (name, value in rowProps)
          rowObj[name] = value
      this.guiScene.setUpdatesEnabled(true, true)
    }
    if (needScroll)
      rowObj.scrollToView()

    foreach (p in ["value", "reward"]) {
      let obj = rowObj.findObject(p)
      if (!checkObj(obj))
        continue

      local targetValue = 0
      if (p != "value" || isInArray(row.rowType, ["wp", "exp", "gold"])) {
        let tblKey = getCountedResultId(row, this.state, p == "value" ? row.rowType : row.rewardType)
        targetValue = getTblValue(tblKey, this.debriefingResult.counted_result_by_debrState, 0)
      }

      if (targetValue == 0)
        targetValue = this.getStatValue(row, p)

      if (targetValue == null || (!justCreated && targetValue == row.curValues[p]))
        continue

      local nextValue = 0
      if (!this.skipAnim) {
        nextValue = blendProp(row.curValues[p], targetValue, row.isOverall ? this.totalStatsTime : this.statsTime, dt)
        if (nextValue != targetValue)
          finished = false
        if (p != "value" || !isInArray(row.rowType, ["mul", "tim", "pct", "ptm", "tnt"]))
          nextValue = nextValue.tointeger()
      }
      else
        nextValue = targetValue

      row.curValues[p] = nextValue
      let showEmpty = ((p == "value") != row.isOverall) && row.isVisibleWhenEmpty()
      local paramType = p == "value" ? row.rowType : row.rewardType

      if (row.isFreeRP && paramType == "exp")
        paramType = "frp" 

      let { text, image } = getViewByType(nextValue, paramType, showEmpty)
      obj.setValue(text)
      rowObj.findObject($"{p}_image")["background-image"] = image
    }
    this.needPlayCount = this.needPlayCount || !finished
    return finished
  }

  function getStatValue(row, name, tgtName = null) {
    if (!tgtName)
      tgtName = "base"
    return !u.isTable(row[name]) ? row[name] : getTblValue(tgtName, row[name], null)
  }

  function updateTotal(dt) {
    if (!this.isInited && (!this.totalCurValues || u.isEqual(this.totalCurValues, this.totalTarValues)))
      return

    if (this.isInited) {
      let country = this.getDebriefingCountry()
      if (country in playerRankByCountries && playerRankByCountries[country] >= MAX_COUNTRY_RANK) {
        this.totalTarValues.exp = this.getStatValue(this.totalRow, "exp", "prem")
        dt = 1000 
      }
    }

    let cost = Cost()
    foreach (p in [ "exp", "wp", "expTeaser", "wpTeaser" ])
      if (this.totalCurValues[p] != this.totalTarValues[p]) {
        this.totalCurValues[p] = this.skipAnim ? this.totalTarValues[p] :
          blendProp(this.totalCurValues[p], this.totalTarValues[p], this.totalStatsTime, dt).tointeger()

        let obj = this.totalObj.findObject(p)
        if (checkObj(obj)) {
          cost.wp = p.indexof("wp") != null ? this.totalCurValues[p] : 0
          cost.rp = p.indexof("exp") != null ? this.totalCurValues[p] : 0
          obj.setValue(cost.toStringWithParams({ isColored = p.indexof("Teaser") == null, needIcon = false }))
        }
        this.needPlayCount = true
      }
  }

  function getModExp(airData) {
    if (getTblValue("expModuleCapped", airData, false))
      return airData.expInvestModule
    return airData.expModsTotal 
  }

  function fillResearchingMods() {
    if (!isDebriefingResultFull())
      return

    let usedUnitsList = []
    foreach (unitId, unitData in this.debriefingResult.exp.aircrafts) {
      let unit = getAircraftByName(unitId)
      if (unit && this.isShowUnitInModsResearch(unitId))
        usedUnitsList.append({ unit = unit, unitData = unitData })
    }

    usedUnitsList.sort(function(a, b) {
      let haveInvestA = a.unitData.investModuleName == ""
      let haveInvestB = b.unitData.investModuleName == ""
      if (haveInvestA != haveInvestB)
        return haveInvestA ? 1 : -1
      let expA = a.unitData.expTotal
      let expB = b.unitData.expTotal
      if (expA != expB)
        return (expA > expB) ? -1 : 1
      return 0
    })

    let tabObj = this.scene.findObject("modifications_objects_place")
    this.guiScene.replaceContentFromText(tabObj, "", 0, this)
    foreach (data in usedUnitsList)
      this.fillResearchMod(tabObj, data.unit, data.unitData)
  }

  function fillResearchingUnits() {
    if (!isDebriefingResultFull())
      return

    let obj = this.scene.findObject("air_item_place")
    local data = ""
    let unitItems = []
    foreach (ut in unitTypes.types) {
      let unitItem = this.getResearchUnitMarkupData(ut.name)
      if (unitItem) {
        data = "".concat(data, buildUnitSlot(unitItem.id, unitItem.unit, unitItem.params))
        unitItems.append(unitItem)
      }
    }

    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
    foreach (unitItem in unitItems)
      fillUnitSlotTimers(obj.findObject(unitItem.id), unitItem.unit)

    if (!unitItems.len()) {
      let expInvestUnitTotal = this.getExpInvestUnitTotal()
      if (expInvestUnitTotal > 0) {
        let msg = format(loc("debriefing/all_units_researched"),
          Cost().setRp(expInvestUnitTotal).tostring())
        let noUnitObj = this.scene.findObject("no_air_text")
        if (checkObj(noUnitObj))
          noUnitObj.setValue(stripTags(msg))
      }
    }
  }

  function onEventUnitBought(_p) {
    this.fillResearchingUnits()
  }

  function onEventUnitRented(_p) {
    this.fillResearchingUnits()
  }

  function isShowUnitInModsResearch(unitId) {
    let unitData = this.debriefingResult.exp.aircrafts?[unitId]
    return unitData?.expTotal && unitData?.sessionTime &&
      ((unitData?.investModuleName ?? "") != "" ||
      isUsedPlayersOwnUnit(this.playersInfo?[userIdInt64.get()], unitId))
  }

  function hasAnyFinishedResearch() {
    if (!this.debriefingResult)
      return false
    foreach (ut in unitTypes.types) {
      let unit = getTblValue("unit", this.getResearchUnitInfo(ut.name))
      if (unit && !isUnitInResearch(unit))
        return true
    }
    foreach (unitId, unitData in this.debriefingResult.exp.aircrafts) {
      let modName = getTblValue("investModuleName", unitData, "")
      if (modName == "")
        continue
      let unit = getAircraftByName(unitId)
      let mod = unit && getModificationByName(unit, modName)
      if (unit && mod && isModResearched(unit, mod))
        return true
    }
    return false
  }

  function getExpInvestUnitTotal() {
    local res = 0
    foreach (_unitId, unitData in this.debriefingResult.exp.aircrafts)
      res += unitData?.expInvestUnitTotal ?? 0
    return res
  }

  function getResearchUnitInfo(unitTypeName) {
    let unitId = this.debriefingResult?.exp[$"investUnitName{unitTypeName}"] ?? ""
    let unit = getAircraftByName(unitId)
    if (!unit)
      return null
    local expInvest = this.debriefingResult?.exp[$"expInvestUnit{unitTypeName}"] ?? 0
    expInvest = this.applyItemExpMultiplicator(expInvest)
    if (expInvest <= 0)
      return null
    return { unit = unit, expInvest = expInvest }
  }

  function getResearchUnitMarkupData(unitTypeName) {
    let info = this.getResearchUnitInfo(unitTypeName)
    if (!info)
      return null

    return {
      id = info.unit.name
      unit = info.unit
      params = {
        diffExp = info.expInvest
        tooltipParams = {
          researchExpInvest = info.expInvest
          boosterEffects = this.getBoostersTotalEffects()
        }
      }
    }
  }

  function applyItemExpMultiplicator(itemExp) {
    local multBonus = 0
    if (this.debriefingResult.mulsList.len() > 0)
      foreach (_idx, table in this.debriefingResult.mulsList)
        multBonus += getTblValue("exp", table, 0)

    itemExp = multBonus == 0 ? itemExp : itemExp * multBonus
    return itemExp
  }

  function getResearchModFromAirData(air, airData) {
    let curResearch = airData.investModuleName
    if (curResearch != "")
      return getModificationByName(air, curResearch)
    return null
  }

  function fillResearchMod(holderObj, unit, airData) {
    let unitId = unit.name
    let mod = this.getResearchModFromAirData(unit, airData)
    let diffExp = mod ? this.getModExp(airData) : 0
    let isCompleted = mod ? getTblValue("expModuleCapped", airData, false) : false

    let view = {
      id = unitId
      unitImg = image_for_air(unit)
      unitName = getUnitName(unit).replace(nbsp, " ")
      hasModItem = mod != null
      isCompleted = isCompleted
      unitTooltipId = getTooltipType("UNIT").getTooltipId(unit.name, { boosterEffects = this.getBoostersTotalEffects() })
      modTooltipId =  mod
        ? MODIFICATION.getTooltipId(unit.name, mod.name, { diffExp = diffExp, curEdiff = this.getCurrentEdiff() })
        : ""
      isTooltipByHold = showConsoleButtons.get()
    }

    let markup = handyman.renderCached("%gui/debriefing/modificationProgress.tpl", view)
    this.guiScene.appendWithBlk(holderObj, markup, this)
    let obj = holderObj.findObject(unitId)

    if (mod) {
      let modObj = obj.findObject($"mod_{unitId}")
      updateModItem(unit, mod, modObj, false, this, this.getParamsForModItem(diffExp))
    }
    else {
      local msg = "debriefing/but_all_mods_researched"
      if (findAnyNotResearchedMod(unit))
        msg = "debriefing/but_not_any_research_active"
      msg = format(loc(msg), Cost().setRp(this.getModExp(airData) || airData.expTotal).tostring())
      obj.findObject("no_mod_text").setValue(msg)
    }
  }

  function getCurrentEdiff() {
    return get_mission_mode()
  }

  function onEventModBought(p) {
    let unitId = getTblValue("unitName", p, "")
    let modId = getTblValue("modName", p, "")
    this.updateResearchMod(unitId, modId)
  }

  function onEventUnitModsRecount(p) {
    this.updateResearchMod(p?.unit.name, "")
  }

  function updateResearchMod(unitId, modId) {
    let airData = this.debriefingResult?.exp.aircrafts[unitId]
    if (!airData)
      return
    let unit = getAircraftByName(unitId)
    let mod = this.getResearchModFromAirData(unit, airData)
    if (!mod || (modId != "" && modId != mod.name))
      return

    let obj = this.scene.findObject("research_list")
    let modObj = checkObj(obj) ? obj.findObject($"mod_{unitId}") : null
    if (!checkObj(modObj))
      return
    let diffExp = this.getModExp(airData)
    updateModItem(unit, mod, modObj, false, this, this.getParamsForModItem(diffExp))
  }

  function getParamsForModItem(diffExp) {
    return { diffExp = diffExp, limitedName = false, curEdiff = this.getCurrentEdiff() }
  }

  function fillLeaderboardChanges() {
    let lbWindgetsNestObj = this.scene.findObject("leaderbord_stats")
    if (!checkObj(lbWindgetsNestObj))
      return

    let logs = getUserLogsList({
        show = [EULT_SESSION_RESULT]
        currentRoomOnly = true
      })

    if (logs.len() == 0)
      return

    let { tournamentResult = null, eventId = null } = logs[0]
    if (tournamentResult == null || events.getEvent(eventId)?.leaderboardEventTable != null)
      return

    let gapSides = this.guiScene.calcString("@tablePad", null)
    let gapMid   = this.guiScene.calcString("@debrPad", null)
    let gapsPerRow = gapSides * 2 + gapMid * (DEBR_LEADERBOARD_LIST_COLUMNS - 1)

    let posFirst  = format("%d, %d", gapSides, gapMid)
    let posCommon = format("%d, %d", gapMid,   gapMid)
    let itemParams = {
      width  = format("(pw - %d) / %d", gapsPerRow, DEBR_LEADERBOARD_LIST_COLUMNS)
      pos    = posCommon
      margin = "0"
    }

    let now = tournamentResult.newStat
    let was = tournamentResult.oldStat

    let lbDiff = getLbDiff(now, was)
    let items = []
    foreach (lbFieldsConfig in eventsTableConfig) {
      if (!(lbFieldsConfig.field in now)
        || !events.checkLbRowVisibility(lbFieldsConfig, { eventId }))
        continue

      let isFirstInRow = items.len() % DEBR_LEADERBOARD_LIST_COLUMNS == 0
      itemParams.pos = isFirstInRow ? posFirst : posCommon

      items.append(getLeaderboardItemView(lbFieldsConfig,
        now[lbFieldsConfig.field],
        getTblValue(lbFieldsConfig.field, lbDiff, null),
        itemParams))
    }
    lbWindgetsNestObj.show(true)

    let blk = getLeaderboardItemWidgets({ items = items })
    this.guiScene.replaceContentFromText(lbWindgetsNestObj, blk, blk.len(), this)
    lbWindgetsNestObj.scrollToView()
  }

  function onSkip() {
    this.skipAnim = true
  }

  function checkShowTooltip(obj) {
    let showTooltip = this.skipAnim || this.state == debrState.done
    obj["class"] = showTooltip ? "" : "empty"
    return showTooltip
  }

  function onTrTooltipOpen(obj) {
    if (!this.checkShowTooltip(obj) || !this.debriefingResult)
      return

    let id = getTooltipObjId(obj)
    if (!id)
      return
    if (!("exp" in this.debriefingResult) || !("aircrafts" in this.debriefingResult.exp)) {
      obj["class"] = "empty"
      return
    }

    let tRow = this.getDebriefingRowById(id)
    if (!tRow || tRow.hideTooltip) {
      obj["class"] = "empty"
      return
    }

    if (tRow?.fillTooltipFunc != null) {
      tRow.fillTooltipFunc(this.debriefingResult, obj, this)
      return
    }
    let rowsCfg = []
    if (!tRow.joinRows) {
      if (tRow.isCountedInUnits) {
        foreach (unitId, unitData in this.debriefingResult.exp.aircrafts)
          rowsCfg.append({
            row     = tRow
            name    = getUnitName(unitId)
            expData = unitData
            unitId  = unitId
          })
      }
      else {
        rowsCfg.append({
          row     = tRow
          name    = tRow.getName()
          expData = this.debriefingResult.exp
        })
      }
    }

    if (tRow.joinRows || tRow.tooltipExtraRows) {
      let extraRows = []
      if (tRow.joinRows)
        extraRows.extend(tRow.joinRows)
      if (tRow.tooltipExtraRows)
        extraRows.extend(tRow.tooltipExtraRows())

      foreach (extId in extraRows) {
        let extraRow = this.getDebriefingRowById(extId)
        if (extraRow.show || extraRow.showInTooltips)
          rowsCfg.append({
            row     = extraRow
            name    = extraRow.getName()
            expData = this.debriefingResult.exp
          })
      }
    }

    if (!rowsCfg.len()) {
      obj["class"] = "empty"
      return
    }

    let tooltipView = {
      rows = this.getTrTooltipRowsView(rowsCfg, tRow)
      tooltipComment = tRow.tooltipComment ? tRow.tooltipComment() : null
      commentMaxWidth = tRow?.commentMaxWidth
    }

    let markup = handyman.renderCached("%gui/debriefing/statRowTooltip.tpl", tooltipView)
    this.guiScene.replaceContentFromText(obj, markup, markup.len(), this)
  }

  function getTrTooltipRowsView(rowsCfg, tRow) {
    let view = []

    let boosterEffects = this.getBoostersTotalEffects()

    foreach (cfg in rowsCfg) {
      let rowView = {
        name = cfg.name
      }

      let rowTbl = cfg.expData?[getTableNameById(cfg.row)]

      foreach (currency in [ "exp", "wp" ]) {
        if (cfg.row.rowType != currency && cfg.row.rewardType != currency)
          continue
        let currencySourcesView = []
        foreach (source in rewardsBonusTypes) {
          let val = rowTbl?[$"{source}{capitalize(currency)}"] ?? 0
          if (val <= 0)
            continue
          local extra = ""
          if (source == "booster") {
            let effect = boosterEffects?[$"{currency == "exp" ? "xp" : currency}Rate"] ?? 0
            if (effect)
              extra = colorize("fadedTextColor", loc("ui/parentheses", { text = $"{effect.tointeger()}%" }))
          }
          let { text, image } = getViewByType(val, currency)
          currencySourcesView.append((sourcesConfig?[source] ?? {}).__merge({
            text = $"{text}{extra}"
            currencyImg = image
          }))
        }
        if (currencySourcesView.len() > 1) {
          if (!("bonuses" in rowView))
            rowView.bonuses <- []
          rowView.bonuses.append({ sources = currencySourcesView })
        }
      }

      let extraBonuses = tRow.tooltipRowBonuses(cfg?.unitId, cfg.expData)
      if (extraBonuses) {
        if (!("bonuses" in rowView))
          rowView.bonuses <- []
        rowView.bonuses.append(extraBonuses)
      }

      foreach (p in ["time", "value", "reward", "info"]) {
        let { paramType, pId, showEmpty = false } = statTooltipColumnParamByType[p](cfg.row)
        let { text, image } = getViewByType(cfg.expData?[pId] ?? 0, paramType, showEmpty)
        rowView[p] <- text
        if (image != "")
          rowView[$"{p}_image"] <- image
      }

      view.append(rowView)
    }

    let showColumns = { time = false, value = false, reward = false, info = false }
    foreach (rowView in view)
      foreach (col, _isShow in showColumns)
        if (!u.isEmpty(rowView[col]))
          showColumns[col] = true
    foreach (rowView in view)
      foreach (col, isShow in showColumns)
        if (isShow && u.isEmpty(rowView[col]))
          rowView[col] = nbsp

    let headerRow = { name = colorize("fadedTextColor", loc("options/unit")) }
    foreach (col, isShow in showColumns) {
      local title = ""
      if (isShow)
        title = col == "value" ? tRow.getIcon()
          : col == "time" ? loc("icon/timer")
          : ""
      headerRow[col] <- colorize("fadedTextColor", title)
    }
    view.insert(0, headerRow)

    return view
  }

  function getDebriefingRowById(id) {
    return u.search(debriefingRows, @(row) row.id == id)
  }

  function getPremTeaserInfo() {
    let totalWp = this.debriefingResult.exp?.wpTotal  ?? 0
    let totalRp = this.debriefingResult.exp?.expTotal ?? 0
    let virtPremAccWp = this.debriefingResult.exp?.tblTotal.virtPremAccWp  ?? 0
    let virtPremAccRp = this.debriefingResult.exp?.tblTotal.virtPremAccExp ?? 0

    let totalWithPremWp = (totalWp <= 0 || virtPremAccWp <= 0) ? 0 : (totalWp + virtPremAccWp)
    let totalWithPremRp = (totalRp <= 0 || virtPremAccRp <= 0) ? 0 : (totalRp + virtPremAccRp)

    return {
      exp  = totalWithPremRp
      wp   = totalWithPremWp
      isPositive = totalWithPremRp > 0 || totalWithPremWp > 0
    }
  }

  function canSuggestBuyPremium() {
    return !havePremium.value && hasFeature("SpendGold") && hasFeature("EnablePremiumPurchase")
  }

  getBqEventPremBtnParams = @() {
    sessionId = this.debriefingResult?.sessionId ?? ""
    premiumRewardWp = get_premium_reward_wp()
    entitelmentId = this.getEntitlementWithAward()
  }

  function updateBuyPremiumAwardButton() {
    let isShow = this.canSuggestBuyPremium() && this.gm == GM_DOMINATION && this.checkPremRewardAmount()

    let obj = this.scene.findObject("buy_premium")
    if (!checkObj(obj))
      return

    obj.show(isShow)
    if (!isShow)
      return

    sendBqEvent("CLIENT_GAMEPLAY_1", "debriefing_premium_button_discovery", this.getBqEventPremBtnParams())

    let curAwardText = this.getCurAwardText()

    let btnObj = obj.findObject("btn_buy_premium_award")
    if (checkObj(btnObj))
      btnObj.findObject("label").setValue($"{loc("mainmenu/earn")}\n{curAwardText}")

    this.updateMyStatsTopBarArrangement()
  }

  function getEntitlementWithAward() {
    let priceBlk = getShopPriceBlk()
    let l = priceBlk.blockCount()
    for (local i = 0; i < l; i++)
      if (priceBlk.getBlock(i)?.allowBuyWithAward)
        return priceBlk.getBlock(i).getBlockName()
    return null
  }

  function checkPremRewardAmount() {
    if (!this.getEntitlementWithAward())
      return false
    if (get_premium_reward_wp() >= minValuesToShowRewardPremium.get().wp)
      return true
    let exp = get_premium_reward_xp()
    return exp >= minValuesToShowRewardPremium.get().exp
  }

  function onBuyPremiumAward() {
    sendBqEvent("CLIENT_GAMEPLAY_1", "debriefing_premium_button_activation", this.getBqEventPremBtnParams())

    if (havePremium.value)
      return
    let entName = this.getEntitlementWithAward()
    if (!entName) {
      assert(false, "Error: not found entitlement with premium award")
      return
    }

    let ent = getEntitlementConfig(entName)
    let entNameText = getEntitlementName(ent)
    let price = Cost(0, ent?.goldCost ?? 0)
    let cb = Callback(this.onBuyPremiumAward, this)

    let msgText = format(loc("msgbox/EarnNow"), entNameText, this.getCurAwardText(), price.getTextAccordingToBalance())
    this.msgBox("not_all_mapped", msgText,
    [
      ["ok", function() {
        if (!checkBalanceMsgBox(price, cb))
          return false

        let bqEventPremBtnParams = this.getBqEventPremBtnParams()
        this.taskId = purchase_entitlement_and_get_award(entName)
        if (this.taskId >= 0) {
          set_char_cb(this, this.slotOpCb)
          this.showTaskProgressBox()
          this.afterSlotOp = function() {
            sendBqEvent("CLIENT_GAMEPLAY_1", "debriefing_premium_purchase_confirmation", bqEventPremBtnParams)
            this.addPremium()
          }
        }
      }],
      ["cancel", @() null]
    ], "ok", { cancel_fn = @() null })
  }

  function addPremium() {
    if (!havePremium.value)
      return

    debriefingAddVirtualPremAcc()

    foreach (row in debriefingRows)
      if (!row.show)
        showObjById($"row_{row.id}", row.show, this.scene)

    this.updateBuyPremiumAwardButton()
    this.reinitTotal()
    this.skipAnim = false
    this.state = debrState.showBonuses - 1
    this.switchState()
    updateGamercards()
  }

  function updateAwards(dt) {
    this.statsTimer -= dt

    if (this.statsTimer < 0 || this.skipAnim) {
      if (this.awardsList && this.curAwardIdx < this.awardsList.len()) {
        if (this.currentAwardsListIdx >= this.currentAwardsList.len()) {
          if (this.awardsData.len() == 0)
            return false

          let awardsItem = this.awardsData.pop()
          this.currentAwardsList = awardsItem.list
          this.currentAwardsListConfig = awardsItem.config

          if (this.challengesAwardsList.len() > 0)
            this.scene.findObject("btn_challenge_div").show(true)

          this.currentAwardsListIdx = 0
        }

        let giftsCount = this.giftItems?.len() ?? 0
        local awardSize = null
        if(this.currentAwardsListConfig == this.awardsListsConfig.challenges
          && this.currentAwardsList.len() == 1 && giftsCount == 0)
            awardSize = "2@debriefingUnlockIconSize"

        this.addAward(awardSize)
        this.statsTimer += this.awardDelay
        this.curAwardIdx++
        this.currentAwardsListIdx++
      }
      else if (this.curAwardIdx == this.awardsList.len()) {
        
        this.statsTimer += this.nextWndDelay
        this.curAwardIdx++
      }
      else
        return false
    }
    return true
  }

  function countAwardsOffset(obj, tgtObj, axis) {
    let size = obj.getSize()
    let maxSize = tgtObj.getSize()
    let awardSize = size[axis] * this.currentAwardsList.len()

    if(axis == 0)
      this.awardShift = max(0, (maxSize[0] - awardSize) / 2)

    
    let giftsCount = this.giftItems?.len() ?? 0
    if(axis == 1)
      maxSize[1] = maxSize[1] - to_pixels("0.2@debriefingUnlockIconSize") - (giftsCount > 0 ? to_pixels("1@navBarBattleButtonHeight") : 0)

    if (awardSize > maxSize[axis] && this.currentAwardsList.len() > 1)
      this.awardOffset = ((maxSize[axis] - awardSize) / (this.currentAwardsList.len() - 1) - 1).tointeger()
    else
      tgtObj[axis ? "height" : "width"] = awardSize.tostring()
  }

  function addAward(awardSize = null) {
    let config = this.currentAwardsList[this.currentAwardsListIdx]
    let objId = $"award_{this.curAwardIdx}"

    let listObj = this.scene.findObject(this.currentAwardsListConfig.listObjId)
    let obj = this.guiScene.createElementByObject(listObj, "%gui/debriefing/awardIcon.blk", "awardPlace", this)
    obj.id = objId

    let tooltipObj = obj.findObject("tooltip_")
    tooltipObj.id = $"tooltip_{this.curAwardIdx}"
    tooltipObj.setUserData(config)

    if ("needFrame" in config && config.needFrame)
      obj.findObject("move_part")["class"] = "unlockFrame"

    if (awardSize != null) {
      obj.size = $"{awardSize}, {awardSize}"
      listObj.size = $"pw, {awardSize}"
      this.guiScene.applyPendingChanges(false)
    }

    let align = this.currentAwardsListConfig.align
    let axis = (align == ALIGN.TOP || align == ALIGN.BOTTOM) ? 1 : 0
    if (this.currentAwardsListIdx == 0) 
      this.countAwardsOffset(obj, listObj, axis)
    else if (align == ALIGN.LEFT && this.awardOffset != 0)
      obj.pos = $"{this.awardOffset}, 0"
    else if (align == ALIGN.TOP && this.awardOffset != 0)
      obj.pos = $"0, {this.awardOffset}"

    if (align == ALIGN.CENTER)
      obj.pos = $"{this.currentAwardsListIdx == 0 ? this.awardShift : this.awardOffset} , 0"

    if (align == ALIGN.RIGHT)
      if (this.currentAwardsListIdx == 0)
        obj.pos = "pw - w, 0"
      else
        obj.pos = $"-2w -{this.awardOffset} ,0"

    let icoObj = obj.findObject("award_img")
    let { iconStyle, image, ratio, iconParams, iconConfig } = getUnlockIconConfig(config, false)
    let containerSizePx = to_pixels(awardSize ?? "1@debriefingUnlockIconSize")
    LayersIcon.replaceIcon(icoObj, iconStyle, image, ratio, null, iconParams, iconConfig, containerSizePx)

    let awMultObj = obj.findObject("award_multiplier")
    if (checkObj(awMultObj)) {
      let show = config.amount > 1
      awMultObj.show(show)
      if (show) {
        let amObj = awMultObj.findObject("amount_text")
        if (checkObj(amObj))
          amObj.setValue($"x{config.amount}")
      }
    }

    if (!this.skipAnim) {
      let objStart = this.scene.findObject(this.currentAwardsListConfig.startplaceObId)
      let objTarget = obj.findObject("move_part")
      create_ObjMoveToOBj(this.scene, objStart, objTarget, { time = this.awardFlyTime })

      obj["_size-timer"] = "0"
      obj.width = "0"
      this.guiScene.playSound("deb_achivement")
    }
  }

  function onGotoChallenge() {
    this.goBack()
    openBattlePassWnd({ currSheet = "challenges_sheet" })
  }

  function onViewAwards(_obj) {
    this.switchTab("awards_list")
  }

  function onAwardTooltipOpen(obj) {
    if (!this.checkShowTooltip(obj))
      return

    let config = obj.getUserData()
    build_unlock_tooltip_by_config(obj, config, this)
  }

  function buildPlayersTable() {
    this.playersTbl = []
    this.curPlayersTbl = [[], []]
    this.updateNumMaxPlayers(true)
    if (this.isTeamplay) {
      for (local t = 0; t < 2; t++) {
        let tbl = this.getMplayersList(t + 1)
        this.sortTable(tbl)
        this.playersTbl.append(tbl)
      }
    }
    else {
      this.sortTable(this.debriefingResult.mplayers_list)
      this.playersTbl.append([])
      this.playersTbl.append([])
      foreach (i, player in this.debriefingResult.mplayers_list) {
        let tblIdx = i >= this.numMaxPlayers ? 1 : 0
        this.playersTbl[tblIdx].append(player)
      }
    }

    foreach (tbl in this.playersTbl)
      foreach (player in tbl) {
        player.state = PLAYER_IN_FLIGHT 
        player.isDead = false
      }
  }

  function initPlayersTable() {
    this.initStats()

    if (this.needPlayersTbl)
      this.buildPlayersTable()

    this.updatePlayersTable(0.0)
  }

  function updatePlayersTable(dt) {
    if (!this.playersTbl || !this.debriefingResult)
      return false

    this.statsTimer -= dt
    this.minPlayersTime -= dt
    if (this.statsTimer <= 0 || this.skipAnim) {
      if (this.playersTblDone)
        return this.minPlayersTime > 0

      this.playersTblDone = true
      for (local t = 0; t < 2; t++) {
        let idx = this.curPlayersTbl[t].len()
        if (idx in this.playersTbl[t])
          this.curPlayersTbl[t].append(this.playersTbl[t][idx])
        this.playersTblDone = this.playersTblDone && this.curPlayersTbl[t].len() == this.playersTbl[t].len()
      }
      this.updateStats({ playersTbl = this.curPlayersTbl }, this.debriefingResult.mpTblTeams,
        this.debriefingResult.friendlyTeam)
      this.statsTimer += this.playersRowTime
    }
    return true
  }

  function getMyPlace() {
    local place = 0
    if (this.playersTbl)
      foreach (t, tbl in this.playersTbl)
        foreach (i, player in tbl)
          if (("isLocal" in player) && player.isLocal) {
            place = i + 1
            if (!this.isTeamplay && t)
              place += this.playersTbl[0].len()
            break
          }

    return place
  }

  function showCollectedResourcesTitle() {
    let objTarget = this.scene.findObject("my_place_move_box")
    objTarget.show(true)

    this.scene.findObject("my_place_label").setValue(this.hasGiftItem()
      ? loc("debriefing/collectedResources")
      : loc("debriefing/noCollectedResources"))
    this.scene.findObject("my_place_in_mptable").show(false)
  }

  function showMyPlaceInTable() {
    if (this.isCurMissionExtr)
      return

    if (!this.is_show_my_stats())
      return

    let place = this.getMyPlace()
    let hasPlace = place != 0

    let label = hasPlace && this.isTeamplay ? loc("debriefing/placeInMyTeam")
      : hasPlace && !this.isTeamplay ? "".concat(loc("mainmenu/btnMyPlace"), loc("ui/colon"))
      : !isDebriefingResultFull() ? loc("debriefing/preliminaryResults")
      : loc(this.debriefingResult.isSucceed ? "debriefing/victory" : "debriefing/defeat")

    let objTarget = this.scene.findObject("my_place_move_box")
    objTarget.show(true)
    this.scene.findObject("my_place_label").setValue(label)
    this.scene.findObject("my_place_in_mptable").setValue(hasPlace ? place.tostring() : "")

    if (!this.skipAnim && hasPlace) {
      let objStart = this.scene.findObject("my_place_move_box_start")
      create_ObjMoveToOBj(this.scene, objStart, objTarget, { time = this.myPlaceTime })
    }
  }

  function updateMyStatsTopBarArrangement() {
    if (!this.is_show_my_stats())
      return

    let containerObj = this.scene.findObject("my_stats_top_bar")
    let myPlaceObj = this.scene.findObject("my_place_move_box")
    let topBarNestObj = this.scene.findObject("top_bar_nest")
    if (!checkObj(containerObj) || !checkObj(myPlaceObj) || !checkObj(topBarNestObj))
      return
    let total = containerObj.childrenCount()
    if (total < 2)
      return
    this.guiScene.applyPendingChanges(false)

    local visible = 0
    for (local i = 0; i < total; i++) {
      let obj = containerObj.getChild(i)
      if (checkObj(obj) && obj.isVisible())
        visible++
    }

    let isSingleRow = visible < 3
    let gapMin = 1.0
    let debrTopBarGAPMax = isSingleRow ? 3 : DEBR_MYSTATS_TOP_BAR_GAP_MAX
    let maxValue = isSingleRow ? 1 : 2
    let contentPadStr = isSingleRow ? "debrBarContentPad" : "debrPad"

    let gapMax = gapMin * debrTopBarGAPMax
    let gap = clamp(stdMath.lerp(total, maxValue, gapMin, gapMax, visible), gapMin, gapMax)
    let pos = $"{gap}@{contentPadStr}, 0.5ph-0.5h"

    for (local i = 0; i < containerObj.childrenCount(); i++) {
      let obj = containerObj.getChild(i)
      if (checkObj(obj))
        obj["pos"] = pos
    }

    if (isSingleRow) {                  
      topBarNestObj.flow = "horisontal"
      local totalWidth = 0.5 * (myPlaceObj.getSize()[0] + containerObj.getSize()[0])
      myPlaceObj.pos = $"0.5pw-{totalWidth}, 0.5ph-0.5h"
      containerObj.pos = "0, 0"
    }
    else {                            
      topBarNestObj.flow = "vertical"
      myPlaceObj.pos = "0.5pw-0.5w, 0"
      containerObj.pos = "0.5pw-0.5w-0.5@debrPad, 0.5@debrPad"
    }
  }

  function loadBattleLog(filterIdx = null) {
    if (!this.needPlayersTbl)
      return
    let filters = HudBattleLog.getFilters()

    if (filterIdx == null) {
      filterIdx = loadLocalByAccount("wnd/battleLogFilterDebriefing", 0)

      let obj = this.scene.findObject("battle_log_filter")
      if (checkObj(obj)) {
        local data = ""
        foreach (f in filters)
          data = "".concat(data, "RadioButton { text:t='#", f.title, "'; style:t='color:@white'; RadioButtonImg{} }\n")
        this.guiScene.replaceContentFromText(obj, data, data.len(), this)
        obj.setValue(filterIdx)
      }
    }

    let obj = this.scene.findObject("battle_log_div")
    if (checkObj(obj)) {
      let logText = HudBattleLog.getText(filters[filterIdx].id, 0)
      obj.findObject("battle_log").setValue(logText)
    }
  }

  function loadChatHistory() {
    if (!this.needPlayersTbl)
      return
    let logText = getTblValue("chatLog", this.debriefingResult, "")
    if (logText == "")
      return
    let obj = this.scene.findObject("chat_history_div")
    if (checkObj(obj))
      obj.findObject("chat_log").setValue(logText)
  }

  function loadAwardsList() {
    let listObj = this.scene.findObject("awards_list_tab_div")
    let itemWidth = floor((listObj.getSize()[0] -
      this.guiScene.calcString("@scrollBarSize", null)
      ) / DEBR_AWARDS_LIST_COLUMNS - 1)
    foreach (list in [ this.challengesAwardsList, this.unlocksAwardsList, this.streakAwardsList ])
      foreach (award in list) {
        let obj = this.guiScene.createElementByObject(listObj, "%gui/unlocks/unlockBlock.blk", "tdiv", this)
        obj.width = itemWidth.tostring()
        fill_unlock_block(obj, award)
      }
  }

  function loadBattleTasksList() {
    if (!this.is_show_battle_tasks_list(false) || !this.roomEvent)
      return

    this.battleTasksConfigsSorted = getCurBattleTasksByGm(this.roomEvent?.name)
      .filter(@(t) !isBattleTaskDone(t))
      .map(@(t) mkUnlockConfigByBattleTask(t))

    let currentBattleTasksConfigs = {}
    foreach (config in this.battleTasksConfigsSorted)
      currentBattleTasksConfigs[config.id] <- config

    if (!u.isEqual(currentBattleTasksConfigs, this.battleTasksConfigs)) {
      this.shouldBattleTasksListUpdate = true
      this.battleTasksConfigs = currentBattleTasksConfigs
      this.updateBattleTasksList()
    }
  }

  function updateBattleTasksList() {
    if (this.curTab != "battle_tasks_list" || !this.shouldBattleTasksListUpdate || !this.is_show_battle_tasks_list(false))
      return

    this.shouldBattleTasksListUpdate = false
    let msgObj = this.scene.findObject("battle_tasks_list_msg")
    if (checkObj(msgObj))
      msgObj.show(!this.is_show_battle_tasks_list())

    let listObj = this.scene.findObject("battle_tasks_list_scroll_block")
    if (!checkObj(listObj))
      return

    listObj.show(this.is_show_battle_tasks_list())
    if (!this.is_show_battle_tasks_list())
      return

    let curSelected = listObj.getValue()
    let battleTasksArray = []
    foreach (config in this.battleTasksConfigsSorted) {
      battleTasksArray.append(getBattleTaskView(config, { showUnlockImage = false }))
    }
    let data = handyman.renderCached("%gui/unlocks/battleTasksItem.tpl", { items = battleTasksArray })
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)

    if (battleTasksArray.len() > 0)
      listObj.setValue(clamp(curSelected, 0, listObj.childrenCount() - 1))
  }

  function updateBattleTasksStatusImg() {
    let tabObjStatus = this.scene.findObject("battle_tasks_list_icon")
    if (checkObj(tabObjStatus))
      tabObjStatus.show(canGetAnyBattleTaskReward())
  }

  function onSelectTask(obj) {
    this.updateBattleTasksRequirementsList() 

    let val = obj.getValue()
    let taskObj = obj.getChild(val)
    let taskId = taskObj?.task_id
    let task = getBattleTaskById(taskId)
    if (!task)
      return

    let isTask = isBattleTask(taskId)

    let isDone = isBattleTaskDone(task)
    let canGetReward = isTask && canGetBattleTaskReward(task)

    let showRerollButton = isTask && !isDone && !canGetReward
      && !u.isEmpty(getBattleTaskRerollCost())
    showObjById("btn_reroll", showRerollButton, taskObj)
    showObjById("btn_receive_reward", canGetReward, taskObj)
    if (showRerollButton)
      placePriceTextToButton(taskObj, "btn_reroll", loc("mainmenu/battleTasks/reroll"), getBattleTaskRerollCost())
  }

  function updateBattleTasksRequirementsList() {
    local config = null
    if (this.curTab == "battle_tasks_list" && this.is_show_battle_tasks_list()) {
      let taskId = this.getCurrentBattleTaskId()
      config = this.battleTasksConfigs?[taskId]
    }

    showObjById("btn_requirements_list", showConsoleButtons.get() && (config?.names ?? []).len() != 0, this.scene)
  }

  function onTaskReroll(obj) {
    let config = this.battleTasksConfigs?[obj?.task_id]
    if (!config)
      return

    let task = config?.originTask
    if (!task)
      return

    if (checkBalanceMsgBox(getBattleTaskRerollCost()))
      this.msgBox("reroll_perform_action",
             loc("msgbox/battleTasks/reroll",
                  { cost = getBattleTaskRerollCost().tostring(),
                    taskName = getBattleTaskNameById(task)
                  }),
      [
        ["yes", @() isSpecialBattleTask(task)
          ? rerollSpecialTask(task)
          : rerollBattleTask(task) ],
        ["no", @() null ]
      ], "yes", { cancel_fn = @() null })
  }

  function onGetRewardForTask(obj) {
    requestBattleTaskReward(obj?.task_id)
  }

  function getCurrentBattleTaskId() {
    let listObj = this.scene.findObject("battle_tasks_list_scroll_block")
    if (checkObj(listObj))
      return listObj.getChild(listObj.getValue())?.task_id

    return null
  }

  function onViewBattleTaskRequirements(obj) {
    local taskId = obj?.task_id
    if (!taskId)
      taskId = this.getCurrentBattleTaskId()

    let config = this.battleTasksConfigs?[taskId]
    if (!config)
      return

    let cfgNames = config?.names ?? []
    if (cfgNames.len() == 0)
      return

    let awards = cfgNames.map(@(id) build_log_unlock_data(
      buildConditionsConfig(
        getUnlockById(id)
    )))

    showUnlocksGroupWnd(awards, loc("unlocks/requirements"))
  }

  function updateBattleTasks() {
    this.loadBattleTasksList()
    this.updateBattleTasksStatusImg()
    this.updateShortBattleTask()
  }

  function onEventBattleTasksIncomeUpdate(_p) { this.updateBattleTasks() }
  function onEventBattleTasksTimeExpired(_p)  { this.updateBattleTasks() }
  function onEventBattleTasksFinishedUpdate(_p) { this.updateBattleTasks() }

  function getWwBattleResults() {
    if (!this.is_show_ww_casualties())
      return null

    let logs = getUserLogsList({
      show = [
        EULT_SESSION_RESULT
      ]
      currentRoomOnly = true
    })

    if (!logs.len())
      return null

    return WwBattleResults().updateFromUserlog(logs[0])
  }

  function loadWwCasualtiesHistory() {
    if (!isWorldWarEnabled())
      return

    let wwBattleResults = this.getWwBattleResults()
    if (!wwBattleResults)
      return

    let taskCallback = Callback(function() {
      let view = wwBattleResults.getView()
      let markup = handyman.renderCached("%gui/worldWar/battleResults.tpl", view)
      let contentObj = this.scene.findObject("ww_casualties_div")
      if (checkObj(contentObj))
        this.guiScene.replaceContentFromText(contentObj, markup, markup.len(), this)
    }, this)

    let operationId = wwBattleResults.operationId
    if (operationId)
      updateOperationPreviewAndDo(operationId, taskCallback)
  }

  function showTabsList() {
    let tabsObj = this.scene.findObject("tabs_list")
    tabsObj.show(true)
    let view = { items = [] }
    local tabValue = 0
    let defaultTabName = this.is_show_ww_casualties() ? "ww_casualties" : ""
    foreach (idx, tabName in this.tabsList) {
      let checkName = $"is_show_{tabName}"
      if (!(checkName in this) || this[checkName]()) {
        let title = getTblValue(tabName, this.tabsTitles,$"#debriefing/{tabName}")
        view.items.append({
          id = tabName
          text = title
          image = tabName == "battle_tasks_list" ? "#ui/gameuiskin#new_reward_icon.svg" : null
        })
        if (tabName == defaultTabName)
          tabValue = idx
      }
    }
    let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(tabValue)
    this.onChangeTab(tabsObj)
    this.updateBattleTasksStatusImg()
  }

    
  function updateShortBattleTask() {
    if (!this.is_show_battle_tasks_list(false))
      return

    let buttonObj = this.scene.findObject("current_battle_tasks")
    if (!checkObj(buttonObj))
      return

    let battleTasksArray = []
    foreach (config in this.battleTasksConfigsSorted) {
      battleTasksArray.append(getBattleTaskView(config, { isShortDescription = true }))
    }
    if (u.isEmpty(battleTasksArray))
      battleTasksArray.append(getBattleTaskView({
        id = "current_battle_tasks"
        text = "#mainmenu/btnBattleTasks"
        shouldRefreshTimer = true
        }, { isShortDescription = true }))

    let data = handyman.renderCached("%gui/unlocks/battleTasksShortItem.tpl", { items = battleTasksArray })
    this.guiScene.replaceContentFromText(buttonObj, data, data.len(), this)
    setBattleTasksUpdateTimer(null, buttonObj)
  }
  


  function is_show_my_stats() {
    return !this.isSpectator  && this.gm != GM_SKIRMISH
  }
  function is_show_players_stats() {
    return this.needPlayersTbl
  }
  function is_show_battle_log() {
    return this.needPlayersTbl && HudBattleLog.getLength() > 0
  }
  function is_show_chat_history() {
    return this.needPlayersTbl && getTblValue("chatLog", this.debriefingResult, "") != ""
  }
  function is_show_left_block() {
    return this.is_show_awards_list() || this.is_show_inventory_gift()
  }
  function is_show_awards_list() {
    return !u.isEmpty(this.awardsList)
  }
  function is_show_inventory_gift() {
    return !this.isCurMissionExtr && (this.giftItems != null)
  }
  function is_show_ww_casualties() {
    return this.needPlayersTbl && isWorldWarEnabled() && getCurMissionRules().isWorldWar
  }
  function is_show_research_list() {
    foreach (unitId, _unitData in this.debriefingResult.exp.aircrafts)
      if (this.isShowUnitInModsResearch(unitId))
        return true
    foreach (ut in unitTypes.types)
      if (this.getResearchUnitInfo(ut.name))
        return true
    if (this.getExpInvestUnitTotal() > 0)
      return true
    return false
  }

  function is_show_battle_tasks_list(isNeedBattleTasksList = true) {
    return (hasFeature("DebriefingBattleTasks") && isBattleTasksAvailable()) &&
      (!isNeedBattleTasksList || this.battleTasksConfigs.len() > 0)
  }

  function is_show_right_block() {
    return this.is_show_research_list() || this.is_show_battle_tasks_list()
  }

  function onChangeTab(obj) {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    this.showTab(obj.getChild(value).id)
    this.updateBattleTasksList()
    this.updateBattleTasksRequirementsList()
  }

  function updateScrollableObjects(tabObj, tabName, isEnable) {
    foreach (objId, val in getTblValue(tabName, this.tabsScrollableObjs, {})) {
      let obj = tabObj.findObject(objId)
      if (checkObj(obj))
        obj["scrollbarShortcuts"] = isEnable ? val : "no"
    }
  }

  function updateListsButtons() {
    if (!this.skipAnim)
      this.skipAnim = this.state == debrState.done
    let isReplayReady = hasFeature("ClientReplay") && is_replay_present() && is_replay_turned_on()
    let player = this.getSelectedPlayer()
    let buttonsList = {
      btn_view_replay = this.skipAnim && isReplayReady
      btn_save_replay = this.skipAnim && isReplayReady && !is_replay_saved()
      btn_parse_replay = this.skipAnim && isReplayReady && canOpenHitsAnalysisWindow()
      btn_user_options = this.skipAnim && (this.curTab == "players_stats") && player && !player.isBot && showConsoleButtons.get()
      btn_view_highlights = this.skipAnim && is_highlights_inited()
    }

    foreach (btn, show in buttonsList)
      showObjById(btn, show, this.scene)
  }

  function onChatLinkClick(_obj, _itype, link) {
    if (link.len() > 3 && link.slice(0, 3) == "PL_") {
      let name = link.slice(3)
      gui_modal_userCard({ name = name })
    }
  }

  function onChatLinkRClick(_obj, _itype, link) {
    if (link.len() > 3 && link.slice(0, 3) == "PL_") {
      let name = link.slice(3)
      let player = this.getPlayerInfo(name)
      if (player)
        showSessionPlayerRClickMenu(this, player, this.getChatLog())
    }
  }

  function onChangeBattlelogFilter(obj) {
    if (!checkObj(obj))
      return
    let filterIdx = obj.getValue()
    saveLocalByAccount("wnd/battleLogFilterDebriefing", filterIdx)
    this.loadBattleLog(filterIdx)
  }

  function onViewReplay(_obj) {
    if (this.isInProgress)
      return

    set_presence_to_player("replay")
    reqUnlockByClient("view_replay")
    autosaveReplay()
    on_view_replay("")
    this.isInProgress = true
  }

  function onSaveReplay(_obj) {
    if (this.isInProgress)
      return
    if (is_replay_saved() || !is_replay_present())
      return

    let afterFunc = function(newName) {
      let result = on_save_replay(newName);
      if (!result) {
        this.msgBox("save_replay_error", loc("replays/save_error"),
          [
            ["ok", function() { } ]
          ], "ok")
      }
      this.updateListsButtons()
    }
    guiModalNameAndSaveReplay(this, afterFunc)
  }

  function onParseReplay(_obj) {
    if (this.isInProgress || !is_replay_present())
      return

    handlersManager.setLastBaseHandlerStartParams({
      handlerName = "DebriefingModal"
      params = {
        skipAnim  =  this.skipAnim
        skipRoulette = this.skipRoulette
      }
    })
    this.guiScene.performDelayed(this, @() openHitsAnalysisWindow())
  }

  function onViewHighlights() {
    if (!is_highlights_inited())
      return

    show_highlights()
  }

  function setGoNext() {
    goDebriefingNextFunc = gui_start_mainmenu 
    if (this.needShowWorldWarOperationBtn()) {
      if (!g_squad_manager.isInSquad() || g_squad_manager.isSquadLeader())
        goDebriefingNextFunc = function() {
          handlersManager.setLastBaseHandlerStartParams({ eventbusName = "gui_start_mainmenu" }) 
          openOperationsOrQueues(true)
        }
      return
    }

    let isMpMode = (this.gameType & GT_COOPERATIVE) || (this.gameType & GT_VERSUS)

    if (sessionLobbyStatus.get() == lobbyStates.IN_DEBRIEFING && haveLobby())
      return
    if (isMpMode && !is_online_available())
      return

    if (isMpMode && this.needGoLobbyAfterStatistics() && this.gm != GM_DYNAMIC) {
      goDebriefingNextFunc = guiStartMpLobby
      return
    }

    if (this.gm == GM_CAMPAIGN) {
      if (this.debriefingResult.isSucceed) {
        let currentCampId = currentCampaignId.get()
        let currentCampMission = currentCampaignMission.get()
        log($"VIDEO: campaign = {currentCampId} mission = {currentCampMission}")
        if ((currentCampMission == "jpn_guadalcanal_m4")
            || (currentCampMission == "us_guadalcanal_m4"))
          needCheckForVictory.set(true)
        selectNextAvailCampaignMission(currentCampId, currentCampMission)
      }
      goDebriefingNextFunc = guiStartMenuCampaign
      return
    }

    if (this.gm == GM_TEST_FLIGHT) {
      goDebriefingNextFunc = @() gui_start_mainmenu_reload({ showShop = true})
      return
    }

    if (this.gm == GM_DYNAMIC) {
      if (isMpMode) {
        if (isInSessionRoom.get() && getDynamicResult() == MISSION_STATUS_RUNNING) {
          goDebriefingNextFunc = guiStartDynamicSummary
          if (is_mplayer_host())
            this.recalcDynamicLayout()
        }
        else
          goDebriefingNextFunc = guiStartDynamicSummaryF
        return
      }

      if (getDynamicResult() == MISSION_STATUS_RUNNING) {
        let settings = DataBlock();
        set_mission_settings("dynlist", dynamicGetList(settings, false))

        let add = []
        for (local i = 0; i < get_mission_settings().dynlist.len(); i++) {
          let misblk = get_mutable_mission_settings().dynlist[i].mission_settings.mission
          misblk.setStr("mis_file", get_mission_settings().layout)
          misblk.setStr("chapter", get_cur_game_mode_name())
          misblk.setStr("type", get_cur_game_mode_name())
          add.append(misblk)
        }
        addMissionListFull(GM_DYNAMIC, add, get_mission_settings().dynlist)
        goDebriefingNextFunc = guiStartDynamicSummary
      }
      else
        goDebriefingNextFunc = guiStartDynamicSummaryF

      return
    }

    if (this.gm == GM_SINGLE_MISSION) {
      let mission = get_mission_settings()?.mission ?? get_current_mission_info_cached()
      goDebriefingNextFunc = is_user_mission(mission)
        ? guiStartMenuUserMissions
        : guiStartMenuSingleMissions

      return
    }

    if (this.roomEvent?.chapter == "competitive")
      goDebriefingNextFunc = @() openLastTournamentWnd(this.roomEvent)
    else
      goDebriefingNextFunc = gui_start_mainmenu
  }

  function needGoLobbyAfterStatistics() {
    return !((this.gameType & GT_COOPERATIVE) || (this.gameType & GT_VERSUS))
  }

  function recalcDynamicLayout() {
    set_mission_settings("layout", dynamicGetLayout())
    
    if (get_mission_settings().layout) {
      let settings = DataBlock();
      set_mission_settings("dynlist", dynamicGetList(settings, false))

      let add = []
      for (local i = 0; i < get_mission_settings().dynlist.len(); i++) {
        let misblk = get_mutable_mission_settings().dynlist[i].mission_settings.mission
        misblk.setStr("mis_file", get_mutable_mission_settings().layout)
        misblk.setStr("chapter", get_cur_game_mode_name())
        misblk.setStr("type", get_cur_game_mode_name())
        misblk.setBool("gt_cooperative", true)
        add.append(misblk)
      }
      addMissionListFull(GM_DYNAMIC, add, get_mission_settings().dynlist)
      set_mission_settings("currentMissionIdx", 0)
      let misBlk = get_mutable_mission_settings().dynlist[get_mission_settings().currentMissionIdx].mission_settings.mission
      misBlk.setInt("_gameMode", GM_DYNAMIC)
      set_mission_settings("missionFull", get_mutable_mission_settings().dynlist[get_mission_settings().currentMissionIdx])
      select_mission_full(misBlk, get_mission_settings().missionFull);
    }
    else {
      log("no mission_settings.layout, destroy session")
      destroySessionScripted("on unable to recalc dynamic layout")
    }
  }

  function afterSave() {
    this.applyReturn()
  }

  function applyReturn() {
    if (goDebriefingNextFunc != guiStartDynamicSummary)
      destroySessionScripted("on leave debriefing")

    if (this.is_show_my_stats())
      setNeedShowRate(this.debriefingResult, this.getMyPlace())

    this.debriefingResult = null
    setDebriefingResult(null)
    this.playCountSound(false)
    this.isInProgress = false

    HudBattleLog.reset()

    if (!goForwardSessionLobbyAfterDebriefing())
      this.goForward(goDebriefingNextFunc)
    this.callbackOnDebriefingClose?()
  }

  function goBack() {
    if (this.state != debrState.done && !this.skipAnim) {
      this.onSkip()
      return
    }

    if (this.isInProgress)
      return

    if (this.needShowWorldWarOperationBtn())
      this.switchWwOperationToCurrent()

    this.isInProgress = true

    autosaveReplay()

    if (!goDebriefingNextFunc)
      goDebriefingNextFunc = gui_start_mainmenu

    invalidateCrewsList()

    if (this.isReplay)
      this.applyReturn()
    else {  
      this.save()
      checkRemnantPremiumAccount()
    }
    this.playCountSound(false)
  }

  function onNext() {
    if (this.state != debrState.done && !this.skipAnim) {
      this.onSkip()
      return
    }

    let needGoToBattle = this.isToBattleActionEnabled()
    this.switchWwOperationToCurrent()
    this.goBack()

    if (needGoToBattle)
      goToBattleAction(this.roomEvent)
  }

  function isToBattleActionEnabled() {
    return (this.skipAnim || this.state == debrState.done)
      && (this.gm == GM_DOMINATION) && !!(this.gameType & GT_VERSUS)
      && !isAnyQueuesActive()
      && !(g_squad_manager.isSquadMember() && g_squad_manager.isMeReady())
      && !hasSessionInLobby()
      && !this.hasAnyFinishedResearch()
      && !this.isSpectator
      && goDebriefingNextFunc == gui_start_mainmenu
      && !checkNonApprovedResearches(true, false)
      && !(isNewbieInited() && !isMeNewbie() && hasEveryDayLoginAward())
  }

  function needShowWorldWarOperationBtn() {
    return isWorldWarEnabled() && isLastFlightWasWwBattle.get()
  }

  function switchWwOperationToCurrent() {
    if (!this.needShowWorldWarOperationBtn())
      return

    let wwBattleRes = this.getWwBattleResults()
    if (wwBattleRes)
      saveLastPlayed(wwBattleRes.getOperationId(), wwBattleRes.getPlayerCountry())
    else {
      let missionRules = getCurMissionRules()
      let operationId = missionRules?.missionParams.customRules.operationId
      if (!operationId)
        return

      saveLastPlayed(operationId.tointeger(), profileCountrySq.get())
    }

    goDebriefingNextFunc = function() {
      handlersManager.setLastBaseHandlerStartParams({ eventbusName = "gui_start_mainmenu" })
      openWWMainWnd()
    }
  }

  function updateStartButton() {
    if (this.state != debrState.done)
      return

    let showWorldWarOperationBtn = this.needShowWorldWarOperationBtn()
    let isToBattleBtnVisible = this.isToBattleActionEnabled() && !showWorldWarOperationBtn

    showObjectsByTable(this.scene, {
      btn_next = true
      btn_back = isToBattleBtnVisible
    })

    let btnNextLocId = showWorldWarOperationBtn ? "worldWar/stayInOperation"
      : !isToBattleBtnVisible ? "mainmenu/btnOk"
      : g_squad_manager.isSquadMember() ? "mainmenu/btnReady"
      : getToBattleLocId()

    setDoubleTextToButton(this.scene, "btn_next", loc(btnNextLocId))

    if (isToBattleBtnVisible)
      this.scene.findObject("btn_back").setValue(loc("mainmenu/toHangar"))
  }

  function onEventSquadSetReady(_p) {
    this.updateStartButton()
  }

  function onEventSquadStatusChanged(_p) {
    this.updateStartButton()
  }

  function onEventQueueChangeState(_params) {
    this.updateStartButton()
  }

  onEventToBattleLocChanged = @(_params) this.updateStartButton()

  function onEventMatchingDisconnect(_p) {
    goDebriefingNextFunc = startLogout
  }

  function isDelayedLogoutOnDisconnect() {
    goDebriefingNextFunc = startLogout
    return true
  }

  function throwBattleEndEvent() {
    let eventId = getTblValue("eventId", this.debriefingResult)
    if (eventId)
      broadcastEvent("EventBattleEnded", { eventId = eventId })
    broadcastEvent("BattleEnded", { battleResult = this.debriefingResult?.exp.result })
  }

  function checkPopupWindows() {
    let country = this.getDebriefingCountry()

    
    let wnd_unlock_gained = getUserLogsList({
      show = [EULT_NEW_UNLOCK]
      unlocks = [UNLOCKABLE_AIRCRAFT, UNLOCKABLE_AWARD]
      filters = { popupInDebriefing = [true] }
      currentRoomOnly = true
      disableVisible = true
    })
    foreach (logObj in wnd_unlock_gained)
      showUnlockWnd(build_log_unlock_data(logObj))

    
    let new_rank = getPlayerRankByCountry(country)
    local old_rank = playerRankByCountries?[country] ?? new_rank

    if (country != "" && country != "country_0" &&
        !isCountryAvailable(country) && getPlayerExpByCountry(country) > 0) {
      unlockCountry(country)
      old_rank = -1 
    }

    if (new_rank > old_rank) {
      let gained_ranks = [];

      for (local i = old_rank + 1; i <= new_rank; i++)
        gained_ranks.append(i);
      checkRankUpWindow(country, old_rank, new_rank);
    }

    
    let country_unlock_gained = getUserLogsList({
      show = [EULT_NEW_UNLOCK]
      unlocks = [UNLOCKABLE_COUNTRY]
      currentRoomOnly = true
      disableVisible = true
    })
    foreach (logObj in country_unlock_gained) {
      showUnlockWnd(build_log_unlock_data(logObj))
      if (("unlockId" in logObj) && logObj.unlockId != country && isInArray(logObj.unlockId, shopCountriesList))
        unlockCountry(logObj.unlockId)
    }

    
    let tornament_special_rewards = getUserLogsList({
      show = [EULT_CHARD_AWARD]
      currentRoomOnly = true
      disableVisible = true
      filters = { rewardType = ["TournamentReward"] }
    })

    let rewardsArray = []
    foreach (logObj in tornament_special_rewards)
      rewardsArray.extend(getTournamentRewardData(logObj))

    foreach (rewardConfig in rewardsArray)
      showUnlockWnd(rewardConfig)

    if (!this.skipRoulette)
      this.openGiftTrophy()
  }

  function updateInfoText() {
    if (this.debriefingResult == null)
      return
    local infoText = ""
    local infoColor = "active"

    let wpdata = get_session_warpoints()

    if (this.debriefingResult.exp?.noActivityPlayer ?? false) {
      infoText = loc("MISSION_NO_ACTIVITY")
      infoColor = "bad"
    }
    else if (this.debriefingResult.exp.result == STATS_RESULT_ABORTED_BY_KICK) {
      infoText = loc("MISSION_ABORTED_BY_KICK")
      infoColor = "bad"
    }
    else if (this.debriefingResult.exp.result == STATS_RESULT_ABORTED_BY_ANTICHEAT) {
      infoText = this.getKickReasonLocText()
      infoColor = "bad"
    }
    else if ((this.gm == GM_DYNAMIC || this.gm == GM_BUILDER) && wpdata.isRewardReduced)
      infoText = loc("debriefing/award_reduced")
    else {
      local hasAnyReward = false
      foreach (source in [ "Total", "Mission" ])
        foreach (currency in [ "exp", "wp", "gold" ])
          if ((this.debriefingResult.exp?[$"{currency}{source}"] ?? 0) > 0)
            hasAnyReward = true

      if (!hasAnyReward) {
        if (this.gm == GM_SINGLE_MISSION || this.gm == GM_CAMPAIGN || this.gm == GM_TRAINING) {
          if (this.debriefingResult.isSucceed) {
            let isCompletedBefore = get_mission_progress(locCurrentMissionName()) < MIS_PROGRESS.UNLOCKED
            infoText = isCompletedBefore ? loc("debriefing/award_already_received")
              : loc("debriefing/no_award")
          }
        }
        else if (this.isMp && !isDebriefingResultFull() && this.gm == GM_DOMINATION) {
          infoText = loc("debriefing/most_award_after_battle")
          infoColor = "userlog"
        }
        else if (this.isMp && this.debriefingResult.exp.result == STATS_RESULT_IN_PROGRESS && !(this.gameType & GT_RACE))
          infoText = loc("debriefing/exp_and_reward_will_be_later")
      }
    }

    let isShow = infoText != ""
    let infoObj = this.scene.findObject("stat_info_text")
    infoObj.show(isShow)
    if (isShow) {
      infoObj.setValue(infoText)
      infoObj["overlayTextColor"] = infoColor
      this.guiScene.applyPendingChanges(false)
      infoObj.scrollToView()
    }
  }

  function getBoostersText() {
    let textsList = []
    let activeBoosters = getTblValue("activeBoosters", this.debriefingResult, [])
    if (activeBoosters.len() > 0)
      foreach (effectType in boosterEffectType) {
        let boostersArray = []
        foreach (_idx, block in activeBoosters) {
          let item = findItemById(block.itemId)
          if (item && effectType.checkBooster(item))
            boostersArray.append(item)
        }

        if (boostersArray.len())
          textsList.append(getActiveBoostersDescription(boostersArray, effectType))
      }
    return "\n\n".join(textsList, true)
  }

  function getBoostersTotalEffects() {
    let activeBoosters = getTblValue("activeBoosters", this.debriefingResult, [])
    let boostersArray = []
    foreach (block in activeBoosters) {
      let item = findItemById(block.itemId)
      if (item)
        boostersArray.append(item)
    }
    return getBoostersEffects(boostersArray)
  }

  function getInvetoryGiftActionData() {
    if (!this.giftItems)
      return null

    let itemDefId = this.giftItems?[0]?.item
    let wSet = workshop.getSetByItemId(itemDefId)
    if (wSet && wSet.isVisible())
      return {
        btnText = loc("items/workshop")
        action = @() wSet.needShowPreview() ? workshopPreview.open(wSet)
          : gui_start_items_list(itemsTab.WORKSHOP, {
              curSheet = { id = wSet.getShopTabId() },
              curItem = getInventoryItemById(itemDefId)
              initSubsetId = wSet.getSubsetIdByItemId(itemDefId)
            })
      }

    return null
  }

  function updateInventoryButton() {
    let actionData = this.getInvetoryGiftActionData()
    let actionBtn = showObjById("btn_inventory_gift_action", actionData != null, this.scene)
    if (actionData && actionBtn)
      setColoredDoubleTextToButton(this.scene, "btn_inventory_gift_action", actionData.btnText)
  }

  function onInventoryGiftAction() {
    let actionData = this.getInvetoryGiftActionData()
    if (actionData)
      actionData.action()
  }

  getUserlogsMask = @() this.state == debrState.done && this.isSceneActiveNoModals()
    ? USERLOG_POPUP.OPEN_TROPHY
    : USERLOG_POPUP.NONE

  function onEventModalWndDestroy(p) {
    base.onEventModalWndDestroy(p)
    if (this.state == debrState.done && this.isSceneActiveNoModals())
      ::checkNewNotificationUserlogs()
  }

  function onEventProfileUpdated(_p) {
    if (this.debriefingResult == null || this.giftItems != null)
      return

    updateDebriefingResultGiftItemsInfo()
    this.giftItems = this.groupGiftsById(this.debriefingResult?.giftItemsInfo)
    if (this.state >= debrState.showMyStats && this.is_show_my_stats())
      this.updateMyStatObjects()
  }

  function getChatLog() {
    return this.debriefingResult?.logForBanhammer
  }

  function getDebriefingCountry() {
    if (this.debriefingResult)
      return this.debriefingResult.country
    return ""
  }

  function getMissionBonus() {
    if (this.gm != GM_DOMINATION)
      return {}

    let isWin = this.debriefingResult.isSucceed

    let bonusWp = (isWin ? get_warpoints_blk()?.winK : get_warpoints_blk()?.defeatK) ?? 0.0
    let wp = (bonusWp > 0) ? ceil(bonusWp * 100) : 0
    let textWp = (wp > 0) ? $"+{wp}%" : ""

    let mis = get_current_mission_info_cached()
    let useTimeAwardingExp = mis?.useTimeAwardingEconomics ?? false
    local textRp = ""
    if (!useTimeAwardingExp) {
      let rBlk = get_ranks_blk()
      let missionRp = (isWin ? rBlk?.expForVictoryVersusPerSec : rBlk?.expForPlayingVersusPerSec) ?? 0.0
      let baseRp = rBlk?.expBaseVersusPerSec ?? 0
      if (missionRp > 0 && baseRp > 0) {
        let rp = ceil((missionRp.tofloat() / baseRp - 1.0) * 100)
        textRp = $"+{rp}%"
      }
    }
    return {
      textWp
      textRp
    }
  }

  function getCurAwardText() {
    return Cost(get_premium_reward_wp(), 0, get_premium_reward_xp()).tostring()
  }

  getLocalTeam = @() getLocalTeamForMpStats(this.debriefingResult.localTeam)
  getMplayersList = @(team = GET_MPLAYERS_LIST) team == GET_MPLAYERS_LIST
    ? this.debriefingResult.mplayers_list
    : this.debriefingResult.mplayers_list.filter(@(player) player.team == team)
  getOverrideCountryIconByTeam = @(team) this.debriefingResult.overrideCountryIconByTeam[team]

  function initStatsMissionParams() {
    this.gameMode = this.debriefingResult.gm
    this.isOnline = isLoggedIn.get()

    this.isTeamsRandom = !this.isTeamplay || this.gameMode == GM_DOMINATION
    if (this.debriefingResult.isInRoom || this.isReplay)
      this.isTeamsWithCountryFlags = this.isTeamplay &&
        (this.debriefingResult.missionDifficultyInt > 0 || !this.debriefingResult.isSymmetric)

    this.missionObjectives = this.debriefingResult.missionObjectives
  }

  isInited = true
  state = 0
  skipAnim = false
  skipRoulette = false
  isMp = false
  isReplay = false
  isCurMissionExtr = false
  

  tabsList = [ "my_stats", "players_stats", "ww_casualties", "awards_list", "battle_tasks_list", "battle_log", "chat_history" ]
  tabsTitles = { awards_list = "#profile/awards", battle_tasks_list = "#userlog/page/battletasks" }
  tabsScrollableObjs = {
    my_stats      = { my_stats_scroll_block = "yes", researches_scroll_block = "left" }
    players_stats = { players_stats_scroll_block = "yes" }
    ww_casualties = { ww_battle_results_scroll_block = "yes" }
    awards_list   = { awards_list_scroll_block = "yes" }
    battle_tasks_list = { battle_tasks_list_scroll_block = "yes" }
    battle_log    = { battle_log_div = "yes" }
    chat_history  = { chat_history_scroll_block = "yes" }
  }
  curTab = ""
  nextWndDelay = 1.0

  needPlayersTbl = false
  playersTbl = null
  curPlayersTbl = null
  playersRowTime = 0.05
  playersTblDone = false
  myPlaceTime = 0.7
  minPlayersTime = 0.7

  playerStatsObj = null
  isCountSoundPlay = false
  needPlayCount = false
  statsTimer = 0.0
  statsTime = 0.3
  statsNextTime = 0.15
  totalStatsTime = 0.6
  statsBonusTime = 0.3
  statsBonusDelay = 0.2
  curStatsIdx = -1

  totalObj = null
  totalTimer = 0.0
  totalRow = null
  totalCurValues = null
  totalTarValues = null

  awardsList = null
  curAwardIdx = 0

  streakAwardsList = null
  challengesAwardsList = null
  unlocksAwardsList = null

  currentAwardsList = null
  currentAwardsListConfig = null
  currentAwardsListIdx = 0

  awardsData = null

  awardOffset = 0
  awardShift = 0
  awardsAppearTime = 2.0 
  awardDelay = 0.25
  awardFlyTime = 0.5

  usedUnitTypes = null

  isInProgress = false
}

return {
  guiStartDebriefingFull
}
