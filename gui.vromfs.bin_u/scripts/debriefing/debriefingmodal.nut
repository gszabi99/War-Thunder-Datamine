let stdMath = require("%sqstd/math.nut")
let time = require("%scripts/time.nut")
let workshop = require("%scripts/items/workshop/workshop.nut")
let { updateModItem } = require("%scripts/weaponry/weaponryVisual.nut")
let workshopPreview = require("%scripts/items/workshop/workshopPreview.nut")
let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { setDoubleTextToButton, setColoredDoubleTextToButton,
  placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isModResearched,
        getModificationByName,
        findAnyNotResearchedMod } = require("%scripts/weaponry/modificationInfo.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { needLogoutAfterSession, startLogout } = require("%scripts/login/logout.nut")
let activityFeedPostFunc = require("%scripts/social/activityFeed/activityFeedPostFunc.nut")
let { MODIFICATION } = require("%scripts/weaponry/weaponryTooltips.nut")
let { boosterEffectType, getBoostersEffects } = require("%scripts/items/boosterEffect.nut")
let { fillItemDescr, getActiveBoostersDescription } = require("%scripts/items/itemVisual.nut")
let { getToBattleLocId } = require("%scripts/viewUtils/interfaceCustomization.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { setNeedShowRate } = require("%scripts/user/suggestionRateGame.nut")
let { sourcesConfig } = require("%scripts/debriefing/rewardSources.nut")
let { minValuesToShowRewardPremium, playerRankByCountries } = require("%scripts/ranks.nut")
let { getDebriefingResult, getDynamicResult, debriefingRows, isDebriefingResultFull,
gatherDebriefingResult, getCountedResultId, debriefingAddVirtualPremAcc, getTableNameById
} = require("%scripts/debriefing/debriefingFull.nut")
let { needCheckForVictory } = require("%scripts/missions/missionsUtils.nut")
let { getTournamentRewardData } = require("%scripts/userLog/userlogUtils.nut")
let { getGoToBattleAction } = require("%scripts/debriefing/toBattleAction.nut")
let { checkRankUpWindow } = require("%scripts/debriefing/rankUpModal.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")
let { havePremium } = require("%scripts/user/premium.nut")

const DEBR_LEADERBOARD_LIST_COLUMNS = 2
const DEBR_AWARDS_LIST_COLUMNS = 3
const DEBR_MYSTATS_TOP_BAR_GAP_MAX = 6
const LAST_WON_VERSION_SAVE_ID = "lastWonInVersion"
const VISIBLE_GIFT_NUMBER = 4

enum DEBR_THEME {
  WIN       = "win"
  LOSE      = "lose"
  PROGRESS  = "progress"
}

let debriefingSkipAllAtOnce = true

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

::go_debriefing_next_func <- null

::gui_start_debriefingFull <- function gui_start_debriefingFull(params = {})
{
  ::handlersManager.loadHandler(::gui_handlers.DebriefingModal, params)
}

::gui_start_debriefing_replay <- function gui_start_debriefing_replay()
{
  gui_start_debriefing()

  ::add_msg_box("replay_question", ::loc("mainmenu/questionSaveReplay"), [
        ["yes", function()
        {
          let guiScene = ::get_gui_scene()
          guiScene.performDelayed(getroottable(), function()
          {
            if (::debriefing_handler != null)
            {
              ::debriefing_handler.onSaveReplay(null)
            }
          })
        }],
        ["no", function() { if (::debriefing_handler != null) ::debriefing_handler.onSelect(null) } ],
        ["viewAgain", function()
        {
          let guiScene = ::get_gui_scene()
          guiScene.performDelayed(getroottable(), function()
              {
            if (::debriefing_handler != null)
              ::debriefing_handler.onViewReplay(null)
          })
        }]
        ], "yes")
  ::update_msg_boxes()
}

::gui_start_debriefing <- function gui_start_debriefing()
{
  if (needLogoutAfterSession.value)
  {
    ::destroy_session_scripted()
    //need delay after destroy session before is_multiplayer become false
    ::get_gui_scene().performDelayed(::getroottable(), startLogout)
    return
  }

  let gm = ::get_game_mode()
  if (::back_from_replays != null)
  {
     dagor.debug("gui_nav gui_start_debriefing back_from_replays");
     let temp_func = ::back_from_replays
     dagor.debug("gui_nav back_from_replays = null");
     ::back_from_replays = null
     temp_func()
     ::update_gamercards()
     return
  }
  else
    dagor.debug("gui_nav gui_start_debriefing back_from_replays is null");

  if (gm == ::GM_BENCHMARK)
  {
    let title = ::loc_current_mission_name()
    let benchmark_data = ::stat_get_benchmark()
    ::gui_start_mainmenu()
    ::gui_start_modal_wnd(::gui_handlers.BenchmarkResultModal, {title = title benchmark_data = benchmark_data})
    return
  }
  if (gm == ::GM_CREDITS || gm == ::GM_TRAINING)
  {
     ::gui_start_mainmenu();
     return
  }
  if (gm == ::GM_TEST_FLIGHT)
  {
    if (::last_called_gui_testflight)
      ::last_called_gui_testflight()
    else
      ::gui_start_decals();
    ::update_gamercards()
    return
  }
  if (::custom_miss_flight)
  {
    ::custom_miss_flight = false
    ::gui_start_mainmenu()
    return
  }

  ::gui_start_debriefingFull()
}

::gui_handlers.DebriefingModal <- class extends ::gui_handlers.MPStatistics
{
  sceneBlkName = "%gui/debriefing/debriefing.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  static awardsListsConfig = {
    streaks = {
      filter = {
          show = [::EULT_NEW_STREAK]
          unlocks = [::UNLOCKABLE_STREAK]
          filters = { popupInDebriefing = [false, null] }
          currentRoomOnly = true
          disableVisible = true
        }
      align = ALIGN.TOP
      listObjId = "awards_list_streaks"
      startplaceObId = "start_award_place_streaks"
    }
    unlocks = {
      filter = {
        show = [::EULT_NEW_UNLOCK]
        unlocks = [::UNLOCKABLE_AIRCRAFT, ::UNLOCKABLE_SKIN, ::UNLOCKABLE_DECAL, ::UNLOCKABLE_ATTACHABLE,
                   ::UNLOCKABLE_WEAPON, ::UNLOCKABLE_DIFFICULTY, ::UNLOCKABLE_ENCYCLOPEDIA, ::UNLOCKABLE_PILOT,
                   ::UNLOCKABLE_MEDAL, ::UNLOCKABLE_CHALLENGE, ::UNLOCKABLE_ACHIEVEMENT, ::UNLOCKABLE_TITLE]
        filters = { popupInDebriefing = [false, null] }
        currentRoomOnly = true
        disableVisible = true
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
  mGameMode = null
  playersInfo = null //it is SessionLobby.playersInfo for debriefing statistics info

  pveRewardInfo = null
  battleTasksConfigs = {}
  shouldBattleTasksListUpdate = false

  giftItems = null
  isAllGiftItemsKnown = false

  isFirstWinInMajorUpdate = false
  isForceShowMyStatsRightBlock = false

  debugUnlocks = 0  //show at least this amount of unlocks received from userlogs even disabled.
  debriefingResult = null

  function initScreen()
  {
    debriefingResult = getDebriefingResult()
    if (debriefingResult == null) {
      ::script_net_assert_once("not inited debriefing result", "try to get debriefing data")
      gatherDebriefingResult()
      debriefingResult = getDebriefingResult()
    }
    gm = debriefingResult.gm
    mGameMode = debriefingResult.mGameMode
    gameType = debriefingResult.gameType
    isTeamplay = debriefingResult.isTeamplay
    isSpectator = debriefingResult.isSpectator
    playersInfo = debriefingResult.playersInfo
    isMp = debriefingResult.isMp
    isReplay = debriefingResult.isReplay
    isForceShowMyStatsRightBlock = ::has_feature("Profile")

    if (::disable_network()) //for correct work in disable_menu mode
      ::update_gamercards()

    scene.findObject("content_frame").width = isForceShowMyStatsRightBlock ? "1.4@sf" : "1.0@sf"

    showTab("") //hide all tabs

    ::set_presence_to_player("menu")
    initStatsMissionParams()
    ::SessionLobby.checkLeaveRoomInDebriefing()
    ::close_cur_voicemenu()
    ::enableHangarControls(true)

    // Debriefing shows on on_hangar_loaded event, but looks like DoF resets in this frame too.
    // DoF changing works unstable on this frame, but works 100% good on next guiscene act.
    guiScene.performDelayed(this, function() { ::handlersManager.updateSceneBgBlur(true) })

    if (isInited)
      scene.findObject("debriefing_timer").setUserData(this)

    playerStatsObj = scene.findObject("stat_table")
    numberOfWinningPlaces = ::getTblValue("numberOfWinningPlaces", debriefingResult, -1)
    pveRewardInfo = ::getTblValue("pveRewardInfo", debriefingResult)
    giftItems = groupGiftsById(debriefingResult?.giftItemsInfo)
    foreach(idx, row in debriefingRows)
      if (row.show)
      {
        curStatsIdx = idx
        break
      }

    handleActiveWager()
    handlePveReward()

    //update title
    local resTitle = ""
    local resReward = " "
    local resTheme = DEBR_THEME.PROGRESS

    if (isMp)
    {
      let mpResult = debriefingResult.exp.result
      resTitle = ::loc("MISSION_IN_PROGRESS")

      if (isSpectator
           && (gameType & ::GT_VERSUS)
           && (mpResult == ::STATS_RESULT_SUCCESS
                || mpResult == ::STATS_RESULT_FAIL))
      {
        if (isTeamplay)
        {
          local myTeam = Team.A
          foreach(player in debriefingResult.mplayers_list)
            if (::getTblValue("isLocal", player, false))
            {
              myTeam = player.team
              break
            }
          let winner = ((myTeam == Team.A) == debriefingResult.isSucceed) ? "A" : "B"
          resTitle = ::loc("multiplayer/team_won") + ::loc("ui/colon") + ::loc("multiplayer/team" + winner)
          resTheme = DEBR_THEME.WIN
        }
        else
        {
          resTitle = ::loc("MISSION_FINISHED")
          resTheme = DEBR_THEME.WIN
        }
      }
      else if (mpResult == ::STATS_RESULT_SUCCESS)
      {
        resTitle = ::loc("MISSION_SUCCESS")
        resTheme = DEBR_THEME.WIN

        let victoryBonus = (isMp && isDebriefingResultFull()) ? getMissionBonusText() : ""
        if (victoryBonus != "")
          resReward = "".concat(::loc("debriefing/MissionWinReward"), ::loc("ui/colon"), victoryBonus)

        let currentMajorVersion = ::get_game_version() >> 16
        let lastWinVersion = ::load_local_account_settings(LAST_WON_VERSION_SAVE_ID, 0)
        isFirstWinInMajorUpdate = currentMajorVersion > lastWinVersion
        save_local_account_settings(LAST_WON_VERSION_SAVE_ID, currentMajorVersion)
      }
      else if (mpResult == ::STATS_RESULT_FAIL)
      {
        resTitle = ::loc("MISSION_FAIL")
        resTheme = DEBR_THEME.LOSE

        let loseBonus = (isMp && isDebriefingResultFull()) ? getMissionBonusText() : ""
        if (loseBonus != "")
          resReward = "".concat(::loc("debriefing/MissionLoseReward"), ::loc("ui/colon"), loseBonus)
      }
      else if (mpResult == ::STATS_RESULT_ABORTED_BY_KICK)
      {
        resReward = ::colorize("badTextColor", getKickReasonLocText())
        resTheme = DEBR_THEME.LOSE
      }
    }
    else
    {
      resTitle = ::loc(debriefingResult.isSucceed ? "MISSION_SUCCESS" : "MISSION_FAIL")
      resTheme = debriefingResult.isSucceed ? DEBR_THEME.WIN : DEBR_THEME.LOSE
    }

    scene.findObject("result_title").setValue(resTitle)
    scene.findObject("result_reward").setValue(resReward)

    gatherAwardsLists()

    //update mp table
    needPlayersTbl = isMp && !(gameType & ::GT_COOPERATIVE) && isDebriefingResultFull()
    setSceneTitle(getCurMpTitle(), null, "dbf_title")

    if (!isDebriefingResultFull())
    {
      foreach(tName in ["no_air_text", "research_list_text"])
      {
        let obj = scene.findObject(tName)
        if (::checkObj(obj))
          obj.setValue(::loc("MISSION_IN_PROGRESS"))
      }
    }

    if (!isReplay)
    {
      setGoNext()
      if (gm == ::GM_DYNAMIC)
      {
        ::save_profile(true)
        if (getDynamicResult() > ::MISSION_STATUS_RUNNING)
          ::destroy_session_scripted()
        else
          ::g_squad_manager.setReadyFlag(true)
      }
    }
    ::first_generation <- false //for dynamic campaign
    isInited = false
    check_logout_scheduled()

    ::g_squad_utils.updateMyCountryData() //to update broken airs for squad.

    handleNoAwardsCaption()

    if (!isSpectator && !isReplay)
      ::add_big_query_record("show_debriefing_screen",
        ::save_to_json({
          gm = gm
          economicName = ::events.getEventEconomicName(mGameMode)
          difficulty = mGameMode?.difficulty ?? ::SessionLobby.getMissionData()?.difficulty ?? ""
          sessionId = debriefingResult?.sessionId ?? ""
          sessionTime = debriefingResult?.exp?.sessionTime ?? 0
          originalMissionName = ::SessionLobby.getMissionName(true)
          missionsComplete = ::my_stats.getMissionsComplete()
          result = resTheme
        }))
    let sessionIdObj = scene.findObject("txt_session_id")
    if (sessionIdObj?.isValid())
      sessionIdObj.setValue(debriefingResult?.sessionId ?? "")
  }

  function gatherAwardsLists()
  {
    awardsList = []

    streakAwardsList = getAwardsList(awardsListsConfig.streaks.filter)

    let wpBattleTrophy = ::getTblValue("wpBattleTrophy", debriefingResult.exp, 0)
    if (wpBattleTrophy > 0)
      streakAwardsList.append(getFakeUnlockDataByWpBattleTrophy(wpBattleTrophy))

    unlockAwardsList = getAwardsList(awardsListsConfig.unlocks.filter)

    ::showBtnTable(scene, {
      [awardsListsConfig.streaks.listObjId] = streakAwardsList.len() > 0,
      [awardsListsConfig.unlocks.listObjId] = unlockAwardsList.len() > 0,
    })

    awardsList.extend(streakAwardsList)
    awardsList.extend(unlockAwardsList)

    currentAwardsList = streakAwardsList
    currentAwardsListConfig = awardsListsConfig.streaks
  }

  function getFakeUnlockData(config)
  {
    let res = {}
    foreach(key, value in ::default_unlock_data)
      res[key] <- (key in config)? config[key] : value
    foreach(key, value in config)
      if (!(key in res))
        res[key] <- value
    return res
  }

  getFakeUnlockDataByWpBattleTrophy = @(wpBattleTrophy) getFakeUnlockData({
    iconStyle = ::trophyReward.getWPIcon(wpBattleTrophy)
    title = ::loc("debriefing/BattleTrophy"),
    desc = ::loc("debriefing/BattleTrophy/desc"),
    rewardText = ::Cost(wpBattleTrophy).toStringWithParams({isWpAlwaysShown = true}),
  })

  function getAwardsList(filter)
  {
    let res = []
    local logsList = getUserLogsList(filter)
    logsList = ::combineSimilarAwards(logsList)
    for (local i = logsList.len()-1; i >= 0; i--)
      res.append(::build_log_unlock_data(logsList[i]))

    //add debugUnlocks
    if (!::is_dev_version || debugUnlocks <= res.len())
      return res

    let dbgFilter = clone filter
    dbgFilter.currentRoomOnly = false
    logsList = getUserLogsList(dbgFilter)
    if (!logsList.len())
    {
      ::dlog("Not found any unlocks in userlogs for debug") // warning disable: -forbidden-function
      return res
    }

    let addAmount = debugUnlocks - res.len()
    for(local i = 0; i < addAmount; i++)
      res.append(::build_log_unlock_data(logsList[i % logsList.len()]))

    return res
  }

  function handleNoAwardsCaption()
  {
    local text = ""
    local color = ""

    if(::getTblValue("haveTeamkills", debriefingResult, false))
    {
      text = ::loc("debriefing/noAwardsCaption")
      color = "bad"
    }
    else if (debriefingResult?.exp.eacKickMessage != null)
    {
      text = "".concat(getKickReasonLocText(), "\n",
        ::loc("multiplayer/reason"), ::loc("ui/colon"),
        ::colorize("activeTextColor", debriefingResult.exp.eacKickMessage))

      if (::has_feature("AllowExternalLink") && !::is_vendor_tencent())
        ::showBtn("btn_no_awards_info", true, scene)
      else
        text = "".concat(text, "\n",
          ::loc("msgbox/error_link_format_game"), ::loc("ui/colon"), ::loc("url/support/easyanticheat"))

      color = "bad"
    }
    else if (pveRewardInfo && pveRewardInfo.warnLowActivity)
    {
      text = ::loc("debriefing/noAwardsCaption/noMinActivity")
      color = "userlog"
    }

    if (text == "")
      return

    let blockObj = ::showBtn("no_awards_block", true, scene)
    let captionObj = blockObj && blockObj.findObject("no_awards_caption")
    if (!::check_obj(captionObj))
      return
    captionObj.setValue(text)
    captionObj.overlayTextColor = color
  }

  function getKickReasonLocText()
  {
    if (debriefingResult?.exp.eacKickMessage != null)
      return ::loc("MISSION_ABORTED_BY_KICK/EAC")
    return ::loc("MISSION_ABORTED_BY_KICK")
  }

  function onNoAwardsInfoBtn()
  {
    if (debriefingResult?.exp.eacKickMessage != null)
      openUrl(::loc("url/support/easyanticheat/kick_reasons"), false, false, "support_eac")
  }

  function reinitTotal()
  {
    if (!is_show_my_stats())
      return

    if (state != debrState.showMyStats && state != debrState.showBonuses)
      return

    //find and update Total
    totalRow = getDebriefingRowById("Total")
    if (!totalRow)
      return

    let premTeaser = getPremTeaserInfo()

    totalCurValues = totalCurValues || {}
    totalTarValues = {}

    foreach(currency in [ "exp", "wp" ])
    {
      foreach(suffix in [ "", "Teaser" ])
        if (!(currency + suffix in totalCurValues))
          totalCurValues[currency + suffix] <- 0

      let totalKey = getCountedResultId(totalRow, state, currency)
      totalCurValues[currency] <- ::getTblValue(currency, totalCurValues, 0)
      totalTarValues[currency] <- ::getTblValue(totalKey, debriefingResult.counted_result_by_debrState, 0)
      totalCurValues[currency + "Teaser"] <- ::getTblValue(currency + "Teaser", totalCurValues, 0)
      totalTarValues[currency + "Teaser"] <- premTeaser[currency]
    }

    let canSuggestPrem = canSuggestBuyPremium()

    local tooltip = ""
    if (canSuggestPrem)
    {
      let currencies = []
      if (premTeaser.exp > 0)
        currencies.append(::Cost().setRp(premTeaser.exp).tostring())
      if (premTeaser.wp  > 0)
        currencies.append(::Cost(premTeaser.wp).tostring())
      tooltip = ::loc("debriefing/PremiumNotEarned") + ::loc("ui/colon") + "\n" + ::g_string.implode(currencies, ::loc("ui/comma"))
    }

    totalObj = scene.findObject("wnd_total")
    let markup = ::handyman.renderCached("%gui/debriefing/debriefingTotals", {
      showTeaser = canSuggestPrem && premTeaser.isPositive
      canSuggestPrem = canSuggestPrem
      exp = ::Cost().setRp(totalCurValues["exp"]).tostring()
      wp  = ::Cost(totalCurValues["wp"]).tostring()
      expTeaser = ::Cost().setRp(premTeaser.exp).toStringWithParams({isColored = false})
      wpTeaser  = ::Cost(premTeaser.wp).toStringWithParams({isColored = false})
      teaserTooltip = tooltip
    })
    guiScene.replaceContentFromText(totalObj, markup, markup.len(), this)
    updateTotal(0.0)
  }

  function handleActiveWager()
  {
    let activeWagerData = ::getTblValue("activeWager", debriefingResult, null)
    if (!activeWagerData)
      return

    let wager = ::ItemsManager.findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
                  ::ItemsManager.findItemById(activeWagerData.wagerShopId)
    if (wager == null) // This can happen if item ended and was removed from shop.
      return

    let containerObj = scene.findObject("active_wager_container")
    if (!::checkObj(containerObj))
      return

    containerObj.show(true)

    let iconObj = containerObj.findObject("active_wager_icon")
    if (::checkObj(iconObj))
      wager.setIcon(iconObj, {bigPicture = false})

    let wagerResult = activeWagerData.wagerResult
    let isWagerHasResult = wagerResult != null
    let isResultSuccess = wagerResult == "WagerWin" || wagerResult == "WagerStageWin"
    let isWagerEnded = wagerResult == "WagerWin" || wagerResult == "WagerFail"

    if (isWagerHasResult)
      showActiveWagerResultIcon(isResultSuccess)

    let tooltipObj = containerObj.findObject("active_wager_tooltip")
    if (::checkObj(tooltipObj))
    {
      tooltipObj.setUserData(activeWagerData)
      tooltipObj.enable(!isWagerEnded && isWagerHasResult)
    }

    if (!isWagerHasResult)
      containerObj.tooltip = ::loc("debriefing/wager_result_will_be_later")
    else if (isWagerEnded)
    {
      local endedWagerText = activeWagerData.wagerText
      endedWagerText += "\n" + ::loc("items/wager/numWins", {
        numWins = activeWagerData.wagerNumWins,
        maxWins = wager.maxWins
      })
      endedWagerText += "\n" + ::loc("items/wager/numFails", {
        numFails = activeWagerData.wagerNumFails,
        maxFails = wager.maxFails
      })
      containerObj.tooltip = endedWagerText
    }

    handleActiveWagerText(activeWagerData)
    updateMyStatsTopBarArrangement()
  }

  function handleActiveWagerText(activeWagerData)
  {
    let wager = ::ItemsManager.findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
                  ::ItemsManager.findItemById(activeWagerData.wagerShopId)
    if (wager == null)
      return
    let wagerResult = activeWagerData.wagerResult
    if (wagerResult != "WagerWin" && wagerResult != "WagerFail")
      return
    let textObj = scene.findObject("active_wager_text")
    if (::checkObj(textObj))
      textObj.setValue(activeWagerData.wagerText)
  }

  function onWagerTooltipOpen(obj)
  {
    if (!::checkObj(obj))
      return
    let activeWagerData = obj.getUserData()
    if (activeWagerData == null)
      return
    let wager = ::ItemsManager.findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
                  ::ItemsManager.findItemById(activeWagerData.wagerShopId)
    if (wager == null)
      return
    guiScene.replaceContent(obj, "%gui/items/itemTooltip.blk", this)
    fillItemDescr(wager, obj, this)
  }

  function showActiveWagerResultIcon(success)
  {
    let iconObj = scene.findObject("active_wager_result_icon")
    if (!::checkObj(iconObj))
      return
    iconObj["background-image"] = success ? "#ui/gameuiskin#favorite" : "#ui/gameuiskin#icon_primary_fail.svg"
  }

  function handlePveReward()
  {
    let isVisible = !!pveRewardInfo && pveRewardInfo.isVisible

    showSceneBtn("pve_trophy_block", isVisible)
    if (! isVisible)
      return

    let trophyItemReached =  ::ItemsManager.findItemById(pveRewardInfo.reachedTrophyName)
    let trophyItemReceived = ::ItemsManager.findItemById(pveRewardInfo.receivedTrophyName)

    fillPveRewardProgressBar()
    fillPveRewardTrophyChest(trophyItemReached)
    fillPveRewardTrophyContent(trophyItemReceived, pveRewardInfo.isRewardReceivedEarlier)
  }

  function handleGiftItems()
  {
    if (!giftItems || isAllGiftItemsKnown)
      return

    let obj = scene.findObject("inventory_gift_icon")
    let leftBlockHeight = scene.findObject("left_block").getSize()[1]
    let itemHeight = ::g_dagui_utils.toPixels(guiScene, "1@itemHeight")
    obj.smallItems = (itemHeight * giftItems.len() > leftBlockHeight / 2) ? "yes" : "no"

    local giftsMarkup = ""
    let showLen = min(giftItems.len(), VISIBLE_GIFT_NUMBER)
    isAllGiftItemsKnown = true
    for (local i=0; i < showLen; i++)
    {
      let markup = ::trophyReward.getImageByConfig(giftItems[i], false)
      isAllGiftItemsKnown = isAllGiftItemsKnown && markup != ""
      giftsMarkup += markup
    }
    guiScene.replaceContentFromText(obj, giftsMarkup, giftsMarkup.len(), this)
  }

  function onEventItemsShopUpdate(p)
  {
    if (state >= debrState.showMyStats)
      handleGiftItems()
    if (state >= debrState.done)
      updateInventoryButton()
  }

  function onViewRewards()
  {
    ::gui_start_open_trophy_rewards_list({rewardsArray = giftItems})
  }

  function groupGiftsById(items)
  {
    if(!items)
      return null

    let res = [items[0]]
    for(local i=1; i < items.len(); i++)
    {
      local isRepeated = false
      foreach(r in res)
        if(items[i].item == r.item)
        {
          r.count += items[i].count
          isRepeated = true
        }

      if(!isRepeated)
        res.append(items[i])
     }
    return res
  }

  function openGiftTrophy()
  {
    if (!giftItems?[0]?.needOpen)
      return

    let trophyItemId = giftItems[0].item
    let filteredLogs = ::getUserLogsList({
      show = [::EULT_OPEN_TROPHY]
      currentRoomOnly = true
      disableVisible = true
      checkFunc = function(userlog) { return trophyItemId == userlog.body.id }
    })

    if (filteredLogs.len() == 0)
      return

    ::gui_start_open_trophy({ [trophyItemId] = filteredLogs })
  }

  function onEventTrophyContentVisible(params)
  {
    if (giftItems?[0]?.item && giftItems[0].item == params?.trophyItem?.id)
      fillTrophyContentDiv(params.trophyItem, "inventory_gift_icon")
  }

  function fillPveRewardProgressBar()
  {
    let pveTrophyPlaceObj = showSceneBtn("pve_trophy_progress", true)
    if (!pveTrophyPlaceObj)
      return

    let receivedTrophyName = pveRewardInfo.receivedTrophyName
    let rewardTrophyStages = pveRewardInfo.stagesTime
    let showTrophiesOnBar  = ! pveRewardInfo.isRewardReceivedEarlier
    let maxValue = pveRewardInfo.victoryStageTime
    let stage = rewardTrophyStages.len()? [] : null
    foreach (stageIndex, val in rewardTrophyStages)
    {
      let isVictoryStage = val == maxValue

      let text = isVictoryStage ? ::loc("debriefing/victory")
       : time.secondsToString(val, true, true)

      let trophyName = ::get_pve_trophy_name(val, isVictoryStage)
      let isReceivedInLastBattle = trophyName && trophyName == receivedTrophyName
      let trophy = showTrophiesOnBar && trophyName ?
        ::ItemsManager.findItemById(trophyName, itemType.TROPHY) : null

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
      stage = stage
    }

    let data = ::handyman.renderCached("%gui/debriefing/pveReward", view)
    guiScene.replaceContentFromText(pveTrophyPlaceObj, data, data.len(), this)
  }

  function fillPveRewardTrophyChest(trophyItem)
  {
    let isVisible = !!trophyItem
    let trophyPlaceObj = showSceneBtn("pve_trophy_chest", isVisible)
    if (!isVisible || !trophyPlaceObj)
      return

    let imageData = trophyItem.getOpenedBigIcon()
    guiScene.replaceContentFromText(trophyPlaceObj, imageData, imageData.len(), this)
  }

  function fillPveRewardTrophyContent(trophyItem, isRewardReceivedEarlier)
  {
    showSceneBtn("pve_award_already_received", isRewardReceivedEarlier)
    fillTrophyContentDiv(trophyItem, "pve_trophy_content")
  }

  function fillTrophyContentDiv(trophyItem, containerObjId)
  {
    let trophyContentPlaceObj = showSceneBtn(containerObjId, !!trophyItem)
    if (!trophyItem || !trophyContentPlaceObj)
      return

    local layersData = ""
    let filteredLogs = ::getUserLogsList({
      show = [::EULT_OPEN_TROPHY]
      currentRoomOnly = true
      checkFunc = function(userlog) { return trophyItem.id == userlog.body.id }
    })

    foreach(log in filteredLogs)
    {
      let layer = ::trophyReward.getImageByConfig(log, false)
      if (layer != "")
      {
        layersData += layer
        break
      }
    }

    let layerId = "item_place_container"
    local layerCfg = ::LayersIcon.findLayerCfg(trophyItem.iconStyle + "_" + layerId)
    if (!layerCfg)
      layerCfg = ::LayersIcon.findLayerCfg(layerId)

    let data = ::LayersIcon.genDataFromLayer(layerCfg, layersData)
    guiScene.replaceContentFromText(trophyContentPlaceObj, data, data.len(), this)
  }

  function updatePvEReward(dt)
  {
    if (!pveRewardInfo)
      return
    let pveTrophyPlaceObj = scene.findObject("pve_trophy_progress")
    if (!::check_obj(pveTrophyPlaceObj))
      return

    let newSliderObj = pveTrophyPlaceObj.findObject("new_progress_box")
    if (!::check_obj(newSliderObj))
      return

    let targetValue = pveRewardInfo.sessionTime
    local newValue = 0
    if (skipAnim)
      newValue = targetValue
    else
      newValue = ::blendProp(newSliderObj.getValue(), targetValue, statsTime, dt).tointeger()

    newSliderObj.setValue(newValue)
  }

  function switchTab(tabName)
  {
    if (state != debrState.done)
      return
    let tabsObj = scene.findObject("tabs_list")
    if (!::check_obj(tabsObj))
      return
    for (local i = 0; i < tabsObj.childrenCount(); i++)
      if (tabsObj.getChild(i).id == tabName)
        return tabsObj.setValue(i)
  }

  function showTab(tabName)
  {
    foreach(name in tabsList)
    {
      let obj = scene.findObject(name + "_tab")
      if (!obj)
        continue
      let isShow = name == tabName
      obj.show(isShow)
      updateScrollableObjects(obj, name, isShow)
    }
    curTab = tabName
    updateListsButtons()

    if (state==debrState.done)
      isModeStat = tabName=="players_stats"
  }

  function animShowTab(tabName)
  {
    let obj = scene.findObject(tabName + "_tab")
    if (!obj) return

    obj.show(true)
    obj["color-factor"] = "0"
    obj["_transp-timer"] = "0"
    obj["animation"] = "show"
    curTab = tabName

    guiScene.playSound("deb_players_off")
  }

  function onUpdate(obj, dt)
  {
    needPlayCount = false
    if (isSceneActiveNoModals() && debriefingResult)
    {
      if (state != debrState.done && !updateState(dt))
        switchState()
      updateTotal(dt)
    }
    playCountSound(needPlayCount)
  }

  function playCountSound(play)
  {
    if (isPlatformSony)
      return

    play = play && !isInProgress
    if (play != isCountSoundPlay)
    {
      if (play)
        ::start_gui_sound("deb_count")
      else
        ::stop_gui_sound("deb_count")
      isCountSoundPlay = play
    }
  }

  function updateState(dt)
  {
    switch(state)
    {
      case debrState.showPlayers:
        return updatePlayersTable(dt)

      case debrState.showAwards:
        return updateAwards(dt)

      case debrState.showMyStats:
        return updateMyStats(dt)

      case debrState.showBonuses:
        return updateBonusStats(dt)
    }
    return false
  }

  function switchState()
  {
    if (state >= debrState.done)
      return

    state++
    statsTimer = 0
    reinitTotal()

    if (state == debrState.showPlayers)
    {
      loadAwardsList()
      loadBattleTasksList()

      if (!needPlayersTbl)
        return switchState()

      showTab("players_stats")
      skipAnim = skipAnim && debriefingSkipAllAtOnce
      if (!skipAnim)
        guiScene.playSound("deb_players_on")
      initPlayersTable()
      loadBattleLog()
      loadChatHistory()
      loadWwCasualtiesHistory()
    }
    else if (state == debrState.showAwards)
    {
      if (!is_show_my_stats() || !is_show_awards_list())
        return switchState()

      skipAnim = skipAnim && debriefingSkipAllAtOnce
      if (awardDelay * awardsList.len() > awardsAppearTime)
        awardDelay = awardsAppearTime / awardsList.len()
    }
    else if (state == debrState.showMyStats)
    {
      if (!is_show_my_stats())
        return switchState()

      showTab("my_stats")
      skipAnim = skipAnim && debriefingSkipAllAtOnce
      ::showBtnTable(scene, {
        left_block              = is_show_left_block()
        inventory_gift_block    = is_show_inventory_gift()
        my_stats_awards_block   = is_show_awards_list()
        right_block             = is_show_right_block()
        battle_tasks_block      = is_show_battle_tasks_list()
        researches_scroll_block = is_show_research_list()
      })
      showMyPlaceInTable()
      updateMyStatsTopBarArrangement()
      handleGiftItems()
    }
    else if (state == debrState.showBonuses)
    {
      statsTimer = statsBonusDelay

      if (!is_show_my_stats())
        return switchState()
      if (!totalRow)
        return switchState()

      let objPlace = scene.findObject("bonus_ico_place")
      if (!::checkObj(objPlace))
        return switchState()

      //Gather rewards info:
      let textArray = []

      if (debriefingResult.mulsList.len())
        textArray.append(::loc("bonus/xpFirstWinInDayMul/tooltip"))

      let bonusNames = {
        premAcc = "charServer/chapter/premium"
        premMod = "modification/premExpMul"
        booster = "itemTypes/booster"
      }
      let tblTotal = ::getTblValue("tblTotal", debriefingResult.exp, {})
      let bonusesTotal = []
      foreach (bonusType in [ "premAcc", "premMod", "booster" ])
      {
        let bonusExp = ::getTblValue(bonusType + "Exp", tblTotal, 0)
        let bonusWp  = ::getTblValue(bonusType + "Wp",  tblTotal, 0)
        if (!bonusExp && !bonusWp)
          continue
        bonusesTotal.append(::loc(::getTblValue(bonusType, bonusNames, "")) + ::loc("ui/colon") +
          ::Cost(bonusWp, 0, bonusExp).tostring())
      }
      if (!::u.isEmpty(bonusesTotal))
        textArray.append(::g_string.implode(bonusesTotal, "\n"))

      let boostersText = getBoostersText()
      if (!::u.isEmpty(boostersText))
        textArray.append(boostersText)

      if (::u.isEmpty(textArray)) //no bonus
        return switchState()

      if (!isDebriefingResultFull() &&
          !((gameType & ::GT_RACE) &&
            debriefingResult.exp.result == ::STATS_RESULT_IN_PROGRESS))
        textArray.append(::loc("debriefing/most_award_after_battle"))

      textArray.insert(0, ::loc("charServer/chapter/bonuses"))

      objPlace.show(true)
      updateMyStatsTopBarArrangement()

      let objTarget = objPlace.findObject("bonus_ico")
      if (::checkObj(objTarget))
      {
        objTarget["background-image"] = havePremium.value ?
          "#ui/gameuiskin#medal_premium" : "#ui/gameuiskin#medal_bonus"
        objTarget.tooltip = ::g_string.implode(textArray, "\n\n")
      }

      if (!skipAnim)
      {
        let objStart = scene.findObject("start_bonus_place")
        ::create_ObjMoveToOBj(scene, objStart, objTarget, { time = statsBonusTime })
        guiScene.playSound("deb_medal")
      }
    }
    else if (state == debrState.done)
    {
      ::showBtnTable(scene, {
        btn_skip = false
        skip_button   = false
        start_bonus_place = false
      })

      updateStartButton()
      fillLeaderboardChanges()
      updateInfoText()
      updateBuyPremiumAwardButton()
      showTabsList()
      updateListsButtons()
      fillResearchingMods()
      fillResearchingUnits()
      updateShortBattleTask()
      updateInventoryButton()

      checkPopupWindows()
      throwBattleEndEvent()
      guiScene.performDelayed(this, function() {ps4SendActivityFeed() })
      let tabsObj = getObj("tabs_list")
      ::move_mouse_on_child(tabsObj, tabsObj.getValue())
    }
    else
      skipAnim = skipAnim && debriefingSkipAllAtOnce
  }

  function ps4SendActivityFeed()
  {
    if (!isPlatformSony
      || !isMp
      || !debriefingResult
      || debriefingResult.exp.result != ::STATS_RESULT_SUCCESS)
      return

    let config = {
      locId = "win_session"
      subType = ps4_activity_feed.MISSION_SUCCESS
    }
    let customConfig = {
      blkParamName = "VICTORY"
    }

    if (isFirstWinInMajorUpdate)
    {
      config.locId = "win_session_after_update"
      config.subType = ps4_activity_feed.MISSION_SUCCESS_AFTER_UPDATE
      customConfig.blkParamName = "MAJOR_UPDATE"
      let ver = split(::get_game_version_str(), ".")
      customConfig.version <- ver[0]+"."+ver[1]
      customConfig.imgSuffix <- "_" + ver[0] + "_" + ver[1]
      customConfig.shouldForceLogo <- true
    }

    activityFeedPostFunc(config, customConfig, bit_activity.PS4_ACTIVITY_FEED)
  }

  function updateMyStats(dt)
  {
    if (curStatsIdx < 0)
      return false //nextState

    statsTimer -= dt

    updatePvEReward(dt)

    local haveChanges = false
    let upTo = min(curStatsIdx, debriefingRows.len()-1)
    for (local i = 0; i <= upTo; i++)
      if (debriefingRows[i].show)
        haveChanges = !updateStat(debriefingRows[i], playerStatsObj, skipAnim? 10*dt : dt, i==upTo) || haveChanges

    if (haveChanges || curStatsIdx < debriefingRows.len())
    {
      if ((statsTimer < 0 || skipAnim) && curStatsIdx < debriefingRows.len())
      {
        do
          curStatsIdx++
        while (curStatsIdx < debriefingRows.len() && !debriefingRows[curStatsIdx].show)
        statsTimer += statsNextTime
      }
      return true
    }
    return false
  }

  function updateBonusStats(dt)
  {
    statsTimer -= dt
    if (statsTimer < 0 || skipAnim)
    {
      local haveChanges = false
      foreach(row in debriefingRows)
        if (row.show)
          haveChanges = !updateStat(row, playerStatsObj, skipAnim? 10*dt : dt, false) || haveChanges
      return haveChanges
    }
    return true
  }

  function updateStat(row, tblObj, dt, needScroll)
  {
    local finished = true
    local justCreated = false
    let rowId = "row_" + row.id
    local rowObj = tblObj.findObject(rowId)

    if (!("curValues" in row) || !::checkObj(rowObj))
      row.curValues <- { value = 0, reward = 0 }
    if (!::checkObj(rowObj))
    {
      guiScene.setUpdatesEnabled(false, false)
      rowObj = guiScene.createElementByObject(tblObj, "%gui/debriefing/statRow.blk", "tr", this)
      rowObj.id = rowId
      rowObj.findObject("tooltip_").id = "tooltip_" + row.id
      rowObj.findObject("name").setValue(row.getName())

      if (!debriefingResult.needRewardColumn)
        guiScene.destroyElement(rowObj.findObject(row.canShowRewardAsValue? "td_value" : "td_reward"))
      justCreated = true

      if ("tooltip" in row)
        rowObj.title = ::loc(row.tooltip)

      local rowProps = ::getTblValue("rowProps", row, null)
      if(::u.isFunction(rowProps))
        rowProps = rowProps()

      if (rowProps != null)
        foreach(name, value in rowProps)
          rowObj[name] = value
      guiScene.setUpdatesEnabled(true, true)
    }
    if (needScroll)
      rowObj.scrollToView()

    foreach(p in ["value", "reward"])
    {
      let obj = rowObj.findObject(p)
      if (!checkObj(obj))
        continue

      local targetValue = 0
      if (p != "value" || ::isInArray(row.rowType, ["wp", "exp", "gold"]))
      {
        let tblKey = getCountedResultId(row, state, p == "value"? row.rowType : row.rewardType)
        targetValue = ::getTblValue(tblKey, debriefingResult.counted_result_by_debrState, 0)
      }

      if (targetValue == 0)
        targetValue = getStatValue(row, p)

      if (targetValue == null || (!justCreated && targetValue == row.curValues[p]))
        continue

      local nextValue = 0
      if (!skipAnim)
      {
        nextValue = ::blendProp(row.curValues[p], targetValue, row.isOverall? totalStatsTime : statsTime, dt)
        if (nextValue != targetValue)
          finished = false
        if (p != "value" || !::isInArray(row.rowType, ["mul", "tim", "pct", "ptm", "tnt"]))
          nextValue = nextValue.tointeger()
      }
      else
        nextValue = targetValue

      row.curValues[p] = nextValue
      let showEmpty = ((p == "value") != row.isOverall) && row.isVisibleWhenEmpty()
      local paramType = p == "value" ? row.rowType : row.rewardType

      if (row.isFreeRP && paramType == "exp")
        paramType = "frp" //show exp as FreeRP currency

      local text = getTextByType(nextValue, paramType, showEmpty)
      obj.setValue(text)
    }
    needPlayCount = needPlayCount || !finished
    return finished
  }

  function getStatValue(row, name, tgtName=null)
  {
    if (!tgtName)
      tgtName = "base"
    return !::u.isTable(row[name]) ? row[name] : ::getTblValue(tgtName, row[name], null)
  }

  function getTextByType(value, paramType, showEmpty = false)
  {
    if (!showEmpty && (value == 0 || (value == 1 && paramType == "mul")))
      return ""
    switch(paramType)
    {
      case "wp":  return ::Cost(value).toStringWithParams({isWpAlwaysShown = true})
      case "gold": return ::Cost(0, value).toStringWithParams({isGoldAlwaysShown = true})
      case "exp": return ::Cost().setRp(value).tostring()
      case "frp": return ::Cost().setFrp(value).tostring()
      case "num": return value.tostring()
      case "sec": return value + ::loc("debriefing/timeSec")
      case "mul": return "x" + value
      case "pct": return (100.0*value + 0.5).tointeger() + "%"
      case "tim": return time.secondsToString(value, false)
      case "ptm": return time.getRaceTimeFromSeconds(value)
      case "tnt": return stdMath.roundToDigits(value * ::KG_TO_TONS, 3).tostring()
    }
    return ""
  }

  function updateTotal(dt)
  {
    if (!isInited && (!totalCurValues || ::u.isEqual(totalCurValues, totalTarValues)))
      return

    if (isInited)
    {
      let country = getDebriefingCountry()
      if (country in playerRankByCountries && playerRankByCountries[country] >= ::max_country_rank)
      {
        totalTarValues.exp = getStatValue(totalRow, "exp", "prem")
        dt = 1000 //force fast blend
      }
    }

    let cost = ::Cost()
    foreach(p in [ "exp", "wp", "expTeaser", "wpTeaser" ])
      if (totalCurValues[p] != totalTarValues[p])
      {
        totalCurValues[p] = skipAnim ? totalTarValues[p] :
          ::blendProp(totalCurValues[p], totalTarValues[p], totalStatsTime, dt).tointeger()

        let obj = totalObj.findObject(p)
        if (::checkObj(obj))
        {
          cost.wp = p.indexof("wp") != null ? totalCurValues[p] : 0
          cost.rp = p.indexof("exp") != null ? totalCurValues[p] : 0
          obj.setValue(cost.toStringWithParams({isColored = p.indexof("Teaser") == null}))
        }
        needPlayCount = true
      }
  }

  function getModExp(airData)
  {
    if (::getTblValue("expModuleCapped", airData, false))
      return airData.expInvestModule
    return airData.expModsTotal //expModsTotal recounted by bonus mul.
  }

  function fillResearchingMods()
  {
    if (!isDebriefingResultFull())
      return

    let usedUnitsList = []
    foreach(unitId, unitData in debriefingResult.exp.aircrafts)
    {
      let unit = ::getAircraftByName(unitId)
      if (unit && isShowUnitInModsResearch(unitId))
        usedUnitsList.append({ unit = unit, unitData = unitData })
    }

    usedUnitsList.sort(function(a,b)
    {
      let haveInvestA = a.unitData.investModuleName == ""
      let haveInvestB = b.unitData.investModuleName == ""
      if (haveInvestA!=haveInvestB)
        return haveInvestA? 1 : -1
      let expA = a.unitData.expTotal
      let expB = b.unitData.expTotal
      if (expA!=expB)
        return (expA > expB)? -1 : 1
      return 0
    })

    let tabObj = scene.findObject("modifications_objects_place")
    guiScene.replaceContentFromText(tabObj, "", 0, this)
    foreach(data in usedUnitsList)
      fillResearchMod(tabObj, data.unit, data.unitData)
  }

  function fillResearchingUnits()
  {
    if (!isDebriefingResultFull())
      return

    let obj = scene.findObject("air_item_place")
    local data = ""
    let unitItems = []
    foreach (ut in unitTypes.types)
    {
      let unitItem = getResearchUnitMarkupData(ut.name)
      if (unitItem)
      {
        data += ::build_aircraft_item(unitItem.id, unitItem.unit, unitItem.params)
        unitItems.append(unitItem)
      }
    }

    guiScene.replaceContentFromText(obj, data, data.len(), this)
    foreach (unitItem in unitItems)
      ::fill_unit_item_timers(obj.findObject(unitItem.id), unitItem.unit, unitItem.params)

    if (!unitItems.len())
    {
      let expInvestUnitTotal = getExpInvestUnitTotal()
      if (expInvestUnitTotal > 0)
      {
        let msg = ::format(::loc("debriefing/all_units_researched"),
          ::Cost().setRp(expInvestUnitTotal).tostring())
        let noUnitObj = scene.findObject("no_air_text")
        if (::checkObj(noUnitObj))
          noUnitObj.setValue(::g_string.stripTags(msg))
      }
    }
  }

  function onEventUnitBought(p)
  {
    fillResearchingUnits()
  }

  function onEventUnitRented(p)
  {
    fillResearchingUnits()
  }

  function isShowUnitInModsResearch(unitId)
  {
    let unitData = debriefingResult.exp.aircrafts?[unitId]
    return unitData?.expTotal && unitData?.sessionTime &&
      ((unitData?.investModuleName ?? "") != "" ||
      ::SessionLobby.isUsedPlayersOwnUnit(playersInfo?[::my_user_id_int64], unitId))
  }

  function hasAnyFinishedResearch()
  {
    if (!debriefingResult)
      return false
    foreach (ut in unitTypes.types)
    {
      let unit = ::getTblValue("unit", getResearchUnitInfo(ut.name))
      if (unit && !::isUnitInResearch(unit))
        return true
    }
    foreach (unitId, unitData in debriefingResult.exp.aircrafts)
    {
      let modName = ::getTblValue("investModuleName", unitData, "")
      if (modName == "")
        continue
      let unit = ::getAircraftByName(unitId)
      let mod = unit && getModificationByName(unit, modName)
      if (unit && mod && isModResearched(unit, mod))
        return true
    }
    return false
  }

  function getExpInvestUnitTotal()
  {
    local res = 0
    foreach (unitId, unitData in debriefingResult.exp.aircrafts)
      res += unitData?.expInvestUnitTotal ?? 0
    return res
  }

  function getResearchUnitInfo(unitTypeName)
  {
    let unitId = debriefingResult?.exp["investUnitName" + unitTypeName] ?? ""
    let unit = ::getAircraftByName(unitId)
    if (!unit)
      return null
    local expInvest = debriefingResult?.exp["expInvestUnit" + unitTypeName] ?? 0
    expInvest = applyItemExpMultiplicator(expInvest)
    if (expInvest <= 0)
      return null
    return { unit = unit, expInvest = expInvest }
  }

  function getResearchUnitMarkupData(unitTypeName)
  {
    let info = getResearchUnitInfo(unitTypeName)
    if (!info)
      return null

    return {
      id = info.unit.name
      unit = info.unit
      params = {
        diffExp = info.expInvest
        tooltipParams = {
          researchExpInvest = info.expInvest
          boosterEffects = getBoostersTotalEffects()
        }
      }
    }
  }

  function applyItemExpMultiplicator(itemExp)
  {
    local multBonus = 0
    if(debriefingResult.mulsList.len() > 0)
      foreach(idx, table in debriefingResult.mulsList)
        multBonus += ::getTblValue("exp", table, 0)

    itemExp = multBonus == 0? itemExp : itemExp * multBonus
    return itemExp
  }

  function getResearchModFromAirData(air, airData)
  {
    let curResearch = airData.investModuleName
    if (curResearch != "")
      return getModificationByName(air, curResearch)
    return null
  }

  function fillResearchMod(holderObj, unit, airData)
  {
    let unitId = unit.name
    let mod = getResearchModFromAirData(unit, airData)
    let diffExp = mod ? getModExp(airData) : 0
    let isCompleted = mod ? ::getTblValue("expModuleCapped", airData, false) : false

    let view = {
      id = unitId
      unitImg = ::image_for_air(unit)
      unitName = ::stringReplace(::getUnitName(unit), ::nbsp, " ")
      hasModItem = mod != null
      isCompleted = isCompleted
      unitTooltipId = ::g_tooltip.getIdUnit(unit.name, { boosterEffects = getBoostersTotalEffects() })
      modTooltipId =  mod
        ? MODIFICATION.getTooltipId(unit.name, mod.name, { diffExp = diffExp, curEdiff = getCurrentEdiff() })
        : ""
      isTooltipByHold = ::show_console_buttons
    }

    let markup = ::handyman.renderCached("%gui/debriefing/modificationProgress", view)
    guiScene.appendWithBlk(holderObj, markup, this)
    let obj = holderObj.findObject(unitId)

    if (mod)
    {
      let modObj = obj.findObject("mod_" + unitId)
      updateModItem(unit, mod, modObj, false, this, getParamsForModItem(diffExp))
    }
    else
    {
      local msg = "debriefing/but_all_mods_researched"
      if (findAnyNotResearchedMod(unit))
        msg = "debriefing/but_not_any_research_active"
      msg = format(::loc(msg), ::Cost().setRp(getModExp(airData) || airData.expTotal).tostring())
      obj.findObject("no_mod_text").setValue(msg)
    }
  }

  function getCurrentEdiff()
  {
    return ::get_mission_mode()
  }

  function onEventModBought(p)
  {
    let unitId = ::getTblValue("unitName", p, "")
    let modId = ::getTblValue("modName", p, "")
    updateResearchMod(unitId, modId)
  }

  function onEventUnitModsRecount(p)
  {
    updateResearchMod(p?.unit.name, "")
  }

  function updateResearchMod(unitId, modId)
  {
    let airData = debriefingResult?.exp.aircrafts[unitId]
    if (!airData)
      return
    let unit = ::getAircraftByName(unitId)
    let mod = getResearchModFromAirData(unit, airData)
    if (!mod || (modId != "" && modId != mod.name))
      return

    let obj = scene.findObject("research_list")
    let modObj = ::checkObj(obj) ? obj.findObject("mod_" + unitId) : null
    if (!::checkObj(modObj))
      return
    let diffExp = getModExp(airData)
    updateModItem(unit, mod, modObj, false, this, getParamsForModItem(diffExp))
  }

  function getParamsForModItem(diffExp)
  {
    return { diffExp = diffExp, limitedName = false, curEdiff = getCurrentEdiff() }
  }

  function fillLeaderboardChanges()
  {
    let lbWindgetsNestObj = scene.findObject("leaderbord_stats")
    if (!::checkObj(lbWindgetsNestObj))
      return

    let logs = ::getUserLogsList({
        show = [::EULT_SESSION_RESULT]
        currentRoomOnly = true
      })

    if (logs.len() == 0)
      return

    if (!("tournamentResult" in logs[0]))
      return

    let gapSides = guiScene.calcString("@tablePad", null)
    let gapMid   = guiScene.calcString("@debrPad", null)
    let gapsPerRow = gapSides * 2 + gapMid * (DEBR_LEADERBOARD_LIST_COLUMNS - 1)

    let posFirst  = ::format("%d, %d", gapSides, gapMid)
    let posCommon = ::format("%d, %d", gapMid,   gapMid)
    let itemParams = {
      width  = ::format("(pw - %d) / %d", gapsPerRow, DEBR_LEADERBOARD_LIST_COLUMNS)
      pos    = posCommon
      margin = "0"
    }

    let now = ::getTblValue("newStat", logs[0].tournamentResult)
    let was = ::getTblValue("oldStat", logs[0].tournamentResult)

    let lbDiff = ::leaderboarsdHelpers.getLbDiff(now, was)
    let items = []
    foreach (lbFieldsConfig in ::events.eventsTableConfig)
    {
      if (!(lbFieldsConfig.field in now)
        || !::events.checkLbRowVisibility(lbFieldsConfig, { eventId = logs[0]?.eventId }))
        continue

      let isFirstInRow = items.len() % DEBR_LEADERBOARD_LIST_COLUMNS == 0
      itemParams.pos = isFirstInRow ? posFirst : posCommon

      items.append(::getLeaderboardItemView(lbFieldsConfig,
        now[lbFieldsConfig.field],
        ::getTblValue(lbFieldsConfig.field, lbDiff, null),
        itemParams))
    }
    lbWindgetsNestObj.show(true)

    let blk = ::getLeaderboardItemWidgets({ items = items })
    guiScene.replaceContentFromText(lbWindgetsNestObj, blk, blk.len(), this)
    lbWindgetsNestObj.scrollToView()
  }

  function onSkip()
  {
    skipAnim = true
  }

  function checkShowTooltip(obj)
  {
    let showTooltip = skipAnim || state==debrState.done
    obj["class"] = showTooltip? "" : "empty"
    return showTooltip
  }

  function onTrTooltipOpen(obj)
  {
    if (!checkShowTooltip(obj) || !debriefingResult)
      return

    let id = getTooltipObjId(obj)
    if (!id) return
    if (!("exp" in debriefingResult) || !("aircrafts" in debriefingResult.exp))
    {
      obj["class"] = "empty"
      return
    }

    let tRow = getDebriefingRowById(id)
    if (!tRow || tRow.hideTooltip)
    {
      obj["class"] = "empty"
      return
    }

    let rowsCfg = []
    if (!tRow.joinRows)
    {
      if (tRow.isCountedInUnits)
      {
        foreach (unitId, unitData in debriefingResult.exp.aircrafts)
          rowsCfg.append({
            row     = tRow
            name    = ::getUnitName(unitId)
            expData = unitData
            unitId  = unitId
          })
      }
      else
      {
        rowsCfg.append({
          row     = tRow
          name    = tRow.getName()
          expData = debriefingResult.exp
        })
      }
    }

    if (tRow.joinRows || tRow.tooltipExtraRows)
    {
      let extraRows = []
      if (tRow.joinRows)
        extraRows.extend(tRow.joinRows)
      if (tRow.tooltipExtraRows)
        extraRows.extend(tRow.tooltipExtraRows())

      foreach (extId in extraRows)
      {
        let extraRow = getDebriefingRowById(extId)
        if (extraRow.show || extraRow.showInTooltips)
          rowsCfg.append({
            row     = extraRow
            name    = extraRow.getName()
            expData = debriefingResult.exp
          })
      }
    }

    if (!rowsCfg.len())
    {
      obj["class"] = "empty"
      return
    }

    let tooltipView = {
      rows = getTrTooltipRowsView(rowsCfg, tRow)
      tooltipComment = tRow.tooltipComment ? tRow.tooltipComment() : null
    }

    let markup = ::handyman.renderCached("%gui/debriefing/statRowTooltip", tooltipView)
    guiScene.replaceContentFromText(obj, markup, markup.len(), this)
  }

  function getTrTooltipRowsView(rowsCfg, tRow)
  {
    let view = []

    let boosterEffects = getBoostersTotalEffects()

    foreach(cfg in rowsCfg)
    {
      let rowView = {
        name = cfg.name
      }

      let rowTbl = cfg.expData?[getTableNameById(cfg.row)]

      foreach(currency in [ "exp", "wp" ])
      {
        if (cfg.row.rowType != currency && cfg.row.rewardType != currency)
          continue
        let currencySourcesView = []
        foreach (source in [ "noBonus", "premAcc", "premMod", "booster" ])
        {
          let val = rowTbl?[$"{source}{::g_string.toUpper(currency, 1)}"] ?? 0
          if (val <= 0)
            continue
          local extra = ""
          if (source == "booster")
          {
            let effect = ::getTblValue((currency == "exp" ? "xp" : currency) + "Rate", boosterEffects, 0)
            if (effect)
              extra = ::colorize("fadedTextColor", ::loc("ui/parentheses", { text = effect.tointeger().tostring() + "%" }))
          }
          currencySourcesView.append((sourcesConfig?[source] ?? {}).__merge({ text = $"{getTextByType(val, currency)}{extra}" }))
        }
        if (currencySourcesView.len() > 1)
        {
          if (!("bonuses" in rowView))
            rowView.bonuses <- []
          rowView.bonuses.append({sources = currencySourcesView})
        }
      }

      let extraBonuses = tRow.tooltipRowBonuses(cfg?.unitId, cfg.expData)
      if (extraBonuses)
      {
        if (!("bonuses" in rowView))
          rowView.bonuses <- []
        rowView.bonuses.append(extraBonuses)
      }

      foreach(p in ["time", "value", "reward", "info"])
      {
        let { paramType, pId, showEmpty = false } = statTooltipColumnParamByType[p](cfg.row)
        rowView[p] <- getTextByType(cfg.expData?[pId] ?? 0, paramType, showEmpty)
      }

      view.append(rowView)
    }

    let showColumns = { time = false, value = false, reward = false, info = false }
    foreach (rowView in view)
      foreach (col, isShow in showColumns)
        if (!::u.isEmpty(rowView[col]))
          showColumns[col] = true
    foreach (rowView in view)
      foreach (col, isShow in showColumns)
        if (isShow && ::u.isEmpty(rowView[col]))
          rowView[col] = ::nbsp

    let headerRow = { name = ::colorize("fadedTextColor", ::loc("options/unit")) }
    foreach (col, isShow in showColumns)
    {
      local title = ""
      if (isShow)
        title = col == "value" ? tRow.getIcon()
          : col == "time" ? ::loc("icon/timer")
          : ""
      headerRow[col] <- ::colorize("fadedTextColor", title)
    }
    view.insert(0, headerRow)

    return view
  }

  function getDebriefingRowById(id)
  {
    return ::u.search(debriefingRows, @(row) row.id == id)
  }

  function getPremTeaserInfo()
  {
    let totalWp = debriefingResult.exp?.wpTotal  ?? 0
    let totalRp = debriefingResult.exp?.expTotal ?? 0
    let virtPremAccWp = debriefingResult.exp?.tblTotal.virtPremAccWp  ?? 0
    let virtPremAccRp = debriefingResult.exp?.tblTotal.virtPremAccExp ?? 0

    let totalWithPremWp = (totalWp <= 0 || virtPremAccWp <= 0) ? 0 : (totalWp + virtPremAccWp)
    let totalWithPremRp = (totalRp <= 0 || virtPremAccRp <= 0) ? 0 : (totalRp + virtPremAccRp)

    return {
      exp  = totalWithPremRp
      wp   = totalWithPremWp
      isPositive = totalWithPremRp > 0 || totalWithPremWp > 0
    }
  }

  function canSuggestBuyPremium()
  {
    return !havePremium.value && ::has_feature("SpendGold") && ::has_feature("EnablePremiumPurchase") && isDebriefingResultFull()
  }

  function updateBuyPremiumAwardButton()
  {
    let isShow = canSuggestBuyPremium() && gm == ::GM_DOMINATION && checkPremRewardAmount()

    let obj = scene.findObject("buy_premium")
    if (!::check_obj(obj))
      return

    obj.show(isShow)
    if (!isShow)
      return

    let curAwardText = getCurAwardText()

    let btnObj = obj.findObject("btn_buy_premium_award")
    if (::check_obj(btnObj))
      btnObj.findObject("label").setValue(::loc("mainmenu/earn") + "\n" + curAwardText)

    updateMyStatsTopBarArrangement()
  }

  function getEntitlementWithAward()
  {
    let priceBlk = ::OnlineShopModel.getPriceBlk()
    let l = priceBlk.blockCount()
    for (local i = 0; i < l; i++)
      if (priceBlk.getBlock(i)?.allowBuyWithAward)
        return priceBlk.getBlock(i).getBlockName()
    return null
  }

  function checkPremRewardAmount()
  {
    if (!getEntitlementWithAward())
      return false
    if (::get_premium_reward_wp() >= minValuesToShowRewardPremium.value.wp)
      return true
    let exp = ::get_premium_reward_xp()
    return exp >= minValuesToShowRewardPremium.value.exp
  }

  function onBuyPremiumAward()
  {
    if (havePremium.value)
      return
    let entName = getEntitlementWithAward()
    if (!entName)
    {
      ::dagor.assertf(false, "Error: not found entitlement with premium award")
      return
    }

    let ent = getEntitlementConfig(entName)
    let entNameText = getEntitlementName(ent)
    let price = ::Cost(0, ent?.goldCost ?? 0)
    let cb = ::Callback(onBuyPremiumAward, this)

    let msgText = format(::loc("msgbox/EarnNow"), entNameText, getCurAwardText(), price.getTextAccordingToBalance())
    msgBox("not_all_mapped", msgText,
    [
      ["ok", function() {
        if (!::check_balance_msgBox(price, cb))
          return false

        taskId = ::purchase_entitlement_and_get_award(entName)
        if (taskId >= 0)
        {
          ::set_char_cb(this, slotOpCb)
          showTaskProgressBox()
          afterSlotOp = function() { addPremium() }
        }
      }],
      ["cancel", @() null]
    ], "ok", {cancel_fn = @() null})
  }

  function addPremium()
  {
    if (!havePremium.value)
      return

    debriefingAddVirtualPremAcc()

    foreach(row in debriefingRows)
      if (!row.show)
        showSceneBtn("row_" + row.id, row.show)

    updateBuyPremiumAwardButton()
    reinitTotal()
    skipAnim = false
    state = debrState.showBonuses - 1
    switchState()
    ::update_gamercards()
  }

  function updateAwards(dt)
  {
    statsTimer -= dt

    if (statsTimer < 0 || skipAnim)
    {
      if (awardsList && curAwardIdx < awardsList.len())
      {
        if (currentAwardsListIdx >= currentAwardsList.len())
        {
          currentAwardsList = unlockAwardsList
          currentAwardsListConfig = awardsListsConfig.unlocks
          currentAwardsListIdx = 0
        }

        addAward()
        statsTimer += awardDelay
        curAwardIdx++
        currentAwardsListIdx++
      }
      else if (curAwardIdx == awardsList.len())
      {
        //finish awards update
        statsTimer += nextWndDelay
        curAwardIdx++
      }
      else
        return false
    }
    return true
  }

  function countAwardsOffset(obj, tgtObj, axis)
  {
    let size = obj.getSize()
    let maxSize = tgtObj.getSize()
    let awardSize = size[axis] * currentAwardsList.len()

    if (awardSize > maxSize[axis] && currentAwardsList.len() > 1)
      awardOffset = ((maxSize[axis] - awardSize) / (currentAwardsList.len()-1) - 1).tointeger()
    else
      tgtObj[axis ? "height" : "width"] = awardSize.tostring()
  }

  function addAward()
  {
    let config = currentAwardsList[currentAwardsListIdx]
    let objId = "award_" + curAwardIdx

    let listObj = scene.findObject(currentAwardsListConfig.listObjId)
    let obj = guiScene.createElementByObject(listObj, "%gui/debriefing/awardIcon.blk", "awardPlace", this)
    obj.id = objId

    let tooltipObj = obj.findObject("tooltip_")
    tooltipObj.id = "tooltip_" + curAwardIdx
    tooltipObj.setUserData(config)

    if ("needFrame" in config && config.needFrame)
      obj.findObject("move_part")["class"] = "unlockFrame"

    let align = currentAwardsListConfig.align
    let axis = (align == ALIGN.TOP || align == ALIGN.BOTTOM) ? 1 : 0
    if (currentAwardsListIdx == 0) //firstElem
      countAwardsOffset(obj, listObj, axis)
    else if (align == ALIGN.LEFT && awardOffset != 0)
      obj.pos = awardOffset + ", 0"
    else if (align == ALIGN.TOP && awardOffset != 0)
      obj.pos = "0, " + awardOffset

    if (align == ALIGN.RIGHT)
      if (currentAwardsListIdx == 0)
        obj.pos = "pw - w, 0"
      else
        obj.pos = "-2w -" + awardOffset + " ,0"

    let icoObj = obj.findObject("award_img")
    set_unlock_icon_by_config(icoObj, config)
    let awMultObj = obj.findObject("award_multiplier")
    if (::checkObj(awMultObj))
    {
      let show = config.amount > 1
      awMultObj.show(show)
      if (show)
      {
        let amObj = awMultObj.findObject("amount_text")
        if (::checkObj(amObj))
          amObj.setValue("x" + config.amount)
      }
    }

    if (!skipAnim)
    {
      let objStart = scene.findObject(currentAwardsListConfig.startplaceObId)
      let objTarget = obj.findObject("move_part")
      ::create_ObjMoveToOBj(scene, objStart, objTarget, { time = awardFlyTime })

      obj["_size-timer"] = "0"
      obj.width = "0"
      guiScene.playSound("deb_achivement")
    }
  }

  function onViewAwards(obj)
  {
    switchTab("awards_list")
  }

  function onAwardTooltipOpen(obj)
  {
    if (!checkShowTooltip(obj))
      return

    let config = obj.getUserData()
    ::build_unlock_tooltip_by_config(obj, config, this)
  }

  function buildPlayersTable()
  {
    playersTbl = []
    curPlayersTbl = [[], []]
    updateNumMaxPlayers(true)
    if (isTeamplay)
    {
      for(local t = 0; t < 2; t++)
      {
        let tbl = getMplayersListByTeam(t+1)
        sortTable(tbl)
        playersTbl.append(tbl)
      }
    }
    else
    {
      sortTable(debriefingResult.mplayers_list)
      playersTbl.append([])
      playersTbl.append([])
      foreach(i, player in debriefingResult.mplayers_list)
      {
        let tblIdx = i >= numMaxPlayers ? 1 : 0
        playersTbl[tblIdx].append(player)
      }
    }

    foreach(tbl in playersTbl)
      foreach(player in tbl)
      {
        player.state = ::PLAYER_IN_FLIGHT //dont need to show laast player state in debriefing.
        player.isDead = false
      }
  }

  function initPlayersTable()
  {
    initStats()

    if (needPlayersTbl)
      buildPlayersTable()

    updatePlayersTable(0.0)
  }

  function getMplayersListByTeam(teamNum)
  {
    return (debriefingResult?.mplayers_list ?? []).filter(@(player) player.team == teamNum)
  }

  function updatePlayersTable(dt)
  {
    if (!playersTbl || !debriefingResult)
      return false

    statsTimer -= dt
    minPlayersTime -= dt
    if (statsTimer <= 0 || skipAnim)
    {
      if (playersTblDone)
        return minPlayersTime > 0

      local hasLocalPlayer = false
      playersTblDone = true
      for(local t = 0; t < 2; t++)
      {
        let idx = curPlayersTbl[t].len()
        if (idx in playersTbl[t])
        {
          curPlayersTbl[t].append(playersTbl[t][idx])
          hasLocalPlayer = hasLocalPlayer || !!playersTbl[t][idx].isLocal
        }
        playersTblDone = playersTblDone && curPlayersTbl[t].len() == playersTbl[t].len()
      }
      updateStats({ playersTbl = curPlayersTbl, playersInfo = playersInfo }, debriefingResult.mpTblTeams,
        debriefingResult.friendlyTeam)
      statsTimer += playersRowTime
    }
    return true
  }

  function getMyPlace() {
    local place = 0
    if (playersTbl)
      foreach(t, tbl in playersTbl)
        foreach(i, player in tbl)
          if (("isLocal" in player) && player.isLocal)
          {
            place = i + 1
            if (!isTeamplay && t)
              place += playersTbl[0].len()
            break
          }

    return place
  }

  function showMyPlaceInTable()
  {
    if (!is_show_my_stats())
      return

    let place = getMyPlace()
    let hasPlace = place != 0

    let label = hasPlace && isTeamplay ? ::loc("debriefing/placeInMyTeam")
      : hasPlace && !isTeamplay ? (::loc("mainmenu/btnMyPlace") + ::loc("ui/colon"))
      : !isDebriefingResultFull() ? ::loc("debriefing/preliminaryResults")
      : ::loc(debriefingResult.isSucceed ? "debriefing/victory" : "debriefing/defeat")

    let objTarget = scene.findObject("my_place_move_box")
    objTarget.show(true)
    scene.findObject("my_place_label").setValue(label)
    scene.findObject("my_place_in_mptable").setValue(hasPlace ? place.tostring() : "")

    if (!skipAnim && hasPlace)
    {
      let objStart = scene.findObject("my_place_move_box_start")
      ::create_ObjMoveToOBj(scene, objStart, objTarget, { time = myPlaceTime })
    }
  }

  function updateMyStatsTopBarArrangement()
  {
    if (!is_show_my_stats())
      return

    let containerObj = scene.findObject("my_stats_top_bar")
    let myPlaceObj = scene.findObject("my_place_move_box")
    let topBarNestObj = scene.findObject("top_bar_nest")
    if (!::check_obj(containerObj) || !::check_obj(myPlaceObj) || !::check_obj(topBarNestObj))
      return
    let total = containerObj.childrenCount()
    if (total < 2)
      return
    guiScene.applyPendingChanges(false)

    local visible = 0
    for (local i = 0; i < total; i++)
    {
      let obj = containerObj.getChild(i)
      if (::check_obj(obj) && obj.isVisible())
        visible++
    }

    let isSingleRow = visible < 3
    let gapMin = 1.0
    let debrTopBarGAPMax = isSingleRow ? 3 : DEBR_MYSTATS_TOP_BAR_GAP_MAX
    let maxValue = isSingleRow ? 1 : 2
    let contentPadStr = isSingleRow ? "debrBarContentPad" : "debrPad"

    let gapMax = gapMin * debrTopBarGAPMax
    let gap = ::clamp(stdMath.lerp(total, maxValue, gapMin, gapMax, visible), gapMin, gapMax)
    let pos = $"{gap}@{contentPadStr}, 0.5ph-0.5h"

    for (local i = 0; i < containerObj.childrenCount(); i++)
    {
      let obj = containerObj.getChild(i)
      if (::check_obj(obj))
        obj["pos"] = pos
    }

    if (isSingleRow)                  //Single row
    {
      topBarNestObj.flow = "horisontal"
      local totalWidth = 0.5*(myPlaceObj.getSize()[0] + containerObj.getSize()[0])
      myPlaceObj.pos = $"0.5pw-{totalWidth}, 0.5ph-0.5h"
    }
    else {                            //Two rows
      topBarNestObj.flow = "vertical"
      myPlaceObj.pos = "0.5pw-0.5w, 0"
      containerObj.pos = "0.5pw-0.5w-0.5@debrPad, 0.5@debrPad"
    }
  }

  function loadBattleLog(filterIdx = null)
  {
    if (!needPlayersTbl)
      return
    let filters = ::HudBattleLog.getFilters()

    if (filterIdx == null)
    {
      filterIdx = ::loadLocalByAccount("wnd/battleLogFilterDebriefing", 0)

      let obj = scene.findObject("battle_log_filter")
      if (::checkObj(obj))
      {
        local data = ""
        foreach (f in filters)
          data += ::format("RadioButton { text:t='#%s'; style:t='color:@white'; RadioButtonImg{} }\n", f.title)
        guiScene.replaceContentFromText(obj, data, data.len(), this)
        obj.setValue(filterIdx)
      }
    }

    let obj = scene.findObject("battle_log_div")
    if (::checkObj(obj))
    {
      let logText = ::HudBattleLog.getText(filters[filterIdx].id, 0)
      obj.findObject("battle_log").setValue(logText)
    }
  }

  function loadChatHistory()
  {
    if (!needPlayersTbl)
      return
    let logText = ::getTblValue("chatLog", debriefingResult, "")
    if (logText == "")
      return
    let obj = scene.findObject("chat_history_div")
    if (::checkObj(obj))
      obj.findObject("chat_log").setValue(logText)
  }

  function loadAwardsList()
  {
    let listObj = scene.findObject("awards_list_tab_div")
    let itemWidth = ::floor((listObj.getSize()[0] -
      guiScene.calcString("@scrollBarSize", null)
      ) / DEBR_AWARDS_LIST_COLUMNS - 1)
    foreach (list in [ unlockAwardsList, streakAwardsList ])
      foreach (award in list)
      {
        let obj = guiScene.createElementByObject(listObj, "%gui/unlocks/unlockBlock.blk", "tdiv", this)
        obj.width = itemWidth.tostring()
        ::fill_unlock_block(obj, award)
      }
  }

  function loadBattleTasksList()
  {
    if (!is_show_battle_tasks_list(false) || !mGameMode)
      return

    let tasksArray = ::g_battle_tasks.getTasksArrayByIncreasingDifficulty()
    local filteredTasks = ::g_battle_tasks.filterTasksByGameModeId(tasksArray, mGameMode?.name)

    filteredTasks = filteredTasks.filter(@(task)
      !::g_battle_tasks.isTaskDone(task) &&
      ::g_battle_tasks.isTaskActive(task)
    )

    let currentBattleTasksConfigs = {}
    let configsArray = filteredTasks.map(@(task) ::g_battle_tasks.generateUnlockConfigByTask(task))
    foreach (config in configsArray)
      currentBattleTasksConfigs[config.id] <- config

    if (!::u.isEqual(currentBattleTasksConfigs, battleTasksConfigs))
    {
      shouldBattleTasksListUpdate = true
      battleTasksConfigs = currentBattleTasksConfigs
      updateBattleTasksList()
    }
  }

  function updateBattleTasksList()
  {
    if (curTab != "battle_tasks_list" || !shouldBattleTasksListUpdate || !is_show_battle_tasks_list(false))
      return

    shouldBattleTasksListUpdate = false
    let msgObj = scene.findObject("battle_tasks_list_msg")
    if (::check_obj(msgObj))
      msgObj.show(!is_show_battle_tasks_list())

    let listObj = scene.findObject("battle_tasks_list_scroll_block")
    if (!::check_obj(listObj))
      return

    listObj.show(is_show_battle_tasks_list())
    if (!is_show_battle_tasks_list())
      return

    let curSelected = listObj.getValue()
    let battleTasksArray = []
    foreach (config in battleTasksConfigs)
    {
      battleTasksArray.append(::g_battle_tasks.generateItemView(config, { showUnlockImage = false }))
    }
    let data = ::handyman.renderCached("%gui/unlocks/battleTasksItem", { items = battleTasksArray })
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    if (battleTasksArray.len() > 0)
      listObj.setValue(::clamp(curSelected, 0, listObj.childrenCount() - 1))
  }

  function updateBattleTasksStatusImg()
  {
    let tabObjStatus = scene.findObject("battle_tasks_list_icon")
    if (::check_obj(tabObjStatus))
      tabObjStatus.show(::g_battle_tasks.canGetAnyReward())
  }

  function onSelectTask(obj)
  {
    updateBattleTasksRequirementsList() //need to check even if there is unlock

    let val = obj.getValue()
    let taskObj = obj.getChild(val)
    let taskId = taskObj?.task_id
    let task = ::g_battle_tasks.getTaskById(taskId)
    if (!task)
      return

    let isBattleTask = ::g_battle_tasks.isBattleTask(taskId)

    let isDone = ::g_battle_tasks.isTaskDone(task)
    let canGetReward = isBattleTask && ::g_battle_tasks.canGetReward(task)

    let showRerollButton = isBattleTask && !isDone && !canGetReward && !::u.isEmpty(::g_battle_tasks.rerollCost)
    ::showBtn("btn_reroll", showRerollButton, taskObj)
    ::showBtn("btn_recieve_reward", canGetReward, taskObj)
    if (showRerollButton)
      placePriceTextToButton(taskObj, "btn_reroll", ::loc("mainmenu/battleTasks/reroll"), ::g_battle_tasks.rerollCost)
  }

  function updateBattleTasksRequirementsList()
  {
    local config = null
    if (curTab == "battle_tasks_list" && is_show_battle_tasks_list())
    {
      let taskId = getCurrentBattleTaskId()
      config = battleTasksConfigs?[taskId]
    }

    showSceneBtn("btn_requirements_list", ::show_console_buttons && (config?.names ?? []).len() != 0)
  }

  function onTaskReroll(obj)
  {
    let config = battleTasksConfigs?[obj?.task_id]
    if (!config)
      return

    let task = config?.originTask
    if (!task)
      return

    if (::check_balance_msgBox(::g_battle_tasks.rerollCost))
      msgBox("reroll_perform_action",
             ::loc("msgbox/battleTasks/reroll",
                  {cost = ::g_battle_tasks.rerollCost.tostring(),
                    taskName = ::g_battle_tasks.getLocalizedTaskNameById(task)
                  }),
      [
        ["yes", @() ::g_battle_tasks.isSpecialBattleTask(task)
          ? ::g_battle_tasks.rerollSpecialTask(task)
          : ::g_battle_tasks.rerollTask(task) ],
        ["no", @() null ]
      ], "yes", { cancel_fn = @() null})
  }

  function onGetRewardForTask(obj)
  {
    ::g_battle_tasks.requestRewardForTask(obj?.task_id)
  }

  function getCurrentBattleTaskId()
  {
    let listObj = scene.findObject("battle_tasks_list_scroll_block")
    if (::check_obj(listObj))
      return listObj.getChild(listObj.getValue())?.task_id

    return null
  }

  function onViewBattleTaskRequirements(obj)
  {
    local taskId = obj?.task_id
    if (!taskId)
      taskId = getCurrentBattleTaskId()

    let config = battleTasksConfigs?[taskId]
    if (!config)
      return

    let cfgNames = config?.names ?? []
    if (cfgNames.len() == 0)
      return

    let awards = cfgNames.map(@(id) ::build_log_unlock_data(
      ::build_conditions_config(
        ::g_unlocks.getUnlockById(id)
    )))

    ::showUnlocksGroupWnd([{
      unlocksList = awards
      titleText = ::loc("unlocks/requirements")
    }])
  }

  function updateBattleTasks()
  {
    loadBattleTasksList()
    updateBattleTasksStatusImg()
    updateShortBattleTask()
  }

  function onEventBattleTasksIncomeUpdate(p) { updateBattleTasks() }
  function onEventBattleTasksTimeExpired(p)  { updateBattleTasks() }
  function onEventBattleTasksFinishedUpdate(p) { updateBattleTasks() }

  function getWwBattleResults()
  {
    if (!is_show_ww_casualties())
      return null

    let logs = ::getUserLogsList({
      show = [
        ::EULT_SESSION_RESULT
      ]
      currentRoomOnly = true
    })

    if (!logs.len())
      return null

    return ::WwBattleResults().updateFromUserlog(logs[0])
  }

  function loadWwCasualtiesHistory()
  {
    if (!::is_worldwar_enabled())
      return

    let wwBattleResults = getWwBattleResults()
    if (!wwBattleResults)
      return

    let taskCallback = ::Callback(function() {
      let view = wwBattleResults.getView()
      let markup = ::handyman.renderCached("%gui/worldWar/battleResults", view)
      let contentObj = scene.findObject("ww_casualties_div")
      if (::checkObj(contentObj))
        guiScene.replaceContentFromText(contentObj, markup, markup.len(), this)
    }, this)

    let operationId = wwBattleResults.operationId
    if (operationId)
      ::g_world_war.updateOperationPreviewAndDo(operationId, taskCallback)
  }

  function showTabsList()
  {
    let tabsObj = scene.findObject("tabs_list")
    tabsObj.show(true)
    let view = { items = [] }
    local tabValue = 0
    let defaultTabName = is_show_ww_casualties() ? "ww_casualties" : ""
    foreach(idx, tabName in tabsList)
    {
      let checkName = "is_show_" + tabName
      if (!(checkName in this) || this[checkName]())
      {
        let title = ::getTblValue(tabName, tabsTitles, "#debriefing/" + tabName)
        view.items.append({
          id = tabName
          text = title
          image = tabName == "battle_tasks_list"? "#ui/gameuiskin#new_reward_icon.svg" : null
        })
        if (tabName == defaultTabName)
          tabValue = idx
      }
    }
    let data = ::handyman.renderCached("%gui/commonParts/shopFilter", view)
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(tabValue)
    onChangeTab(tabsObj)
    updateBattleTasksStatusImg()
  }

    //------------- <CURRENT BATTLE TASK ---------------------
  function updateShortBattleTask()
  {
    if (!is_show_battle_tasks_list(false))
      return

    let buttonObj = scene.findObject("current_battle_tasks")
    if (!::checkObj(buttonObj))
      return

    let battleTasksArray = []
    foreach (config in battleTasksConfigs)
    {
      battleTasksArray.append(::g_battle_tasks.generateItemView(config, { isShortDescription = true }))
    }
    if (::u.isEmpty(battleTasksArray))
      battleTasksArray.append(::g_battle_tasks.generateItemView({
        id = "current_battle_tasks"
        text = "#mainmenu/btnBattleTasks"
        shouldRefreshTimer = true
        }, { isShortDescription = true }))

    let data = ::handyman.renderCached("%gui/unlocks/battleTasksShortItem", { items = battleTasksArray })
    guiScene.replaceContentFromText(buttonObj, data, data.len(), this)
    ::g_battle_tasks.setUpdateTimer(null, buttonObj)
  }
  //------------- </CURRENT BATTLE TASK --------------------


  function is_show_my_stats()
  {
    return !isSpectator  && gm != ::GM_SKIRMISH
  }
  function is_show_players_stats()
  {
    return needPlayersTbl
  }
  function is_show_battle_log()
  {
    return needPlayersTbl && ::HudBattleLog.getLength() > 0
  }
  function is_show_chat_history()
  {
    return needPlayersTbl && ::getTblValue("chatLog", debriefingResult, "") != ""
  }
  function is_show_left_block()
  {
    return is_show_awards_list() || is_show_inventory_gift()
  }
  function is_show_awards_list()
  {
    return !::u.isEmpty(awardsList)
  }
  function is_show_inventory_gift()
  {
    return giftItems != null
  }
  function is_show_ww_casualties()
  {
    return needPlayersTbl && ::is_worldwar_enabled() && ::g_mis_custom_state.getCurMissionRules().isWorldWar
  }
  function is_show_research_list()
  {
    foreach (unitId, unitData in debriefingResult.exp.aircrafts)
      if (isShowUnitInModsResearch(unitId))
        return true
    foreach (ut in unitTypes.types)
      if(getResearchUnitInfo(ut.name))
        return true
    if (getExpInvestUnitTotal() > 0)
      return true
    return false
  }

  function is_show_battle_tasks_list(isNeedBattleTasksList = true)
  {
    return (::has_feature("DebriefingBattleTasks") && ::g_battle_tasks.isAvailableForUser()) &&
      (!isNeedBattleTasksList || battleTasksConfigs.len() > 0)
  }

  function is_show_right_block()
  {
    return isForceShowMyStatsRightBlock || is_show_research_list() || is_show_battle_tasks_list()
  }

  function onChangeTab(obj)
  {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    showTab(obj.getChild(value).id)
    updateBattleTasksList()
    updateBattleTasksRequirementsList()
  }

  function updateScrollableObjects(tabObj, tabName, isEnable)
  {
    foreach (objId, val in ::getTblValue(tabName, tabsScrollableObjs, {}))
    {
      let obj = tabObj.findObject(objId)
      if (::check_obj(obj))
        obj["scrollbarShortcuts"] = isEnable ? val : "no"
    }
  }

  function updateListsButtons()
  {
    let isAnimDone = state==debrState.done
    let isReplayReady = ::has_feature("ClientReplay") && ::is_replay_present() && ::is_replay_turned_on()
    let player = getSelectedPlayer()
    let buttonsList = {
      btn_show_all = isAnimDone && giftItems != null && giftItems.len() > VISIBLE_GIFT_NUMBER
      btn_view_replay = isAnimDone && isReplayReady && !isMp
      btn_save_replay = isAnimDone && isReplayReady && !::is_replay_saved()
      btn_user_options = isAnimDone && (curTab == "players_stats") && player && !player.isBot && ::show_console_buttons
      btn_view_highlights = isAnimDone && ::is_highlights_inited()
    }

    foreach(btn, show in buttonsList)
      showSceneBtn(btn, show)

    let showFacebookBtn = isAnimDone && (curTab == "my_stats" || curTab == "players_stats")
    ::show_facebook_screenshot_button(scene, showFacebookBtn)
  }

  function onChatLinkClick(obj, itype, link)
  {
    if (link.len() > 3 && link.slice(0, 3) == "PL_")
    {
      let name = link.slice(3)
      ::gui_modal_userCard({ name = name })
    }
  }

  function onChatLinkRClick(obj, itype, link)
  {
    if (link.len() > 3 && link.slice(0, 3) == "PL_")
    {
      let name = link.slice(3)
      let player = getPlayerInfo(name)
      if (player)
        ::session_player_rmenu(this, player, getChatLog())
    }
  }

  function onChangeBattlelogFilter(obj)
  {
    if (!::checkObj(obj))
      return
    let filterIdx = obj.getValue()
    ::saveLocalByAccount("wnd/battleLogFilterDebriefing", filterIdx)
    loadBattleLog(filterIdx)
  }

  function onViewReplay(obj)
  {
    if (isInProgress)
      return

    ::set_presence_to_player("replay")
    ::req_unlock_by_client("view_replay", false)
    autosave_replay();
    ::on_view_replay("")
    isInProgress = true
  }

  function onSaveReplay(obj)
  {
    if (isInProgress)
      return
    if (::is_replay_saved() || !::is_replay_present())
      return

    let afterFunc = function(newName)
    {
      let result = ::on_save_replay(newName);
      if (!result)
      {
        msgBox("save_replay_error", ::loc("replays/save_error"),
          [
            ["ok", function() { } ]
          ], "ok")
      }
      updateListsButtons()
    }
    ::gui_modal_name_and_save_replay(this, afterFunc);
  }

  function onViewHighlights()
  {
    if (!::is_highlights_inited())
      return

    ::show_highlights()
  }

  function setGoNext()
  {
    ::go_debriefing_next_func = ::gui_start_mainmenu //default func
    if (needShowWorldWarOperationBtn())
    {
      if (!::g_squad_manager.isInSquad() || ::g_squad_manager.isSquadLeader())
        ::go_debriefing_next_func = function() {
          ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mainmenu) //do not need to back to debriefing
          ::g_world_war.openOperationsOrQueues(true)
        }
      return
    }

    let isMpMode = (gameType & ::GT_COOPERATIVE) || (gameType & ::GT_VERSUS)

    if (::SessionLobby.status == lobbyStates.IN_DEBRIEFING && ::SessionLobby.haveLobby())
      return
    if (isMpMode && !::is_online_available())
      return

    if (isMpMode && needGoLobbyAfterStatistics() && gm != ::GM_DYNAMIC)
    {
      ::go_debriefing_next_func = ::gui_start_mp_lobby
      return
    }

    if (gm == ::GM_CAMPAIGN)
    {
      if (debriefingResult.isSucceed)
      {
        dagor.debug("VIDEO: campaign = "+ ::current_campaign_id + "mission = "+ ::current_campaign_mission)
        if ((::current_campaign_mission == "jpn_guadalcanal_m4")
            || (::current_campaign_mission == "us_guadalcanal_m4"))
          needCheckForVictory(true)
        ::select_next_avail_campaign_mission(::current_campaign_id, ::current_campaign_mission)
      }
      ::go_debriefing_next_func = ::gui_start_menuCampaign
    } else
    if (gm==::GM_TEST_FLIGHT)
      ::go_debriefing_next_func = @() ::gui_start_mainmenu_reload(true)
    else
    if (gm==::GM_DYNAMIC)
    {
      if (isMpMode)
      {
        if (::SessionLobby.isInRoom() && getDynamicResult() == ::MISSION_STATUS_RUNNING)
        {
          ::go_debriefing_next_func = ::gui_start_dynamic_summary
          if (::is_mplayer_host())
            recalcDynamicLayout()
        }
        else
          ::go_debriefing_next_func = ::gui_start_dynamic_summary_f
        return
      }

      if (getDynamicResult() == ::MISSION_STATUS_RUNNING)
      {
        let settings = DataBlock();
        ::mission_settings.dynlist <- ::dynamic_get_list(settings, false)

        let add = []
        for (local i = 0; i < ::mission_settings.dynlist.len(); i++)
        {
          let misblk = ::mission_settings.dynlist[i].mission_settings.mission
          misblk.setStr("mis_file", ::mission_settings.layout)
          misblk.setStr("chapter", ::get_cur_game_mode_name());
          misblk.setStr("type", ::get_cur_game_mode_name());
          add.append(misblk)
        }
        ::add_mission_list_full(::GM_DYNAMIC, add, ::mission_settings.dynlist)
        ::go_debriefing_next_func = ::gui_start_dynamic_summary
      } else
        ::go_debriefing_next_func = ::gui_start_dynamic_summary_f
    } else if (gm == ::GM_SINGLE_MISSION)
    {
      let mission = ::mission_settings?.mission ?? ::get_current_mission_info_cached()
      ::go_debriefing_next_func = ::is_user_mission(mission)
        ? ::gui_start_menuUserMissions
        : ::gui_start_menuSingleMissions
    }
    else
      ::go_debriefing_next_func = ::gui_start_mainmenu
  }

  function needGoLobbyAfterStatistics()
  {
    return !((gameType & ::GT_COOPERATIVE) || (gameType & ::GT_VERSUS))
  }

  function recalcDynamicLayout()
  {
    mission_settings.layout <- ::dynamic_get_layout();
    // FIXME : workaroud for host migration assert (instead of back to lobby - disconnect)
    // http://www.gaijin.lan/mantis/view.php?id=36502
    if (mission_settings.layout)
    {
      let settings = DataBlock();
      ::mission_settings.dynlist <- ::dynamic_get_list(settings, false)

      let add = []
      for (local i = 0; i < ::mission_settings.dynlist.len(); i++)
      {
        let misblk = ::mission_settings.dynlist[i].mission_settings.mission
        misblk.setStr("mis_file", ::mission_settings.layout)
        misblk.setStr("chapter", ::get_cur_game_mode_name());
        misblk.setStr("type", ::get_cur_game_mode_name());
        misblk.setBool("gt_cooperative", true)
        add.append(misblk)
      }
      ::add_mission_list_full(::GM_DYNAMIC, add, ::mission_settings.dynlist)
      ::mission_settings.currentMissionIdx <- 0
      let misBlk = ::mission_settings.dynlist[::mission_settings.currentMissionIdx].mission_settings.mission
      misBlk.setInt("_gameMode", ::GM_DYNAMIC)
      ::mission_settings.missionFull = ::mission_settings.dynlist[::mission_settings.currentMissionIdx]
      ::select_mission_full(misBlk, ::mission_settings.missionFull);
    }
    else
    {
      dagor.debug("no mission_settings.layout, destroy session")
      ::destroy_session_scripted()
    }
  }

  function afterSave()
  {
    applyReturn()
  }

  function applyReturn()
  {
    if (::go_debriefing_next_func != ::gui_start_dynamic_summary)
      ::destroy_session_scripted()

    if (is_show_my_stats())
      setNeedShowRate(debriefingResult, getMyPlace())

    debriefingResult = null
    playCountSound(false)
    isInProgress = false

    ::HudBattleLog.reset()

    if (!::SessionLobby.goForwardAfterDebriefing())
      goForward(::go_debriefing_next_func)
  }

  function goBack()
  {
    if (state != debrState.done && !skipAnim)
    {
      onSkip()
      return
    }

    if (isInProgress)
      return

    isInProgress = true

    autosave_replay();

    if (!::go_debriefing_next_func)
      ::go_debriefing_next_func = ::gui_start_mainmenu

    if (isReplay)
      applyReturn()
    else
    {  //do_finalize_debriefing
      save()
    }
    playCountSound(false)
    ::my_stats.markStatsReset()
  }

  function onNext()
  {
    if (state != debrState.done && !skipAnim)
    {
      onSkip()
      return
    }

    let needGoToBattle = isToBattleActionEnabled()
    switchWwOperationToCurrent()
    goBack()

    if (needGoToBattle)
      goToBattle()
  }

  function goToBattle()
  {
    getGoToBattleAction()()
  }

  function isToBattleActionEnabled()
  {
    return (skipAnim || state == debrState.done)
      && (gm == ::GM_DOMINATION) && !!(gameType & ::GT_VERSUS)
      && !::checkIsInQueue()
      && !(::g_squad_manager.isSquadMember() && ::g_squad_manager.isMeReady())
      && !::SessionLobby.hasSessionInLobby()
      && !hasAnyFinishedResearch()
      && !isSpectator
      && ::go_debriefing_next_func == ::gui_start_mainmenu
      && !::checkNonApprovedResearches(true, false)
  }

  function needShowWorldWarOperationBtn()
  {
    return ::is_worldwar_enabled() && ::g_world_war.isLastFlightWasWwBattle
  }

  function switchWwOperationToCurrent()
  {
    if (!needShowWorldWarOperationBtn())
      return

    let wwBattleRes = getWwBattleResults()
    if (wwBattleRes)
      ::g_world_war.saveLastPlayed(wwBattleRes.getOperationId(), wwBattleRes.getPlayerCountry())
    else
    {
      let missionRules = ::g_mis_custom_state.getCurMissionRules()
      let operationId = missionRules?.missionParams?.customRules?.operationId
      if (!operationId)
        return

      ::g_world_war.saveLastPlayed(operationId.tointeger(), ::get_profile_country_sq())
    }

    ::go_debriefing_next_func = function() {
      ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mainmenu)
      ::g_world_war.openMainWnd()
    }
  }

  function updateStartButton()
  {
    if (state != debrState.done)
      return

    let isToBattleBtnVisible = isToBattleActionEnabled()
    let showWorldWarOperationBtn = needShowWorldWarOperationBtn()

    ::showBtnTable(scene, {
      btn_next = true
      btn_back = isToBattleBtnVisible || showWorldWarOperationBtn
    })

    let btnNextLocId = showWorldWarOperationBtn ? "worldWar/stayInOperation"
      : !isToBattleBtnVisible ? "mainmenu/btnOk"
      : ::g_squad_manager.isSquadMember() ? "mainmenu/btnReady"
      : getToBattleLocId()

    setDoubleTextToButton(scene, "btn_next", ::loc(btnNextLocId))

    local backBtnTextLocId = "mainmenu/btnQuit"
    if (isToBattleBtnVisible)
      backBtnTextLocId = "mainmenu/toHangar"
    else if (showWorldWarOperationBtn)
      backBtnTextLocId = (!::g_squad_manager.isInSquad() || ::g_squad_manager.isSquadLeader())
        ? "worldWar/btn_all_battles" : "mainmenu/toHangar"
    scene.findObject("btn_back").setValue(::loc(backBtnTextLocId))
  }

  function onEventSquadSetReady(p)
  {
    updateStartButton()
  }

  function onEventSquadStatusChanged(p)
  {
    updateStartButton()
  }

  function onEventQueueChangeState(params)
  {
    updateStartButton()
  }

  onEventToBattleLocChanged = @(params) updateStartButton()

  function onEventMatchingDisconnect(p)
  {
    ::go_debriefing_next_func = startLogout
  }

  function isDelayedLogoutOnDisconnect()
  {
    ::go_debriefing_next_func = startLogout
    return true
  }

  function throwBattleEndEvent()
  {
    let eventId = ::getTblValue("eventId", debriefingResult)
    if (eventId)
      ::broadcastEvent("EventBattleEnded", {eventId = eventId})
    ::broadcastEvent("BattleEnded", { battleResult = debriefingResult?.exp.result })
  }

  function checkPopupWindows()
  {
    let country = getDebriefingCountry()

    //check unlocks windows
    let wnd_unlock_gained = getUserLogsList({
      show = [::EULT_NEW_UNLOCK]
      unlocks = [::UNLOCKABLE_AIRCRAFT, ::UNLOCKABLE_AWARD]
      filters = { popupInDebriefing = [true] }
      currentRoomOnly = true
      disableVisible = true
    })
    foreach(log in wnd_unlock_gained)
      ::showUnlockWnd(::build_log_unlock_data(log))

    //check new rank and unlock country by exp gained
    let new_rank = ::get_player_rank_by_country(country)
    local old_rank = playerRankByCountries?[country] ?? new_rank

    if (country!="" && country!="country_0" &&
        !::isCountryAvailable(country) && ::get_player_exp_by_country(country)>0)
    {
      unlockCountry(country)
      old_rank = -1 //new country unlocked!
    }

    if (new_rank > old_rank)
    {
      let gained_ranks = [];

      for (local i = old_rank+1; i<=new_rank; i++)
        gained_ranks.append(i);
      checkRankUpWindow(country, old_rank, new_rank);
    }

    //check country unlocks by N battle
    let country_unlock_gained = getUserLogsList({
      show = [::EULT_NEW_UNLOCK]
      unlocks = [::UNLOCKABLE_COUNTRY]
      currentRoomOnly = true
      disableVisible = true
    })
    foreach(log in country_unlock_gained)
    {
      ::showUnlockWnd(::build_log_unlock_data(log))
      if (("unlockId" in log) && log.unlockId!=country && ::isInArray(log.unlockId, shopCountriesList))
        unlockCountry(log.unlockId)
    }

    //check userlog entry for tournament special rewards
    let tornament_special_rewards = ::getUserLogsList({
      show = [::EULT_CHARD_AWARD]
      currentRoomOnly = true
      disableVisible = true
      filters = { rewardType = ["TournamentReward"] }
    })

    let rewardsArray = []
    foreach(log in tornament_special_rewards)
      rewardsArray.extend(getTournamentRewardData(log))

    foreach(rewardConfig in rewardsArray)
      ::showUnlockWnd(rewardConfig)

    openGiftTrophy()
  }

  function updateInfoText()
  {
    if (debriefingResult == null)
      return
    local infoText = ""
    local infoColor = "active"

    let wpdata = ::get_session_warpoints()

    if (debriefingResult.exp.result == ::STATS_RESULT_ABORTED_BY_KICK)
    {
      infoText = getKickReasonLocText()
      infoColor = "bad"
    }
    else if ((gm == ::GM_DYNAMIC || gm == ::GM_BUILDER) && wpdata.isRewardReduced)
      infoText = ::loc("debriefing/award_reduced")
    else
    {
      local hasAnyReward = false
      foreach (source in [ "Total", "Mission" ])
        foreach (currency in [ "exp", "wp", "gold" ])
          if (::getTblValue(currency + source, debriefingResult.exp, 0) > 0)
            hasAnyReward = true

      if (!hasAnyReward)
      {
        if (gm == ::GM_SINGLE_MISSION || gm == ::GM_CAMPAIGN || gm == ::GM_TRAINING)
        {
          if (debriefingResult.isSucceed)
            infoText = ::loc("debriefing/award_already_received")
        }
        else if (isMp && !isDebriefingResultFull() && gm == ::GM_DOMINATION)
        {
          infoText = ::loc("debriefing/most_award_after_battle")
          infoColor = "userlog"
        }
        else if (isMp && debriefingResult.exp.result == ::STATS_RESULT_IN_PROGRESS && !(gameType & ::GT_RACE))
          infoText = ::loc("debriefing/exp_and_reward_will_be_later")
      }
    }

    let isShow = infoText != ""
    let infoObj = scene.findObject("stat_info_text")
    infoObj.show(isShow)
    if (isShow)
    {
      infoObj.setValue(infoText)
      infoObj["overlayTextColor"] = infoColor
      guiScene.applyPendingChanges(false)
      infoObj.scrollToView()
    }
  }

  function getBoostersText()
  {
    let textsList = []
    let activeBoosters = ::getTblValue("activeBoosters", debriefingResult, [])
    if (activeBoosters.len() > 0)
      foreach(effectType in boosterEffectType)
      {
        let boostersArray = []
        foreach(idx, block in activeBoosters)
        {
          let item = ::ItemsManager.findItemById(block.itemId)
          if (item && effectType.checkBooster(item))
            boostersArray.append(item)
        }

        if (boostersArray.len())
          textsList.append(getActiveBoostersDescription(boostersArray, effectType))
      }
    return ::g_string.implode(textsList, "\n\n")
  }

  function getBoostersTotalEffects()
  {
    let activeBoosters = ::getTblValue("activeBoosters", debriefingResult, [])
    let boostersArray = []
    foreach(block in activeBoosters)
    {
      let item = ::ItemsManager.findItemById(block.itemId)
      if (item)
        boostersArray.append(item)
    }
    return getBoostersEffects(boostersArray)
  }

  function getInvetoryGiftActionData()
  {
    if (!giftItems)
      return null

    let itemDefId = giftItems?[0]?.item
    let wSet = workshop.getSetByItemId(itemDefId)
    if (wSet)
      return {
        btnText = ::loc("items/workshop")
        action = @() wSet.needShowPreview() ? workshopPreview.open(wSet)
          : ::gui_start_items_list(itemsTab.WORKSHOP, {
              curSheet = { id = wSet.getShopTabId() },
              curItem = ::ItemsManager.getInventoryItemById(itemDefId)
              initSubsetId = wSet.getSubsetIdByItemId(itemDefId)
            })
      }

    return null
  }

  function updateInventoryButton()
  {
    let actionData = getInvetoryGiftActionData()
    let actionBtn = showSceneBtn("btn_inventory_gift_action", actionData != null)
    if (actionData && actionBtn)
      setColoredDoubleTextToButton(scene, "btn_inventory_gift_action", actionData.btnText)
  }

  function onInventoryGiftAction()
  {
    let actionData = getInvetoryGiftActionData()
    if (actionData)
      actionData.action()
  }

  getUserlogsMask = @() state == debrState.done && isSceneActiveNoModals()
    ? USERLOG_POPUP.OPEN_TROPHY
    : USERLOG_POPUP.NONE

  function onEventModalWndDestroy(p)
  {
    if (state == debrState.done && isSceneActiveNoModals())
      ::checkNewNotificationUserlogs()
  }

  function getChatLog()
  {
    return debriefingResult?.logForBanhammer
  }

  function getDebriefingCountry()
  {
    if (debriefingResult)
      return debriefingResult.country
    return ""
  }

  function getMissionBonusText()
  {
    if (gm != ::GM_DOMINATION)
      return ""

    let isWin = debriefingResult.isSucceed
    let bonusWp = (isWin ? ::get_warpoints_blk()?.winK : ::get_warpoints_blk()?.defeatK) ?? 0.0
    let rBlk = ::get_ranks_blk()
    let missionRp = (isWin ? rBlk?.expForVictoryVersusPerSec : rBlk?.expForPlayingVersusPerSec) ?? 0.0
    let baseRp = rBlk?.expBaseVersusPerSec ?? 0
    let bonusRp = (baseRp > 0) ? (missionRp.tofloat() / baseRp - 1.0) : 0.0
    let rp = (bonusRp > 0) ? ::ceil(bonusRp * 100) : 0
    let wp = (bonusWp > 0) ? ::ceil(bonusWp * 100) : 0
    let textRp = rp ? ::getRpPriceText($"+{rp}%", true) : ""
    let textWp = wp ? ::getWpPriceText($"+{wp}%", true) : ""
    return ::g_string.implode([textRp, textWp], ::loc("ui/comma"))
  }

  function getCurAwardText()
  {
    return ::Cost(::get_premium_reward_wp(), 0, ::get_premium_reward_xp()).tostring()
  }

  getLocalTeam = @() ::get_local_team_for_mpstats(debriefingResult.localTeam)
  getMplayersList = @(team) team == ::GET_MPLAYERS_LIST
    ? debriefingResult.mplayers_list
    : debriefingResult.mplayers_list.filter(@(player) player.team == team)
  getOverrideCountryIconByTeam = @(team) debriefingResult.overrideCountryIconByTeam[team]

  function initStatsMissionParams() {
    gameMode = debriefingResult.gm
    isOnline = ::g_login.isLoggedIn()

    isTeamsRandom = !isTeamplay || gameMode == ::GM_DOMINATION
    if (debriefingResult.isInRoom || isReplay)
      isTeamsWithCountryFlags = isTeamplay &&
        (debriefingResult.missionDifficultyInt > 0 || !debriefingResult.isSymmetric)

    missionObjectives = debriefingResult.missionObjectives
  }

  isInited = true
  state = 0
  skipAnim = false
  isMp = false
  isReplay = false
  //haveCountryExp = true

  tabsList = [ "my_stats", "players_stats", "ww_casualties", "awards_list", "battle_tasks_list", "battle_log", "chat_history" ]
  tabsTitles = { awards_list = "#profile/awards", battle_tasks_list = "#userlog/page/battletasks"}
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
  unlockAwardsList = null
  currentAwardsList = null
  currentAwardsListConfig = null
  currentAwardsListIdx = 0

  awardOffset = 0
  awardsAppearTime = 2.0 //can be lower than this, not higher
  awardDelay = 0.25
  awardFlyTime = 0.5

  usedUnitTypes = null

  isInProgress = false
}
