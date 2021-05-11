local { seasonLevel, season, seasonMainPrizesData } = require("scripts/battlePass/seasonState.nut")
local { seasonStages, getStageViewData } = require("scripts/battlePass/seasonStages.nut")
local { receiveRewards, unlockProgress, activeUnlocks } = require("scripts/unlocks/userstatUnlocksState.nut")
local { updateChallenges, curSeasonChallenges, getChallengeView, mainChallengeOfSeasonId
} = require("scripts/battlePass/challenges.nut")
local { stashBhvValueConfig } = require("sqDagui/guiBhv/guiBhvValueConfig.nut")
local { seasonLvlWatchObj, todayLoginExpWatchObj, loginStreakWatchObj,
  tomorowLoginExpWatchObj, easyDailyTaskProgressWatchObj,
  mediumDailyTaskProgressWatchObj, seasonTasksProgressWatchObj,
  leftSpecialTasksBoughtCountWatchObj, levelExpWatchObj, hasChallengesRewardWatchObj
} = require("scripts/battlePass/watchObjInfoConfig.nut")
local { openBattlePassShopWnd } = require("scripts/battlePass/progressShop.nut")
local { isUserstatMissingData } = require("scripts/userstat/userstat.nut")
local { getSelectedChild } = require("sqDagui/daguiUtil.nut")
local { addPromoAction } = require("scripts/promo/promoActions.nut")
local { number_of_set_bits } = require("std/math.nut")
require("scripts/promo/battlePassPromoHandler.nut") // Independed Modules

local watchObjInfoConfig = {
  season_lvl = seasonLvlWatchObj
  level_exp = levelExpWatchObj
  today_login_exp = todayLoginExpWatchObj
  login_streak = loginStreakWatchObj
  tomorow_login_exp = tomorowLoginExpWatchObj
  season_tasks_progress = seasonTasksProgressWatchObj
}

local watchObjInfoBattleTasksConfig = {
  easy_daily_task_progress = easyDailyTaskProgressWatchObj
  medium_daily_task_progress = mediumDailyTaskProgressWatchObj
  left_special_tasks_bought_count = leftSpecialTasksBoughtCountWatchObj
}

