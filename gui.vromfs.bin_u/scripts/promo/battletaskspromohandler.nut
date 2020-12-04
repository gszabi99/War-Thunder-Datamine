local { getStringWidthPx } = require("scripts/viewUtils/daguiFonts.nut")
local { openBattlePassWnd } = require("scripts/battlePass/battlePassWnd.nut")
local { seasonLvlWatchObj, easyDailyTaskProgressWatchObj,
  mediumDailyTaskProgressWatchObj, leftSpecialTasksBoughtCountWatchObj
} = require("scripts/battlePass/watchObjInfoConfig.nut")
local { stashBhvValueConfig } = require("sqDagui/guiBhv/guiBhvValueConfig.nut")

::dagui_propid.add_name_id("task_id")
::dagui_propid.add_name_id("difficultyGroup")

class ::gui_handlers.BattleTasksPromoHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM

  sceneBlkName = "gui/empty.blk"
  savePathBattleTasksDiff = "promo/battleTasksDiff"

  static function open(params)
  {
    ::handlersManager.loadHandler(::gui_handlers.BattleTasksPromoHandler, params)
  }

  function initScreen()
  {
    scene.setUserData(this)
    updateHandler()
  }

  function updateHandler()
  {
    local id = scene.id
    local difficultyGroupArray = []

    // 0) Prepare: Filter tasks array by available difficulties list
    local tasksArray = ::g_battle_tasks.getTasksArrayByIncreasingDifficulty()

    // 1) Search for task with available reward
    local reqTask = ::g_battle_tasks.getTaskWithAvailableAward(tasksArray)

    // No need to show some additional info on button
    // when battle task is complete and need to receive a reward
    local isTaskWithReward = reqTask != null

    local currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
    // 2) Search for task by selected gameMode
    if (!reqTask && currentGameModeId)
    {
      local curDifficultyGroup = ::load_local_account_settings(savePathBattleTasksDiff,
        ::g_battle_task_difficulty.getDefaultDifficultyGroup())
      local activeTasks = ::u.filter(::g_battle_tasks.filterTasksByGameModeId(tasksArray, currentGameModeId),
        @(task) !::g_battle_tasks.isTaskDone(task)
          && ::g_battle_tasks.isTaskActive(task)
          && (::g_battle_tasks.canGetReward(task) || !::g_battle_tasks.isTaskTimeExpired(task)))

              //get difficulty list
      difficultyGroupArray = getDifficultyRadioButtonsListByTasks(activeTasks,
        ::g_battle_tasks.getDifficultyTypeGroup(),
        curDifficultyGroup)
      if (difficultyGroupArray.len() == 1)
        curDifficultyGroup = difficultyGroupArray[0].difficultyGroup
      reqTask = ::u.search(activeTasks,
        @(task) (::g_battle_task_difficulty.getDifficultyTypeByTask(task).getDifficultyGroup() == curDifficultyGroup))
    }

    local showProgressBar = false
    local currentWarbond = null
    local promoView = ::u.copy(::getTblValue(id, ::g_promo.getConfig(), {}))
    local view = {}

    if (reqTask)
    {
      local config = ::build_conditions_config(reqTask)
      ::build_unlock_desc(config)

      local itemView = ::g_battle_tasks.generateItemView(config, { isPromo = true })
      itemView.canReroll = false
      view = ::u.tablesCombine(itemView, promoView, function(val1, val2) { return val1 != null? val1 : val2 })
      view.collapsedText <- ::g_promo.getCollapsedText(view, id)

      currentWarbond = ::g_warbonds.getCurrentWarbond()
      if (currentWarbond && currentWarbond.levelsArray.len())
      {
        showProgressBar = (isTaskWithReward || ::g_warbonds_view.needShowProgressBarInPromo)
          && ::g_battle_task_difficulty.getDifficultyTypeByTask(reqTask).canIncreaseShopLevel
        if (showProgressBar)
        {
          local curLevel = currentWarbond.getCurrentShopLevel()
          local nextLevel = curLevel + 1
          local markUp = ::g_warbonds_view.getProgressBoxMarkUp()
          if (currentWarbond.isMaxLevelReached())
          {
            nextLevel = curLevel
            curLevel -= 1
          }
          markUp += ::g_warbonds_view.getLevelItemMarkUp(currentWarbond, curLevel, "-50%w")
          markUp += ::g_warbonds_view.getLevelItemMarkUp(currentWarbond, nextLevel, "pw-50%w")
          view.warbondLevelPlace <- markUp
        }
        else if (!isTaskWithReward)
        {
          view.isConsoleMode <- ::show_console_buttons
          view.newItemsAvailable <- currentWarbond.needShowNewItemsNotifications()
          view.unseenIcon <- SEEN.WARBONDS_SHOP
        }
      }
    }
    else
    {
      promoView.id <- id
      view = ::g_battle_tasks.generateItemView(promoView, { isPromo = true })
      view.collapsedText <- ::g_promo.getCollapsedText(promoView, id)
      view.refreshTimer <- true
    }

    if (!(view.needShowProgressBar ?? false) && view.needShowProgressValue)
    {
      local progressValueText = ::loc("ui/parentheses/space",
        {text = "".concat(view.progressValue, "/", view.progressMaxValue)})
      view.collapsedText = $"{view.collapsedText}{progressValueText}"
    }
    local maxTextWidth = ::to_pixels("".concat("1@arrowButtonWidth-1@mIco-2@blockInterval",
      view.taskStatus != null ? "-1@modStatusHeight" : "",
      view.newIconWidget != null ? "-1@arrowButtonHeight" : ""))
    view.collapsedIcon <- ::g_promo.getCollapsedIcon(view, id)
    local iconSize = getStringWidthPx(view.collapsedIcon, "fontNormal", guiScene) + ::to_pixels("1@blockInterval")
    if (getStringWidthPx(view.collapsedText, "fontNormal", guiScene) > maxTextWidth - iconSize)
      view.shortInfoBlockWidth <- ::to_pixels("1@arrowButtonWidth-1@blockInterval")
    view.hasMarginCollapsedIcon <- view.collapsedText != "" && view.taskDifficultyImage != ""
    view.hasCollapsedText <- view.collapsedText != ""
    local taskHeaderCondition = view?.taskHeaderCondition ?? ""
    if (taskHeaderCondition != "")
      view.title = $"{view.title} {taskHeaderCondition}"
    if (getStringWidthPx(view.title, "fontNormal", guiScene) > maxTextWidth)
      view.headerWidth <- maxTextWidth
    view.performActionId <- ::g_promo.getActionParamsKey(id)
    view.taskId <- ::getTblValue("id", reqTask)
    view.action <- ::g_promo.PERFORM_ACTON_NAME


    view.isShowRadioButtons <- (difficultyGroupArray.len() > 1 && ::has_feature("PromoBattleTasksRadioButtons"))
    view.radioButtons <- difficultyGroupArray
    view.isShowNameInHeader <- true
    view.otherTasksNumText <- view.otherTasksNum > 0 ? "#mainmenu/battleTasks/OtherTasksCount" : ""
    if (::has_feature("BattlePass")) {
      scene.isBattlePass = "yes"
      view.headerAction <- "showBattlePassWnd"
      view.seasonLvlValue <- stashBhvValueConfig([{
        watch = seasonLvlWatchObj.watch
        updateFunc = seasonLvlWatchObj.updateFunc
      }])
      view.isShowNameInHeader = false
      local isEmptyTask = view.taskId == null
      if (isEmptyTask) {
        view.title = ""
        view.isEmptyTask <- isEmptyTask
        view.showAsUsualPromoButton = false
        view.easyDailyTaskProgressValue <- stashBhvValueConfig([{
          watch = easyDailyTaskProgressWatchObj.watch
          updateFunc = easyDailyTaskProgressWatchObj.updateFunc
        }])
        view.mediumDailyTaskProgressValue <- stashBhvValueConfig([{
          watch = mediumDailyTaskProgressWatchObj.watch
          updateFunc = mediumDailyTaskProgressWatchObj.updateFunc
        }])
        if (::g_battle_tasks.canActivateHardTasks()) {
          view.leftSpecialTasksBoughtCountValue <- stashBhvValueConfig([{
            watch = leftSpecialTasksBoughtCountWatchObj.watch
            updateFunc = leftSpecialTasksBoughtCountWatchObj.updateFunc
          }])
          view.newItemsAvailable <- leftSpecialTasksBoughtCountWatchObj.watch.value > 0
        }
      }
    }

    local data = ::handyman.renderCached("gui/promo/promoBattleTasks",
      { items = [view], collapsedAction = ::g_promo.PERFORM_ACTON_NAME})
    guiScene.replaceContentFromText(scene, data, data.len(), this)

    ::g_battle_tasks.setUpdateTimer(reqTask, scene)
    if (showProgressBar && currentWarbond)
      ::g_warbonds_view.updateProgressBar(currentWarbond, scene, true)
  }

  function onGetRewardForTask(obj)
  {
    ::g_battle_tasks.requestRewardForTask(obj?.task_id)
  }

  function onWarbondsShop(obj)
  {
    ::g_warbonds.openShop()
  }

  function onSelectDifficultyBattleTasks(obj)
  {
    local index = obj.getValue()
    if (index < 0 || index >= obj.childrenCount())
      return

    local difficultyGroup = obj.getChild(index)?.difficultyGroup

    if (!difficultyGroup)
      return

    ::save_local_account_settings(savePathBattleTasksDiff, difficultyGroup)

    guiScene.performDelayed(this, function()
    {
      updateHandler()
    })
  }

  function getDifficultyRadioButtonsListByTasks(tasksArray, difficultyTypeArray, curDifficultyGroup)
  {
    local result = []
    foreach(btDiffType in difficultyTypeArray)
    {
      local difficultyGroup = btDiffType.getDifficultyGroup()
      local tasksByDiff = ::u.search(tasksArray,
          @(task) (::g_battle_task_difficulty.getDifficultyTypeByTask(task) == btDiffType))

      if (!tasksByDiff)
        continue

      result.append({ radioButtonImage = ::g_battle_tasks.getDifficultyImage(tasksByDiff)
        difficultyGroup = difficultyGroup
        difficultyLocName = btDiffType.getLocName()
        selected = (curDifficultyGroup == difficultyGroup) })
    }
    return result
  }

  function performAction(obj) { ::g_promo.performAction(this, obj) }
  function performActionCollapsed(obj)
  {
    local buttonObj = obj.getParent()
    performAction(buttonObj.findObject(::g_promo.getActionParamsKey(buttonObj.id)))
  }
  function onToggleItem(obj) { ::g_promo.toggleItem(obj) }

  onEventNewBattleTasksChanged                = @(p) updateHandler()
  onEventBattleTasksFinishedUpdate            = @(p) updateHandler()
  onEventBattleTasksTimeExpired               = @(p) updateHandler()
  onEventCurrentGameModeIdChanged             = @(p) updateHandler()
  onEventWarbondShopMarkSeenLevel             = @(p) updateHandler()
  onEventWarbondViewShowProgressBarFlagUpdate = @(p) updateHandler()

  function showBattlePassWnd() {
    if (!::has_feature("BattlePass"))
      return

    openBattlePassWnd()
  }
}
