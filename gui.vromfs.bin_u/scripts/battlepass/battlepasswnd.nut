let { seasonLevel, season, seasonMainPrizesData } = require("%scripts/battlePass/seasonState.nut")
let { seasonStages, getStageViewData, doubleWidthStagesIcon  } = require("%scripts/battlePass/seasonStages.nut")
let { receiveRewards, unlockProgress, activeUnlocks } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { updateChallenges, curSeasonChallenges, getChallengeView, mainChallengeOfSeasonId
} = require("%scripts/battlePass/challenges.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { seasonLvlWatchObj, todayLoginExpWatchObj, loginStreakWatchObj,
  tomorowLoginExpWatchObj, easyDailyTaskProgressWatchObj,
  mediumDailyTaskProgressWatchObj, seasonTasksProgressWatchObj,
  leftSpecialTasksBoughtCountWatchObj, levelExpWatchObj, hasChallengesRewardWatchObj
} = require("%scripts/battlePass/watchObjInfoConfig.nut")
let { openBattlePassShopWnd } = require("%scripts/battlePass/progressShop.nut")
let { isUserstatMissingData } = require("%scripts/userstat/userstat.nut")
let { getSelectedChild, findChildIndex } = require("%sqDagui/daguiUtil.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { number_of_set_bits } = require("%sqstd/math.nut")
let { hasBattlePass } = require("%scripts/battlePass/unlocksRewardsState.nut")
require("%scripts/promo/battlePassPromoHandler.nut") // Independed Modules

let watchObjInfoConfig = {
  season_lvl = seasonLvlWatchObj
  level_exp = levelExpWatchObj
  today_login_exp = todayLoginExpWatchObj
  login_streak = loginStreakWatchObj
  tomorow_login_exp = tomorowLoginExpWatchObj
  season_tasks_progress = seasonTasksProgressWatchObj
}

let watchObjInfoBattleTasksConfig = {
  easy_daily_task_progress = easyDailyTaskProgressWatchObj
  medium_daily_task_progress = mediumDailyTaskProgressWatchObj
  left_special_tasks_bought_count = leftSpecialTasksBoughtCountWatchObj
}

local BattlePassWnd = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType          = handlerType.MODAL
  sceneBlkName     = "%gui/battlePass/battlePassWnd.blk"

  stageIndexOffset = 0
  stageIndexOffsetAddedByPages = null
  curPage = 0
  curPageStagesList = null
  stagesPerPage = 0
  mainPrizeData = null

  sheetsList = [{
    objId = "battle_pass_sheet"
    text = "#battlePass"
    fillFunc = "fillBattlePassSheet"
  },
  {
    objId = "challenges_sheet"
    text = "#mainmenu/btnUnlockChallenge"
    tabImage = "#ui/gameuiskin#new_reward_icon.svg"
    getTabImageParam = @() $"behaviour:t='bhvUpdateByWatched'; value:t='{stashBhvValueConfig(hasChallengesRewardWatchObj)}'"
    fillFunc = "fillChallengesSheet"
  }]

  isInitedBattlePassSheet = false
  isInitedChallengesSheet = false
  curChallengeId = ""
  hoverChallengeId = ""
  isFillingChallengesList = false
  needCalculateCurPage = false

  function initScreen() {
    updateButtons()
    calculateStageListSizeOnce()

    //init main sheet
    calculateCurPage()
    initStageUpdater()
    initBattlePassInfo()
    initBattleTasksInfo()

    //init challenges sheet
    initChallengesUpdater()

    initSheets()
  }

  function calculateStageListSizeOnce() {
    if (stagesPerPage >= 1)
      return

    let wndObj = scene.findObject("wnd_battlePass")
    let sizes = ::g_dagui_utils.adjustWindowSize(wndObj, scene.findObject("battle_pass_sheet"),
      "@battlePassStageWidth", "@battlePassStageHeight", "@battlePassStageMargin",
      "@battlePassStageMargin", { windowSizeY = 0 })
    stagesPerPage = sizes.itemsCountX
    guiScene.applyPendingChanges(false)
    wndObj.size = $"{sizes.windowSize[0]}, {wndObj.getSize()[1]}"
  }

  function calculateCurPage(lineupType = -1) {
    stageIndexOffsetAddedByPages = {}
    let curStageIdx = getAvailableStageIdx(lineupType)
    let middleIdx = ::ceil(stagesPerPage.tofloat() / 2) - 1
    let doubleStagesCount = doubleWidthStagesIcon.value.reduce(@(res, value) res + (value < curStageIdx ? 1 : 0), 0)
    stageIndexOffset = curStageIdx <= middleIdx ? 0
      : (((curStageIdx + doubleStagesCount) % stagesPerPage) - middleIdx)
    let pageOffset = stageIndexOffset > 0 ? 0 : -1
    curPage = curStageIdx <= middleIdx ? 0
      : ::ceil((curStageIdx.tofloat() + doubleStagesCount - stageIndexOffset) / stagesPerPage).tointeger() + pageOffset
  }

  // lineupType: 0 - bp, 1 - free, -1 - any
  function getAvailableStageIdx(lineupType = -1) {
    return seasonStages.value.findvalue(function(stageData) {
      return ((lineupType == -1 || stageData.isFree.tointeger() == lineupType)
        && stageData.prizeStatus == "available") || stageData.stage >= seasonLevel.value
    })?.stage ?? 0
  }

  function goToPage(obj) {
    curPage = obj.to_page.tointeger()
    if (curPage == 0) {
      stageIndexOffset = 0
      stageIndexOffsetAddedByPages = {}
    }
    fillStagePage()
  }

  function fillStagePage(forceUpdate = false) {
    updateStagePage(scene.findObject("wnd_battlePass"), seasonStages.value, forceUpdate)
  }

  function updateStagePage(obj, stagesList, forceUpdate = false) {
    if (getCurSheetObjId() != "battle_pass_sheet")
      return

    if (needCalculateCurPage) {
      calculateCurPage()
      needCalculateCurPage = false
    }
    let view = { battlePassStage = [], skipButtonNavigation = ::show_console_buttons }
    let curPageOffset = stageIndexOffset > 0 ? -1 : 0
    local pageStartIndex = max((curPage + curPageOffset) * stagesPerPage  + stageIndexOffset, 0)
    let doubleStagesCount = doubleWidthStagesIcon.value.reduce(@(res, value) res + (value < (pageStartIndex - res) ? 1 : 0), 0)
    pageStartIndex = max(pageStartIndex - doubleStagesCount, 0)
    local pageEndIndex = min(pageStartIndex + stagesPerPage, stagesList.len())
    foreach (stage in doubleWidthStagesIcon.value) {
      if (stage == pageEndIndex) {
        pageStartIndex --
        pageEndIndex--
        if (curPage not in stageIndexOffsetAddedByPages) {
          stageIndexOffsetAddedByPages[curPage] <- true
          stageIndexOffset--
        }
        continue
      }

      if (stage <= pageStartIndex || stage > pageEndIndex)
        continue

      pageEndIndex--
    }

    local isChangesRewards = false
    local idxOnPage = 0
    for(local i=pageStartIndex; i < pageEndIndex; i++) {
      let stageView = getStageViewData(stagesList[i], idxOnPage)
      view.battlePassStage.append(stageView)
      isChangesRewards = isChangesRewards
        || !isEqualStageReward(curPageStagesList?[idxOnPage], stageView)
      idxOnPage++
    }

    curPageStagesList = view.battlePassStage
    let stagesObj = scene.findObject("battlePassStages")
    if (isChangesRewards || forceUpdate) {
      let data = ::handyman.renderCached("%gui/battlePass/battlePassStage", view)
      guiScene.replaceContentFromText(stagesObj, data, data.len(), this)
    } else {
      foreach (idx, stage in view.battlePassStage) {
        let stageObj = stagesObj.getChild(idx)
        stageObj.stageStatus = stage.stageStatus
        stageObj.prizeStatus = stage.prizeStatus
      }
    }

    ::generatePaginator(scene.findObject("paginator_place"), this, curPage,
      ::ceil((stagesList.len().tofloat() + doubleWidthStagesIcon.value.len()) / stagesPerPage)
      - 1, null, true /*show last page*/)
  }

  isEqualStageReward = @(curStage, newStage)
    curStage?.holderId == newStage.holderId
    && curStage?.stage == newStage.stage
    && curStage?.rewardId == newStage.rewardId

  function onReceiveRewards(obj) {
    let { holderId = null, stage = null } = obj
    if (holderId == null || stage == null)
      return

    let { lastRewardedStage = null } = unlockProgress.value?[holderId]
    if (lastRewardedStage == null
      || (lastRewardedStage + 1) != stage.tointeger())
      return

    receiveRewards(holderId)
  }

  function onEventItemsShopUpdate(params) {
    fillStagePage(true)//force update stages because recived itemdefs for it
  }

  function initBattlePassInfo() {
    updateChallenges()
    foreach (objId, config in watchObjInfoConfig)
      scene.findObject(objId).setValue(stashBhvValueConfig(config))
  }

  function initBattleTasksInfo() {
    if (!::g_battle_tasks.isAvailableForUser())
      return

    foreach (objId, config in watchObjInfoBattleTasksConfig)
      scene.findObject(objId).setValue(stashBhvValueConfig(config))

    this.showSceneBtn("btn_warbondsShop",
      ::g_warbonds.isShopAvailable() && !::isHandlerInScene(::gui_handlers.WarbondsShop))
    this.showSceneBtn("btn_battleTask", true)
    this.showSceneBtn("battle_tasks_info_nest", true)

    ::g_battle_tasks.setUpdateTimer(
      ::g_battle_tasks.currentTasksArray.findvalue(@(v) v._puType == "Easy"),
      scene.findObject("task_timer_nest"),
      {addText = $"{::loc("mainmenu/btnBattleTasks")}{::loc("ui/colon")}"})
  }

  function initStageUpdater() {
    scene.findObject("wnd_battlePass").setValue(stashBhvValueConfig([{
      watch = seasonStages
      updateFunc = ::Callback(@(obj, stagesList) updateStagePage(obj, stagesList), this)
    },
    {
      watch = season
      updateFunc = @(obj, value)
        obj.findObject("wnd_title").setValue(::loc("battlePass/name", {
          name = ::loc($"battlePass/seasonName/{value}")
        }))
    },
    {
      watch = seasonMainPrizesData
      updateFunc = ::Callback(@(obj, mainPrizesValue) updateMainPrizeData(mainPrizesValue), this)
    }]))
  }

  function onEventBattlePassCacheInvalidate(params) {
    updateChallenges()
  }

  onWarbondsShop = @() ::g_warbonds.openShop()
  onBattleTask = @() ::gui_start_battle_tasks_wnd()

  function updateMainPrizeData(mainPrizesValue) {
    let countMainPrizes = mainPrizesValue.len()
    let mainPrizeImage = mainPrizeData?.mainPrizeImage
    if (countMainPrizes == 0 || (mainPrizeImage != null && mainPrizesValue.findvalue(
        @(v) v?.mainPrizeImage == mainPrizeImage) != null)) //main prize is already showed
      return

    mainPrizeData = clone mainPrizesValue[::math.rnd() % countMainPrizes]
    fillPromoBlock()
  }

  function fillPromoBlock() {
    let promoImage = mainPrizeData?.mainPrizeImage
    if (promoImage != null)
      scene.findObject("promo_img")["background-image"] = promoImage

    this.showSceneBtn("congrat_content", false)
    this.showSceneBtn("promo_preview", ::getAircraftByName(mainPrizeData?.mainPrizeId) != null)
  }

  function onMainPrizePreview(obj) {
    if (!isValid())
      return

    ::getAircraftByName(mainPrizeData?.mainPrizeId)?.doPreview()
  }

  function getHandlerRestoreData() {
    let data = {
      openData = {
        mainPrizeData = mainPrizeData
      }
      stateData = {
        stageIndexOffset = stageIndexOffset
        curPage = curPage
      }
    }
    return data
  }

  function restoreHandler(stateData) {
    curPage = stateData.curPage
    stageIndexOffset = stateData.stageIndexOffset
    fillStagePage()
    fillPromoBlock()
  }

  function onEventBeforeStartShowroom(p) {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onOpenBattlePassWnd() {
    openBattlePassShopWnd()
  }

  function initSheets() {
    let view = {tabs = []}
    foreach (idx, sheetData in sheetsList)
    {
      view.tabs.append({
        tabName = sheetData.text
        navImagesText = ::get_navigation_images_text(idx, sheetsList.len())
        tabImage = sheetData?.tabImage
        tabImageParam = sheetData?.getTabImageParam()
      })
    }

    let data = ::handyman.renderCached("%gui/frameHeaderTabs", view)
    let sheetsListObj = scene.findObject("sheet_list")
    guiScene.replaceContentFromText(sheetsListObj, data, data.len(), this)
    sheetsListObj.setValue(0)
  }

  function onSheetChange(obj) {
    let curId = obj.getValue()
    foreach (idx, sheetData in sheetsList) {
      let isVisible = curId == idx
      this.showSceneBtn(sheetData.objId, isVisible)
      if (isVisible)
        this[sheetData.fillFunc]()
    }
  }

  function getCurSheetObjId() {
    return sheetsList?[scene.findObject("sheet_list").getValue()].objId
  }

  function fillBattlePassSheet() {
    scene.findObject("paginator_place").show(true)
    fillStagePage()
  }

  function fillChallengesSheet() {
    scene.findObject("paginator_place").show(false)

    let sheetObj = scene.findObject("challenges_sheet")
    updateChallengesSheet(sheetObj, curSeasonChallenges.value)

    let listObj = sheetObj.findObject("challenges_list")
    let idx = findChildIndex(listObj, @(i) i?.battleTaskStatus == "complete")
    if (idx == -1)
      return

    if (idx != listObj.getValue())
      listObj.setValue(idx)
    else
      onChallengeSelect(listObj)
  }

  function initChallengesUpdater() {
    scene.findObject("challenges_sheet").setValue(stashBhvValueConfig([{
      watch = curSeasonChallenges
      updateFunc = ::Callback(@(obj, challenges) updateChallengesSheet(obj, challenges), this)
    },
    {
      watch = activeUnlocks
      updateFunc = ::Callback(@(obj, unlocks) updateChallengesSheet(obj, curSeasonChallenges.value), this)
    }]))
  }

  unlockToFavorites = @(obj) ::g_unlocks.unlockToFavorites(obj)
  onChallengeHover = @(obj) hoverChallengeId = obj.id

  function updateChallengesSheet(obj, challenges) {
    if (getCurSheetObjId() != "challenges_sheet")
      return

    let view = { items = challenges.map(
      @(config) getChallengeView(config, { hoverAction = "onChallengeHover" })) }
    let challengesObj = scene.findObject("challenges_list")
    let data = ::handyman.renderCached("%gui/unlocks/battleTasksItem", view)
    guiScene.replaceContentFromText(challengesObj, data, data.len(), this)

    let challengeId = curChallengeId
    let curChallengeIdx = challenges.findindex(@(challenge) challenge.id == challengeId) ?? 0
    isFillingChallengesList = true
    challengesObj.setValue(curChallengeIdx)
    isFillingChallengesList = false


    let mainChallengeOfSeason = challenges.findvalue(@(challenge) challenge.id == mainChallengeOfSeasonId.value)
    let hasMainChallenge = mainChallengeOfSeason != null
    let mainChallengeProgressObj = ::showBtn("main_challenge_progress", hasMainChallenge, obj)
    if (!hasMainChallenge)
      return

    let unlockConfig = ::build_conditions_config(mainChallengeOfSeason)

    local curValue = unlockConfig.curVal
    local maxValue = unlockConfig.maxVal

    let isBitMode = ::UnlockConditions.isBitModeType(unlockConfig.type)
    if (isBitMode) {
      curValue = number_of_set_bits(curValue)
      maxValue = number_of_set_bits(maxValue)
    }

    mainChallengeProgressObj.findObject("progress_bar").setValue(
      (maxValue > 0 ? (curValue.tofloat() / maxValue) : 0) * 1000.0)
    mainChallengeProgressObj.findObject("progress_text").setValue(
      $"{curValue}{::loc("weapons_types/short/separator")}{maxValue}")
  }

  getSelectedChildId = @(obj) getSelectedChild(obj)?.id ?? ""

  function onEventFavoriteUnlocksChanged(params)
  {
    if (getCurSheetObjId() != "challenges_sheet")
      return

    let listBoxObj = scene.findObject("challenges_list")
    if (!listBoxObj.isValid())
      return

    for (local i = 0; i < listBoxObj.childrenCount(); i++)
    {
      let challengeObj = listBoxObj.getChild(i)
      if(params.changedId == challengeObj?.id)
      {
        let cbObj = challengeObj.findObject("checkbox_favorites")
        if(cbObj.isValid())
          cbObj.setValue(params.value)
      }
    }
  }

  function onChallengeSelect(obj) {
    let childObj = getSelectedChild(obj)
    curChallengeId = childObj?.id ?? ""
    if (isFillingChallengesList || childObj == null)
      return

    guiScene.applyPendingChanges(false)
    childObj.scrollToView()
    ::move_mouse_on_obj(childObj)
  }

  function expandHoverChallenge()
  {
    let listBoxObj = scene.findObject("challenges_list")
    let total = listBoxObj.childrenCount()
    if (total == 0)
      return

    for (local i = 0; i < total; i++)
      if(hoverChallengeId == listBoxObj.getChild(i).id)
        listBoxObj.setValue(i)
  }

  function challengeToFavoritesByActivateItem(obj)
  {
    curChallengeId = getSelectedChildId(obj)
    let checkBoxObj = obj.findObject(curChallengeId)?.findObject("checkbox_favorites")
    if (checkBoxObj?.isValid())
      checkBoxObj.setValue(!checkBoxObj.getValue())
  }

  onChallengeDblClick = @(obj) curChallengeId == hoverChallengeId
    ? challengeToFavoritesByActivateItem(obj) : expandHoverChallenge()

  function getCurrentConfig() {
    let listBoxObj = scene.findObject("challenges_list")
    if (!::check_obj(listBoxObj))
      return null

    return ::build_conditions_config(
      curSeasonChallenges.value?[listBoxObj.getValue()])
  }

  function onViewBattleTaskRequirements() {
    let awardsList = []
    foreach(id in getCurrentConfig()?.names ?? [])
      awardsList.append(::build_log_unlock_data(::build_conditions_config(::g_unlocks.getUnlockById(id))))

    ::showUnlocksGroupWnd([{
      unlocksList = awardsList
      titleText = ::loc("unlocks/requirements")
    }])
  }

  onGetRewardForTask = @(obj) receiveRewards(obj?.task_id)

  function congratulationBattlePassPurchased() {
    scene.findObject("sheet_list").setValue(0)
    this.showSceneBtn("congrat_content", true)
    scene.findObject("promo_img")["background-image"] = "#ui/images/bp_bg.jpg?P1"
    this.showSceneBtn("promo_preview", false)
  }

  function onEventBattlePassPurchased(p) {
    needCalculateCurPage = true
    doWhenActiveOnce("congratulationBattlePassPurchased")
  }

  function onStatusIconClick(obj) {
    let isFree = obj?.isFree == "yes"
    if (isFree || hasBattlePass.value) {
      let okBtnId = "#battlePass/msgbox/gotoPrize"
      this.msgBox("gotoPrize", ::loc("battlePass/msgbox/gotoPrizeTitle"), [
        [okBtnId, ::Callback(@() gotoPrize(isFree.tointeger()), this)],
        ["cancel"]], okBtnId)
    }
    else {
      let okBtnId = "#battlePass/btn_buy"
      this.msgBox("gotoBpShop", ::loc("battlePass/msgbox/gotoBpShopTitle"), [
        [okBtnId, openBattlePassShopWnd],
        ["cancel"]], okBtnId)
    }
  }

  function gotoPrize(lineupType) {
    calculateCurPage(lineupType)
    fillStagePage()
  }

  function updateButtons() {
    this.showSceneBtn("btn_wiki_link", ::has_feature("AllowExternalLink") && !::is_vendor_tencent())
  }
}

::gui_handlers.BattlePassWnd <- BattlePassWnd

let function openBattlePassWnd() {
  if (isUserstatMissingData.value) {
    ::showInfoMsgBox(::loc("userstat/missingDataMsg"), "userstat_missing_data_msgbox")
    return
  }

  ::handlersManager.loadHandler(BattlePassWnd)
}

addPromoAction("battle_pass", @(handler, params, obj) openBattlePassWnd())

return {
  openBattlePassWnd
}