local BattlePassWnd = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType          = handlerType.MODAL
  sceneBlkName     = "gui/battlePass/battlePassWnd.blk"

  stageIndexOffset = 0
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
    tabImage = "#ui/gameuiskin#new_reward_icon"
    getTabImageParam = @() $"behaviour:t='bhvUpdateByWatched'; value:t='{stashBhvValueConfig(hasChallengesRewardWatchObj)}'"
    fillFunc = "fillChallengesSheet"
  }]

  isInitedBattlePassSheet = false
  isInitedChallengesSheet = false
  curChallengeId = ""
  hoverChallengeId = ""
  isFillingChallengesList = false
  needCalculateCurPage = true

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

    local wndObj = scene.findObject("wnd_battlePass")
    local sizes = ::g_dagui_utils.adjustWindowSize(wndObj, scene.findObject("battle_pass_sheet"),
      "@battlePassStageWidth", "@battlePassStageHeight", "@battlePassStageMargin",
      "@battlePassStageMargin", { windowSizeY = 0 })
    stagesPerPage = sizes.itemsCountX
    guiScene.applyPendingChanges(false)
    wndObj.size = $"{sizes.windowSize[0]}, {wndObj.getSize()[1]}"
  }

  function calculateCurPage() {
    local stagesList = seasonStages.value
    local curStageIdx = stagesList.findindex(@(stageData) stageData.prizeStatus == "available"
      || stageData.stage >= seasonLevel.value) ?? 0
    local middleIdx = ::ceil(stagesPerPage.tofloat()/2) - 1
    stageIndexOffset = curStageIdx <= middleIdx ? 0
      : ((curStageIdx % stagesPerPage) - middleIdx)
    local pageOffset = stageIndexOffset > 0 ? 0 : -1
    curPage = curStageIdx <= middleIdx ? 0
      : ::ceil((curStageIdx.tofloat() - stageIndexOffset)/ stagesPerPage).tointeger() + pageOffset
  }

  function goToPage(obj) {
    curPage = obj.to_page.tointeger()
    if (curPage == 0)
      stageIndexOffset = 0
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
    local view = { battlePassStage = [], skipButtonNavigation = ::show_console_buttons }
    local curPageOffset = stageIndexOffset > 0 ? -1 : 0
    local pageStartIndex = ::max((curPage + curPageOffset) * stagesPerPage  + stageIndexOffset, 0)
    local pageEndIndex = ::min(pageStartIndex + stagesPerPage, stagesList.len())
    local isChangesRewards = false
    local idxOnPage = 0
    for(local i=pageStartIndex; i < pageEndIndex; i++) {
      local stageView = getStageViewData(stagesList[i], idxOnPage)
      view.battlePassStage.append(stageView)
      isChangesRewards = isChangesRewards
        || !isEqualStageReward(curPageStagesList?[idxOnPage], stageView)
      idxOnPage++
    }

    curPageStagesList = view.battlePassStage
    local stagesObj = scene.findObject("battlePassStages")
    if (isChangesRewards || forceUpdate) {
      local data = ::handyman.renderCached("gui/battlePass/battlePassStage", view)
      guiScene.replaceContentFromText(stagesObj, data, data.len(), this)
    } else {
      foreach (idx, stage in view.battlePassStage) {
        local stageObj = stagesObj.getChild(idx)
        stageObj.stageStatus = stage.stageStatus
        stageObj.prizeStatus = stage.prizeStatus
      }
    }

    ::generatePaginator(scene.findObject("paginator_place"), this,
      curPage, ::ceil(stagesList.len().tofloat() / stagesPerPage) - 1, null, true /*show last page*/)
  }

  isEqualStageReward = @(curStage, newStage)
    curStage?.holderId == newStage.holderId
    && curStage?.stage == newStage.stage
    && curStage?.rewardId == newStage.rewardId

  function onReceiveRewards(obj) {
    local { holderId = null, stage = null } = obj
    if (holderId == null || stage == null)
      return

    local { lastRewardedStage = null } = unlockProgress.value?[holderId]
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

    showSceneBtn("btn_warbondsShop",
      ::g_warbonds.isShopAvailable() && !::isHandlerInScene(::gui_handlers.WarbondsShop))
    showSceneBtn("btn_battleTask", true)
    showSceneBtn("battle_tasks_info_nest", true)

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
    local countMainPrizes = mainPrizesValue.len()
    local mainPrizeImage = mainPrizeData?.mainPrizeImage
    if (countMainPrizes == 0 || (mainPrizeImage != null && mainPrizesValue.findvalue(
        @(v) v?.mainPrizeImage == mainPrizeImage) != null)) //main prize is already showed
      return

    mainPrizeData = clone mainPrizesValue[::math.rnd() % countMainPrizes]
    fillPromoBlock()
  }

  function fillPromoBlock() {
    local promoImage = mainPrizeData?.mainPrizeImage
    if (promoImage != null)
      scene.findObject("promo_img")["background-image"] = promoImage

    showSceneBtn("congrat_content", false)
    showSceneBtn("promo_preview", ::getAircraftByName(mainPrizeData?.mainPrizeId) != null)
  }

  function onMainPrizePreview(obj) {
    if (!isValid())
      return

    ::getAircraftByName(mainPrizeData?.mainPrizeId)?.doPreview()
  }

  function getHandlerRestoreData() {
    local data = {
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
    local view = {tabs = []}
    foreach (idx, sheetData in sheetsList)
    {
      view.tabs.append({
        tabName = sheetData.text
        navImagesText = ::get_navigation_images_text(idx, sheetsList.len())
        tabImage = sheetData?.tabImage
        tabImageParam = sheetData?.getTabImageParam()
      })
    }

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local sheetsListObj = scene.findObject("sheet_list")
    guiScene.replaceContentFromText(sheetsListObj, data, data.len(), this)
    sheetsListObj.setValue(0)
  }

  function onSheetChange(obj) {
    local curId = obj.getValue()
    foreach (idx, sheetData in sheetsList) {
      local isVisible = curId == idx
      showSceneBtn(sheetData.objId, isVisible)
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
    updateChallengesSheet(scene.findObject("challenges_sheet"), curSeasonChallenges.value)
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

    local view = { items = challenges.map(
      @(config) getChallengeView(config, { hoverAction = "onChallengeHover" })) }
    local challengesObj = scene.findObject("challenges_list")
    local data = ::handyman.renderCached("gui/unlocks/battleTasksItem", view)
    guiScene.replaceContentFromText(challengesObj, data, data.len(), this)

    local challengeId = curChallengeId
    local curChallengeIdx = challenges.findindex(@(challenge) challenge.id == challengeId) ?? 0
    isFillingChallengesList = true
    challengesObj.setValue(curChallengeIdx)
    isFillingChallengesList = false


    local mainChallengeOfSeason = challenges.findvalue(@(challenge) challenge.id == mainChallengeOfSeasonId.value)
    local hasMainChallenge = mainChallengeOfSeason != null
    local mainChallengeProgressObj = ::showBtn("main_challenge_progress", hasMainChallenge, obj)
    if (!hasMainChallenge)
      return

    local unlockConfig = ::build_conditions_config(mainChallengeOfSeason)
    ::build_unlock_desc(unlockConfig)

    local curValue = unlockConfig.curVal
    local maxValue = unlockConfig.maxVal

    local isBitMode = ::UnlockConditions.isBitModeType(unlockConfig.type)
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

    local listBoxObj = scene.findObject("challenges_list")
    if (!listBoxObj.isValid())
      return

    for (local i = 0; i < listBoxObj.childrenCount(); i++)
    {
      local challengeObj = listBoxObj.getChild(i)
      if(params.changedId == challengeObj?.id)
      {
        local cbObj = challengeObj.findObject("checkbox_favorites")
        if(cbObj.isValid())
          cbObj.setValue(params.value)
      }
    }
  }

  function onChallengeSelect(obj) {
    curChallengeId = getSelectedChildId(obj)
    if (::show_console_buttons && !isFillingChallengesList) {
      guiScene.applyPendingChanges(false)
      ::move_mouse_on_child_by_value(obj)
    }
  }
  function expandHoverChallenge()
  {
    local listBoxObj = scene.findObject("challenges_list")
    local total = listBoxObj.childrenCount()
    if (total == 0)
      return

    for (local i = 0; i < total; i++)
      if(hoverChallengeId == listBoxObj.getChild(i).id)
        listBoxObj.setValue(i)
  }

  function challengeToFavoritesByActivateItem(obj)
  {
    curChallengeId = getSelectedChildId(obj)
    local checkBoxObj = obj.findObject(curChallengeId)?.findObject("checkbox_favorites")
    if (checkBoxObj?.isValid())
      checkBoxObj.setValue(!checkBoxObj.getValue())
  }

  onChallengeDblClick = @(obj) curChallengeId == hoverChallengeId
    ? challengeToFavoritesByActivateItem(obj) : expandHoverChallenge()

  function getCurrentConfig() {
    local listBoxObj = scene.findObject("challenges_list")
    if (!::check_obj(listBoxObj))
      return null

    local unlockConfig = ::build_conditions_config(
      curSeasonChallenges.value?[listBoxObj.getValue()])
    ::build_unlock_desc(unlockConfig)
    return unlockConfig
  }

  function onViewBattleTaskRequirements() {
    local awardsList = []
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
    showSceneBtn("congrat_content", true)
    scene.findObject("promo_img")["background-image"] = "#ui/images/bp_bg.jpg?P1"
    showSceneBtn("promo_preview", false)
  }

  function onEventBattlePassPurchased(p) {
    needCalculateCurPage = true
    doWhenActiveOnce("congratulationBattlePassPurchased")
  }

  function updateButtons() {
    showSceneBtn("btn_wiki_link", ::has_feature("AllowExternalLink") && !::is_vendor_tencent())
  }
}

::gui_handlers.BattlePassWnd <- BattlePassWnd

local function openBattlePassWnd() {
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
