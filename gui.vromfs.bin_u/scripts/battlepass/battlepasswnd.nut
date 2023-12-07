//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { isHandlerInScene } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { ceil } = require("math")
let { rnd } = require("dagor.random")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_obj, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
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
let { userstatStats, isUserstatMissingData } = require("%scripts/userstat/userstat.nut")
let { getSelectedChild, findChildIndex, adjustWindowSize } = require("%sqDagui/daguiUtil.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { number_of_set_bits } = require("%sqstd/math.nut")
let { hasBattlePass } = require("%scripts/battlePass/unlocksRewardsState.nut")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")
let { isBitModeType } = require("%scripts/unlocks/unlocksConditions.nut")
let { unlockToFavorites } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { buildDateTimeStr } = require("%scripts/time.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getCurrentBattleTasks, isBattleTasksAvailable, setBattleTasksUpdateTimer
} = require("%scripts/unlocks/battleTasks.nut")
require("%scripts/promo/battlePassPromoHandler.nut") // Independed Modules
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

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

local BattlePassWnd = class (gui_handlers.BaseGuiHandlerWT) {
  wndType          = handlerType.MODAL
  sceneBlkName     = "%gui/battlePass/battlePassWnd.blk"

  currSheet = "battle_pass_sheet"
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
    this.updateButtons()
    this.calculateStageListSizeOnce()

    //init main sheet
    this.calculateCurPage()
    this.initStageUpdater()
    this.initBattlePassInfo()
    this.initBattleTasksInfo()

    //init challenges sheet
    this.initChallengesUpdater()

    this.initSheets()
  }

  function calculateStageListSizeOnce() {
    if (this.stagesPerPage >= 1)
      return

    let wndObj = this.scene.findObject("wnd_battlePass")
    let sizes = adjustWindowSize(wndObj, this.scene.findObject("battle_pass_sheet"),
      "@battlePassStageWidth", "@battlePassStageHeight", "@battlePassStageMargin",
      "@battlePassStageMargin", { windowSizeY = 0 })
    this.stagesPerPage = sizes.itemsCountX
    this.guiScene.applyPendingChanges(false)
    wndObj.size = $"{sizes.windowSize[0]}, {wndObj.getSize()[1]}"
  }

  function calculateCurPage(lineupType = -1) {
    this.stageIndexOffsetAddedByPages = {}
    let curStageIdx = this.getAvailableStageIdx(lineupType)
    let middleIdx = ceil(this.stagesPerPage.tofloat() / 2) - 1
    let doubleStagesCount = doubleWidthStagesIcon.value.reduce(@(res, value) res + (value < curStageIdx ? 1 : 0), 0)
    this.stageIndexOffset = curStageIdx <= middleIdx ? 0
      : (((curStageIdx + doubleStagesCount) % this.stagesPerPage) - middleIdx)
    let pageOffset = this.stageIndexOffset > 0 ? 0 : -1
    this.curPage = curStageIdx <= middleIdx ? 0
      : ceil((curStageIdx.tofloat() + doubleStagesCount - this.stageIndexOffset) / this.stagesPerPage).tointeger() + pageOffset
  }

  // lineupType: 0 - bp, 1 - free, -1 - any
  function getAvailableStageIdx(lineupType = -1) {
    return seasonStages.value.findvalue(function(stageData) {
      return ((lineupType == -1 || stageData.isFree.tointeger() == lineupType)
        && stageData.prizeStatus == "available") || stageData.stage >= seasonLevel.value
    })?.stage ?? 0
  }

  function goToPage(obj) {
    this.curPage = obj.to_page.tointeger()
    if (this.curPage == 0) {
      this.stageIndexOffset = 0
      this.stageIndexOffsetAddedByPages = {}
    }
    this.fillStagePage()
  }

  function fillStagePage(forceUpdate = false) {
    this.updateStagePage(this.scene.findObject("wnd_battlePass"), seasonStages.value, forceUpdate)
  }

  function updateStagePage(_obj, stagesList, forceUpdate = false) {
    if (this.getCurSheetObjId() != "battle_pass_sheet")
      return

    if (this.needCalculateCurPage) {
      this.calculateCurPage()
      this.needCalculateCurPage = false
    }
    let view = { battlePassStage = [], skipButtonNavigation = showConsoleButtons.value }
    let curPageOffset = this.stageIndexOffset > 0 ? -1 : 0
    local pageStartIndex = max((this.curPage + curPageOffset) * this.stagesPerPage  + this.stageIndexOffset, 0)
    let doubleStagesCount = doubleWidthStagesIcon.value.reduce(@(res, value) res + (value < (pageStartIndex - res) ? 1 : 0), 0)
    pageStartIndex = max(pageStartIndex - doubleStagesCount, 0)
    local pageEndIndex = min(pageStartIndex + this.stagesPerPage, stagesList.len())
    foreach (stage in doubleWidthStagesIcon.value) {
      if (stage == pageEndIndex) {
        pageStartIndex --
        pageEndIndex--
        if (this.curPage not in this.stageIndexOffsetAddedByPages) {
          this.stageIndexOffsetAddedByPages[this.curPage] <- true
          this.stageIndexOffset--
        }
        continue
      }

      if (stage <= pageStartIndex || stage > pageEndIndex)
        continue

      pageEndIndex--
    }

    local isChangesRewards = false
    local idxOnPage = 0
    for (local i = pageStartIndex; i < pageEndIndex; i++) {
      let stageView = getStageViewData(stagesList[i], idxOnPage)
      view.battlePassStage.append(stageView)
      isChangesRewards = isChangesRewards
        || !this.isEqualStageReward(this.curPageStagesList?[idxOnPage], stageView)
      idxOnPage++
    }

    this.curPageStagesList = view.battlePassStage
    let stagesObj = this.scene.findObject("battlePassStages")
    if (isChangesRewards || forceUpdate) {
      let data = handyman.renderCached("%gui/battlePass/battlePassStage.tpl", view)
      this.guiScene.replaceContentFromText(stagesObj, data, data.len(), this)
    }
    else {
      foreach (idx, stage in view.battlePassStage) {
        let stageObj = stagesObj.getChild(idx)
        stageObj.stageStatus = stage.stageStatus
        stageObj.prizeStatus = stage.prizeStatus
      }
    }

    ::generatePaginator(this.scene.findObject("paginator_place"), this, this.curPage,
      ceil((stagesList.len().tofloat() + doubleWidthStagesIcon.value.len()) / this.stagesPerPage)
      - 1, null, true /*show last page*/ )
  }

  isEqualStageReward = @(curStage, newStage)
    curStage?.holderId == newStage.holderId
    && curStage?.stage == newStage.stage
    && curStage?.rewardId == newStage.rewardId

  function onReceiveRewards(obj) {
    let { holderId = null, stage = null, prizeStatus = "", stageStatus = "" } = obj
    if (holderId == null || stage == null)
      return

    if (stageStatus == "future") {
      this.msgBox("futureStage", loc("battlePass/msgbox/bpLevelInsufficient"), [["ok"]], "ok")
      return
    }

    if (prizeStatus == "received") {
      this.msgBox("alreadyReceived", loc("battlePass/msgbox/alreadyReceived"), [["ok"]], "ok")
      return
    }

    let { lastRewardedStage = null } = unlockProgress.value?[holderId]

    if (lastRewardedStage == null
        || (lastRewardedStage + 1) != stage.tointeger()) {
      this.showLockedsMessage(obj?.isFree == "yes")
      return
    }

    receiveRewards(holderId)
  }

  function onEventItemsShopUpdate(_params) {
    this.fillStagePage(true) //force update stages because recived itemdefs for it
  }

  function initBattlePassInfo() {
    updateChallenges()
    foreach (objId, config in watchObjInfoConfig)
      this.scene.findObject(objId).setValue(stashBhvValueConfig(config))
  }

  function initBattleTasksInfo() {
    if (!isBattleTasksAvailable())
      return

    foreach (objId, config in watchObjInfoBattleTasksConfig)
      this.scene.findObject(objId).setValue(stashBhvValueConfig(config))

    this.showSceneBtn("btn_warbondsShop",
      ::g_warbonds.isShopAvailable() && !isHandlerInScene(gui_handlers.WarbondsShop))
    this.showSceneBtn("btn_battleTask", true)
    this.showSceneBtn("battle_tasks_info_nest", true)

    setBattleTasksUpdateTimer(
      getCurrentBattleTasks().findvalue(@(v) v._puType == "Easy"),
      this.scene.findObject("task_timer_nest"),
      { addText = $"{loc("mainmenu/btnBattleTasks")}{loc("ui/colon")}" })
  }

  function initStageUpdater() {
    let seasonEndDate = Computed(@() userstatStats.value?.stats.seasons["$endsAt"] ?? 0)
    let seasonTitleParams = Computed(@() {
      season = season.value
      endDate = seasonEndDate.value
    })

    this.scene.findObject("wnd_battlePass").setValue(stashBhvValueConfig([{
      watch = seasonStages
      updateFunc = Callback(@(obj, stagesList) this.updateStagePage(obj, stagesList), this)
    },
    {
      watch = seasonTitleParams
      updateFunc = @(obj, value)
        obj.findObject("wnd_title").setValue("{0} {1}".subst(
          loc("battlePass/name", { name = loc($"battlePass/seasonName/{value.season}") }),
          loc("battlePass/endDate", { time = buildDateTimeStr(value.endDate, false, false) })
        ))
    },
    {
      watch = seasonMainPrizesData
      updateFunc = Callback(@(_obj, mainPrizesValue) this.updateMainPrizeData(mainPrizesValue), this)
    }]))
  }

  function onEventBattlePassCacheInvalidate(_params) {
    updateChallenges()
  }

  onWarbondsShop = @() ::g_warbonds.openShop()
  onBattleTask = @() ::gui_start_battle_tasks_wnd()

  function updateMainPrizeData(mainPrizesValue) {
    let countMainPrizes = mainPrizesValue.len()
    let mainPrizeImage = this.mainPrizeData?.mainPrizeImage
    if (countMainPrizes == 0 || (mainPrizeImage != null && mainPrizesValue.findvalue(
        @(v) v?.mainPrizeImage == mainPrizeImage) != null)) //main prize is already showed
      return

    this.mainPrizeData = clone mainPrizesValue[rnd() % countMainPrizes]
    this.fillPromoBlock()
  }

  function fillPromoBlock() {
    let promoImage = this.mainPrizeData?.mainPrizeImage
    if (promoImage != null)
      this.scene.findObject("promo_img")["background-image"] = promoImage

    this.showSceneBtn("congrat_content", false)
    this.showSceneBtn("promo_preview", getAircraftByName(this.mainPrizeData?.mainPrizeId) != null)
  }

  function onMainPrizePreview(_obj) {
    if (!this.isValid())
      return

    getAircraftByName(this.mainPrizeData?.mainPrizeId)?.doPreview()
  }

  function getHandlerRestoreData() {
    let data = {
      openData = {
        mainPrizeData = this.mainPrizeData
      }
      stateData = {
        stageIndexOffset = this.stageIndexOffset
        curPage = this.curPage
      }
    }
    return data
  }

  function restoreHandler(stateData) {
    this.curPage = stateData.curPage
    this.stageIndexOffset = stateData.stageIndexOffset
    this.fillStagePage()
    this.fillPromoBlock()
  }

  function onEventBeforeStartShowroom(_p) {
    handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  }

  function onOpenBattlePassWnd() {
    openBattlePassShopWnd()
  }

  function initSheets() {
    let view = { tabs = [] }
    foreach (idx, sheetData in this.sheetsList) {
      view.tabs.append({
        tabName = sheetData.text
        navImagesText = ::get_navigation_images_text(idx, this.sheetsList.len())
        tabImage = sheetData?.tabImage
        tabImageParam = sheetData?.getTabImageParam()
      })
    }
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    let sheetsListObj = this.scene.findObject("sheet_list")
    this.guiScene.replaceContentFromText(sheetsListObj, data, data.len(), this)
    let showSheet = this.currSheet;
    let sheetIndex = this.sheetsList.findindex(@(s) s.objId == showSheet) ?? 0
    sheetsListObj.setValue(sheetIndex)
  }

  function onSheetChange(obj) {
    let curId = obj.getValue()
    foreach (idx, sheetData in this.sheetsList) {
      let isVisible = curId == idx
      this.showSceneBtn(sheetData.objId, isVisible)
      if (isVisible)
        this[sheetData.fillFunc]()
    }
  }

  function getCurSheetObjId() {
    return this.sheetsList?[this.scene.findObject("sheet_list").getValue()].objId
  }

  function fillBattlePassSheet() {
    this.scene.findObject("paginator_place").show(true)
    this.fillStagePage()
  }

  function fillChallengesSheet() {
    this.scene.findObject("paginator_place").show(false)

    let sheetObj = this.scene.findObject("challenges_sheet")
    this.updateChallengesSheet(sheetObj, curSeasonChallenges.value)

    let listObj = sheetObj.findObject("challenges_list")
    let idx = findChildIndex(listObj, @(i) i?.battleTaskStatus == "complete")
    if (idx == -1)
      return

    if (idx != listObj.getValue())
      listObj.setValue(idx)
    else
      this.onChallengeSelect(listObj)
  }

  function initChallengesUpdater() {
    this.scene.findObject("challenges_sheet").setValue(stashBhvValueConfig([{
      watch = curSeasonChallenges
      updateFunc = Callback(@(obj, challenges) this.updateChallengesSheet(obj, challenges), this)
    },
    {
      watch = activeUnlocks
      updateFunc = Callback(@(obj, _unlocks) this.updateChallengesSheet(obj, curSeasonChallenges.value), this)
    }]))
  }

  unlockToFavorites = @(obj) unlockToFavorites(obj)
  onChallengeHover = @(obj) this.hoverChallengeId = obj.id

  function updateChallengesSheet(obj, challenges) {
    if (this.getCurSheetObjId() != "challenges_sheet")
      return

    let view = { items = challenges.map(
      @(config) getChallengeView(config, { hoverAction = "onChallengeHover" })) }
    let challengesObj = this.scene.findObject("challenges_list")
    let data = handyman.renderCached("%gui/unlocks/battleTasksItem.tpl", view)
    this.guiScene.replaceContentFromText(challengesObj, data, data.len(), this)

    let challengeId = this.curChallengeId
    let curChallengeIdx = challenges.findindex(@(challenge) challenge.id == challengeId) ?? 0
    this.isFillingChallengesList = true
    challengesObj.setValue(curChallengeIdx)
    this.isFillingChallengesList = false


    let mainChallengeOfSeason = challenges.findvalue(@(challenge) challenge.id == mainChallengeOfSeasonId.value)
    let hasMainChallenge = mainChallengeOfSeason != null
    let mainChallengeProgressObj = showObjById("main_challenge_progress", hasMainChallenge, obj)
    if (!hasMainChallenge)
      return

    let unlockConfig = ::build_conditions_config(mainChallengeOfSeason)

    local curValue = unlockConfig.curVal
    local maxValue = unlockConfig.maxVal

    let isBitMode = isBitModeType(unlockConfig.type)
    if (isBitMode) {
      curValue = number_of_set_bits(curValue)
      maxValue = number_of_set_bits(maxValue)
    }

    mainChallengeProgressObj.findObject("progress_bar").setValue(
      (maxValue > 0 ? (curValue.tofloat() / maxValue) : 0) * 1000.0)
    mainChallengeProgressObj.findObject("progress_text").setValue(
      $"{curValue}{loc("weapons_types/short/separator")}{maxValue}")
  }

  getSelectedChildId = @(obj) getSelectedChild(obj)?.id ?? ""

  function onEventFavoriteUnlocksChanged(params) {
    if (this.getCurSheetObjId() != "challenges_sheet")
      return

    let listBoxObj = this.scene.findObject("challenges_list")
    if (!listBoxObj.isValid())
      return

    for (local i = 0; i < listBoxObj.childrenCount(); i++) {
      let challengeObj = listBoxObj.getChild(i)
      if (params.changedId == challengeObj?.id) {
        let cbObj = challengeObj.findObject("checkbox_favorites")
        if (cbObj.isValid())
          cbObj.setValue(params.value)
      }
    }
  }

  function onChallengeSelect(obj) {
    let childObj = getSelectedChild(obj)
    this.curChallengeId = childObj?.id ?? ""
    if (this.isFillingChallengesList || childObj == null)
      return

    this.guiScene.applyPendingChanges(false)
    childObj.scrollToView()
    move_mouse_on_obj(childObj)
  }

  function expandHoverChallenge() {
    let listBoxObj = this.scene.findObject("challenges_list")
    let total = listBoxObj.childrenCount()
    if (total == 0)
      return

    for (local i = 0; i < total; i++)
      if (this.hoverChallengeId == listBoxObj.getChild(i).id)
        listBoxObj.setValue(i)
  }

  function challengeToFavoritesByActivateItem(obj) {
    this.curChallengeId = this.getSelectedChildId(obj)
    let checkBoxObj = obj.findObject(this.curChallengeId)?.findObject("checkbox_favorites")
    if (checkBoxObj?.isValid())
      checkBoxObj.setValue(!checkBoxObj.getValue())
  }

  onChallengeDblClick = @(obj) this.curChallengeId == this.hoverChallengeId
    ? this.challengeToFavoritesByActivateItem(obj) : this.expandHoverChallenge()

  function getCurrentConfig() {
    let listBoxObj = this.scene.findObject("challenges_list")
    if (!checkObj(listBoxObj))
      return null

    return ::build_conditions_config(
      curSeasonChallenges.value?[listBoxObj.getValue()])
  }

  function onViewBattleTaskRequirements() {
    let awardsList = []
    foreach (id in this.getCurrentConfig()?.names ?? [])
      awardsList.append(::build_log_unlock_data(::build_conditions_config(getUnlockById(id))))

    showUnlocksGroupWnd(awardsList, loc("unlocks/requirements"))
  }

  onGetRewardForTask = @(obj) receiveRewards(obj?.task_id)

  function congratulationBattlePassPurchased() {
    this.scene.findObject("sheet_list").setValue(0)
    this.showSceneBtn("congrat_content", true)
    this.scene.findObject("promo_img")["background-image"] = "#ui/images/bp_bg?P1"
    this.showSceneBtn("promo_preview", false)
  }

  function onEventBattlePassPurchased(_p) {
    this.needCalculateCurPage = true
    this.doWhenActiveOnce("congratulationBattlePassPurchased")
  }

  function onStatusIconClick(obj) {
    this.showLockedsMessage(obj?.isFree == "yes")
  }

  function showLockedsMessage(isFree) {
    if (isFree || hasBattlePass.value) {
      let okBtnId = "#battlePass/msgbox/gotoPrize"
      this.msgBox("gotoPrize", loc("battlePass/msgbox/gotoPrizeTitle"), [
        [okBtnId, Callback(@() this.gotoPrize(isFree.tointeger()), this)],
        ["cancel"]], okBtnId)
    }
    else {
      let okBtnId = "#battlePass/btn_buy"
      this.msgBox("gotoBpShop", loc("battlePass/msgbox/gotoBpShopTitle"), [
        [okBtnId, openBattlePassShopWnd],
        ["cancel"]], okBtnId)
    }
  }

  function gotoPrize(lineupType) {
    this.calculateCurPage(lineupType)
    this.fillStagePage()
  }

  function updateButtons() {
    this.showSceneBtn("btn_wiki_link", hasFeature("AllowExternalLink"))
  }
}

gui_handlers.BattlePassWnd <- BattlePassWnd

let function openBattlePassWnd(params = {}) {
  if (isUserstatMissingData.value) {
    showInfoMsgBox(loc("userstat/missingDataMsg"), "userstat_missing_data_msgbox")
    return
  }

  handlersManager.loadHandler(BattlePassWnd, params)
}

addPromoAction("battle_pass", @(_handler, _params, _obj) openBattlePassWnd())

return {
  openBattlePassWnd
}
