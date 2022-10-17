from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let time = require("%scripts/time.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")

::gui_start_battle_tasks_wnd <- function gui_start_battle_tasks_wnd(taskId = null, tabType = null)
{
  if (!::g_battle_tasks.isAvailableForUser())
    return ::showInfoMsgBox(loc("msgbox/notAvailbleYet"))

  ::gui_start_modal_wnd(::gui_handlers.BattleTasksWnd, {
    currentTaskId = taskId,
    currentTabType = tabType
  })
}

global enum BattleTasksWndTab {
  BATTLE_TASKS,
  BATTLE_TASKS_HARD,
  HISTORY
}

::gui_handlers.BattleTasksWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/unlocks/battleTasks"
  sceneTplDescriptionName = "%gui/unlocks/battleTasksDescription"
  battleTaskItemTpl = "%gui/unlocks/battleTasksItem"

  currentTasksArray = null

  configsArrayByTabType = {
    [BattleTasksWndTab.BATTLE_TASKS] = null,
    [BattleTasksWndTab.BATTLE_TASKS_HARD] = null,
  }

  difficultiesByTabType = {
    [BattleTasksWndTab.BATTLE_TASKS] = [::g_battle_task_difficulty.EASY, ::g_battle_task_difficulty.MEDIUM],
    [BattleTasksWndTab.BATTLE_TASKS_HARD] = [::g_battle_task_difficulty.HARD]
  }

  newIconWidgetByTaskId = null

  finishedTaskIdx = -1
  usingDifficulties = null

  currentTaskId = null
  currentTabType = null

  userglogFinishedTasksFilter = {
    show = [EULT_NEW_UNLOCK]
    checkFunc = function(userlog) { return ::g_battle_tasks.isBattleTask(userlog.body.unlockId) }
  }

  tabsList = [
    {
      tabType = BattleTasksWndTab.BATTLE_TASKS
      isVisible = @() hasFeature("BattleTasks")
      text = "#mainmenu/btnBattleTasks"
      noTasksLocId = "mainmenu/battleTasks/noTasks"
      fillFunc = "fillBattleTasksList"
    },
    {
      tabType = BattleTasksWndTab.BATTLE_TASKS_HARD
      isVisible = @() hasFeature("BattleTasksHard")
      text = "#mainmenu/btnBattleTasksHard"
      noTasksLocId = "mainmenu/battleTasks/noSpecialTasks"
      fillFunc = "fillBattleTasksList"
    },
    {
      tabType = BattleTasksWndTab.HISTORY
      text = "#mainmenu/battleTasks/history"
      fillFunc = "fillTasksHistory"
    }
  ]

  function initScreen()
  {
    updateBattleTasksData()
    updateButtons()

    let tabType = currentTabType? currentTabType : findTabSheetByTaskId()
    getTabsListObj().setValue(tabType)

    updateWarbondsBalance()
  }

  function findTabSheetByTaskId()
  {
    if (currentTaskId)
      foreach (tabType, tasksArray in configsArrayByTabType)
      {
        let task = tasksArray && ::u.search(tasksArray, function(task) { return currentTaskId == task.id }.bindenv(this) )
        if (!task)
          continue

        let tab = ::u.search(tabsList, @(tabData) tabData.tabType == tabType)
        if (!("isVisible" in tab) || tab.isVisible())
          return tabType
        break
      }

    return BattleTasksWndTab.BATTLE_TASKS
  }

  function getSceneTplView()
  {
    return {
      radiobuttons = getRadioButtonsView()
      tabs = getTabsView()
      showAllTasksValue = ::g_battle_tasks.showAllTasksValue? "yes" : "no"
      unseenIcon = SEEN.WARBONDS_SHOP
    }
  }

  function getSceneTplContainerObj()
  {
    return scene.findObject("root-box")
  }

  function buildBattleTasksArray(tabType)
  {
    let filteredByDiffArray = []
    local haveRewards = false
    foreach(t in difficultiesByTabType[tabType])
    {
      // 0) Prepare: Receive tasks list by available battle tasks difficulty
      let arr = ::g_battle_task_difficulty.withdrawTasksArrayByDifficulty(t, currentTasksArray)
      if (arr.len() == 0)
        continue

      // 1) Search for task with reward, to put it first in list
      let taskWithReward = ::g_battle_tasks.getTaskWithAvailableAward(arr)
      if (!::g_battle_tasks.showAllTasksValue && !::u.isEmpty(taskWithReward))
      {
        filteredByDiffArray.append(taskWithReward)
        haveRewards = true
      }
      else if (::g_battle_task_difficulty.canPlayerInteractWithDifficulty(t, arr, ::g_battle_tasks.showAllTasksValue))
        filteredByDiffArray.extend(arr)
    }

    local resultArray = filteredByDiffArray
    if (!haveRewards && filteredByDiffArray.len())
    {
      local gameModeDifficulty = null
      if (tabType != BattleTasksWndTab.BATTLE_TASKS_HARD)
      {
        let obj = getDifficultySwitchObj()
        let val = obj.getValue()
        let diffCode = getTblValue(val, usingDifficulties, DIFFICULTY_ARCADE)
        gameModeDifficulty = ::g_difficulty.getDifficultyByDiffCode(diffCode)
      }

      let filteredByModeArray = ::g_battle_tasks.getTasksArrayByDifficulty(filteredByDiffArray, gameModeDifficulty)

      resultArray = filteredByModeArray.filter(@(task) (
          ::g_battle_tasks.showAllTasksValue
          || ::g_battle_tasks.isTaskDone(task)
          || ::g_battle_tasks.isTaskActive(task)
        )
      )
    }

    configsArrayByTabType[tabType] = resultArray.map(@(task) ::g_battle_tasks.generateUnlockConfigByTask(task))
  }

  function fillBattleTasksList()
  {
    let listBoxObj = getConfigsListObj()
    if (!checkObj(listBoxObj))
      return

    let view = {items = []}
    foreach (idx, config in configsArrayByTabType[currentTabType])
    {
      view.items.append(::g_battle_tasks.generateItemView(config))
      if (::g_battle_tasks.canGetReward(::g_battle_tasks.getTaskById(config)))
        finishedTaskIdx = finishedTaskIdx < 0? idx : finishedTaskIdx
      else if (finishedTaskIdx < 0 && config.id == currentTaskId)
        finishedTaskIdx = idx
    }

    updateNoTasksText(view.items)
    let data = ::handyman.renderCached(battleTaskItemTpl, view)
    guiScene.replaceContentFromText(listBoxObj, data, data.len(), this)

    foreach(config in configsArrayByTabType[currentTabType])
    {
      let task = config.originTask
      ::g_battle_tasks.setUpdateTimer(task, scene.findObject(task.id))
    }

    updateWidgetsVisibility()
    if (finishedTaskIdx < 0 || finishedTaskIdx >= configsArrayByTabType[currentTabType].len())
      finishedTaskIdx = 0
    if (finishedTaskIdx < listBoxObj.childrenCount())
      listBoxObj.setValue(finishedTaskIdx)

    let needShowWarbondProgress = !hasFeature("BattlePass")
    let obj = scene.findObject("warbond_shop_progress_block")
    let curWb = ::g_warbonds.getCurrentWarbond()
    if (needShowWarbondProgress && currentTabType == BattleTasksWndTab.BATTLE_TASKS)
      ::g_warbonds_view.createProgressBox(curWb, obj, this)
    else if (currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD)
      ::g_warbonds_view.createSpecialMedalsProgress(curWb, obj, this, !::g_battle_tasks.hasInCompleteHardTask.value)
  }

  function updateNoTasksText(items = [])
  {
    let tabsListObj = getTabsListObj()
    let tabData = getSelectedTabData(tabsListObj)

    local text = ""
    if (items.len() == 0 && "noTasksLocId" in tabData)
      text = loc(tabData.noTasksLocId)
    scene.findObject("battle_tasks_no_tasks_text").setValue(text)
  }

  function updateWidgetsVisibility()
  {
    let listBoxObj = getConfigsListObj()
    if (!checkObj(listBoxObj))
      return

    foreach(taskId, w in newIconWidgetByTaskId)
    {
      let newIconWidgetContainer = listBoxObj.findObject("new_icon_widget_" + taskId)
      if (!checkObj(newIconWidgetContainer))
        continue

      let widget = ::NewIconWidget(guiScene, newIconWidgetContainer)
      newIconWidgetByTaskId[taskId] = widget
      widget.setWidgetVisible(::g_battle_tasks.isBattleTaskNew(taskId))
    }
  }

  function updateBattleTasksData()
  {
    currentTasksArray = ::g_battle_tasks.getTasksArray()
    newIconWidgetByTaskId = ::g_battle_tasks.getWidgetsTable()
    buildBattleTasksArray(BattleTasksWndTab.BATTLE_TASKS)
    buildBattleTasksArray(BattleTasksWndTab.BATTLE_TASKS_HARD)
  }

  function fillTasksHistory()
  {
    let finishedTasksUserlogsArray = ::getUserLogsList(userglogFinishedTasksFilter)

    let view = {
      doneTasksTable = {}
    }

    if (finishedTasksUserlogsArray.len())
    {
      view.doneTasksTable.rows <- ""
      view.doneTasksTable.rows += ::buildTableRow("tr_header",
               [{textType = "textareaNoTab", text = loc("unlocks/battletask"), tdalign = "left", width = "65%pw"},
               {textType = "textarea", text = loc("debriefing/sessionTime"), tdalign = "right", width = "35%pw"}])

      foreach(idx, uLog in finishedTasksUserlogsArray)
      {
        let config = ::build_log_unlock_data(uLog)
        local text = config.name
        if (!::u.isEmpty(config.rewardText))
          text += loc("ui/parentheses/space", {text = config.rewardText})
        text = colorize("activeTextColor", text)

        let timeStr = time.buildDateTimeStr(uLog.time, true)
        let rowData = [{textType = "textareaNoTab", text = text, tooltip = text, width = "65%pw", textRawParam = "pare-text:t='yes'; width:t='pw'; max-height:t='ph'"},
                         {textType = "textarea", text = timeStr, tooltip = timeStr, tdalign = "right", width = "35%pw"}]

        view.doneTasksTable.rows += ::buildTableRow("tr_" + idx, rowData, idx % 2 == 0)
      }
    }

    let data = ::handyman.renderCached(sceneTplDescriptionName, view)
    guiScene.replaceContentFromText(scene.findObject("tasks_history_frame"), data, data.len(), this)
  }

  function onChangeTab(obj)
  {
    if (!checkObj(obj))
      return

    ::g_sound.stop()
    let curTabData = getSelectedTabData(obj)
    currentTabType = curTabData.tabType
    changeFrameVisibility()
    updateTabButtons()

    if (curTabData.fillFunc in this)
      this[curTabData.fillFunc]()

    guiScene.applyPendingChanges(false)
  }

  function getSelectedTabData(listObj)
  {
    local val = 0
    if (checkObj(listObj))
      val = listObj.getValue()

    return val in tabsList? tabsList[val] : {}
  }

  function changeFrameVisibility()
  {
    this.showSceneBtn("tasks_list_frame", currentTabType != BattleTasksWndTab.HISTORY)
    this.showSceneBtn("tasks_history_frame", currentTabType == BattleTasksWndTab.HISTORY)
  }

  function onEventBattleTasksFinishedUpdate(params)
  {
    updateBattleTasksData()
    onChangeTab(getTabsListObj())
  }

  function onEventBattleTasksTimeExpired(params)
  {
    onChangeTab(getTabsListObj())
  }

  function onShowAllTasks(obj)
  {
    ::broadcastEvent("BattleTasksShowAll", {showAllTasksValue = obj.getValue()})
  }

  function notifyUpdate()
  {
    ::broadcastEvent("BattleTasksIncomeUpdate")
  }

  function onTasksListDblClick(obj)
  {
    let value = obj.getValue()
    let config = getConfigByValue(value)
    let task = ::g_battle_tasks.getTaskById(config)
    if (!task)
      return

    if (::g_battle_tasks.canGetReward(task))
      return ::g_battle_tasks.requestRewardForTask(task.id)

    let isActive = ::g_battle_tasks.isTaskActive(task)
    if (isActive && ::g_battle_tasks.canCancelTask(task))
      return onCancel(config)

    if (!isActive)
      return onActivate()
  }

  function onSelectTask(obj)
  {
    let val = obj.getValue()
    finishedTaskIdx = val

    ::g_sound.stop()

    let config = getConfigByValue(val)
    preparePlaybackForConfig(config)

    updateButtons(config)
    hideTaskWidget(config)

    guiScene.applyPendingChanges(false)
    ::move_mouse_on_obj(obj.getChild(val))
  }

  function preparePlaybackForConfig(config, useDefault = false)
  {
    if (getTblValue("playback", config))
      ::g_sound.preparePlayback(::g_battle_tasks.getPlaybackPath(config.playback, useDefault), config.id)
  }

  function hideTaskWidget(config)
  {
    if (!config)
      return

    let uid = config.id
    let widget = getTblValue(uid, newIconWidgetByTaskId)
    if (!widget)
      return

    widget.setWidgetVisible(false)
    ::g_battle_tasks.markTaskSeen(uid)
  }

  function updateButtons(config = null)
  {
    let task = ::g_battle_tasks.getTaskById(config)
    let isBattleTask = ::g_battle_tasks.isBattleTask(task)

    let isActive = ::g_battle_tasks.isTaskActive(task)
    let isDone = ::g_battle_tasks.isTaskDone(task)
    let canCancel = isBattleTask && ::g_battle_tasks.canCancelTask(task)
    let canGetReward = isBattleTask && ::g_battle_tasks.canGetReward(task)
    let isController = ::g_battle_tasks.isController(task)
    let showActivateButton = !isActive && ::g_battle_tasks.canActivateTask(task)

    let showCancelButton = isActive && canCancel && !canGetReward && !isController

    ::showBtnTable(scene, {
      btn_activate = showActivateButton
      btn_cancel = showCancelButton
      btn_warbonds_shop = ::g_warbonds.isShopButtonVisible() && !::isHandlerInScene(::gui_handlers.WarbondsShop)
    })

    let showRerollButton = isBattleTask && !isDone && !canGetReward && !::u.isEmpty(::g_battle_tasks.rerollCost)
    let taskObj = getCurrentTaskObj()
    if (!checkObj(taskObj))
      return

    ::showBtn("btn_reroll", showRerollButton, taskObj)
    ::showBtn("btn_recieve_reward", canGetReward, taskObj)
    if (showRerollButton)
      placePriceTextToButton(taskObj, "btn_reroll", loc("mainmenu/battleTasks/reroll"), ::g_battle_tasks.rerollCost)
    this.showSceneBtn("btn_requirements_list", ::show_console_buttons && getTblValue("names", config, []).len() != 0)

    let id = config?.id ?? ""
    ::enableBtnTable(taskObj, {[getConfigPlaybackButtonId(id)] = ::g_sound.canPlay(id)})
  }

  function updateTabButtons()
  {
    this.showSceneBtn("show_all_tasks", hasFeature("ShowAllBattleTasks") && currentTabType != BattleTasksWndTab.HISTORY)
    this.showSceneBtn("battle_tasks_modes_radiobuttons", currentTabType == BattleTasksWndTab.BATTLE_TASKS)
    this.showSceneBtn("warbond_shop_progress_block", isBattleTasksTab())
    this.showSceneBtn("progress_box_place", currentTabType == BattleTasksWndTab.BATTLE_TASKS
      && !hasFeature("BattlePass"))
    this.showSceneBtn("medal_icon", currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD)
    updateProgressText()
  }

  function isBattleTasksTab()
  {
    return currentTabType == BattleTasksWndTab.BATTLE_TASKS
    || currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD
  }

  function updateProgressText()
  {
    let textObj = scene.findObject("progress_text")
    if (!checkObj(textObj))
      return

    let curWb = ::g_warbonds.getCurrentWarbond()
    local text = ""
    let tooltip = ""
    if (curWb && currentTabType == BattleTasksWndTab.BATTLE_TASKS && !hasFeature("BattlePass"))
      text = ::g_warbonds_view.getCurrentShopProgressBarText(curWb)

    textObj.setValue(text)
    textObj.tooltip = tooltip
  }

  function getCurrentTaskObj()
  {
    let listObj = getConfigsListObj()
    if (!checkObj(listObj))
      return null

    let value = listObj.getValue()
    if (value < 0 || value >= listObj.childrenCount())
      return null

    return listObj.getChild(value)
  }

  function getRadioButtonsView()
  {
    usingDifficulties = []
    let tplView = []
    let curMode = ::game_mode_manager.getCurrentGameMode()
    let selDiff = ::g_difficulty.getDifficultyByDiffCode(curMode ? curMode.diffCode : DIFFICULTY_ARCADE)

    foreach(idx, diff in ::g_difficulty.types)
    {
      if (diff.diffCode < 0 || !diff.isAvailable(GM_DOMINATION))
        continue

      let arr = ::g_battle_tasks.getTasksArrayByDifficulty(::g_battle_tasks.getTasksArray(), diff)
      if (arr.len() == 0)
        continue

      tplView.append({
        radiobuttonName = diff.getLocName(),
        selected = selDiff == diff
      })
      usingDifficulties.append(diff.diffCode)
    }

    if (tplView.len() && "diffCode" in selDiff && usingDifficulties.indexof(selDiff.diffCode) == null)
      tplView.top().selected = true

    return tplView
  }

  function getTabsView()
  {
    let view = {tabs = []}
    foreach (idx, tabData in tabsList)
    {
      view.tabs.append({
        tabName = tabData.text
        navImagesText = ::get_navigation_images_text(idx, tabsList.len())
        hidden = ("isVisible" in tabData) && !tabData.isVisible()
      })
    }

    return ::handyman.renderCached("%gui/frameHeaderTabs", view)
  }

  function onChangeShowMode(obj)
  {
    notifyUpdate()
  }

  function getCurrentSelectedTask()
  {
    let config = getCurrentConfig()
    return ::g_battle_tasks.getTaskById(config)
  }

  function getConfigByValue(value)
  {
    let checkArray = getTblValue(currentTabType, configsArrayByTabType, [])
    return getTblValue(value, checkArray)
  }

  function onGetRewardForTask(obj)
  {
    ::g_battle_tasks.requestRewardForTask(obj?.task_id)
  }

  function madeTaskAction(mode)
  {
    let task = getCurrentSelectedTask()
    if (!getTblValue("id", task))
      return

    let blk = ::DataBlock()
    blk.setStr("mode", mode)
    blk.setStr("unlockName", task.id)

    let taskId = ::char_send_blk("cln_management_personal_unlocks", blk)
    ::g_tasker.addTask(taskId, {showProgressBox = true}, notifyUpdate)
  }

  function onTaskReroll(obj)
  {
    let taskId = obj?.task_id
    if (!taskId)
      return

    let task = ::g_battle_tasks.getTaskById(taskId)
    if (!task)
      return

    if (::check_balance_msgBox(::g_battle_tasks.rerollCost))
      this.msgBox("reroll_perform_action",
             loc("msgbox/battleTasks/reroll",
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

  function onActivate()
  {
    let task = getCurrentSelectedTask()
    if (!::g_battle_tasks.canActivateTask(task))
      return

    madeTaskAction("accept")
  }

  function onCancel(config)
  {
    if (getTblValue("curVal", config, 0) <= 0)
      return madeTaskAction("cancel")

    this.msgBox("battletasks_confirm_cancel", loc("msgbox/battleTasks/clarifyCancel"),
    [["ok", function(){ madeTaskAction("cancel") }],
     ["cancel", function() {}]], "cancel")
  }

  function getConfigPlaybackButtonId(btnId)
  {
    return btnId + "_sound"
  }

  function getConfigsListObj()
  {
    if (checkObj(scene))
      return scene.findObject("tasks_list")
    return null
  }

  function getDifficultySwitchObj()
  {
    return scene.findObject("battle_tasks_modes_radiobuttons")
  }

  function goBack()
  {
    ::g_battle_tasks.markAllTasksSeen()
    ::g_battle_tasks.saveSeenTasksData()
    ::g_sound.stop()
    base.goBack()
  }

  function updateWarbondsBalance()
  {
    if (!hasFeature("Warbonds"))
      return

    let warbondsObj = scene.findObject("warbonds_balance")
    warbondsObj.setValue(::g_warbonds.getBalanceText())
    warbondsObj.tooltip = loc("warbonds/maxAmount", {warbonds = ::g_warbonds.getLimit()})
  }

  function onEventProfileUpdated(p)
  {
    updateWarbondsBalance()
  }

  function onEventPlaybackDownloaded(p)
  {
    if (!checkObj(scene))
      return

    let pbObj = scene.findObject(getConfigPlaybackButtonId(p.id))
    if (!checkObj(pbObj))
      return

    pbObj.enable(p.success)
    pbObj.downloading = p.success? "no" : "yes"

    if (p.success)
      return

    let config = getConfigByValue(finishedTaskIdx)
    if (config)
      preparePlaybackForConfig(config, true)
  }

  function onEventFinishedPlayback(p)
  {
    let config = getConfigByValue(finishedTaskIdx)
    if (!config)
      return

    let pbObjId = getConfigPlaybackButtonId(config.id)
    let pbObj = scene.findObject(pbObjId)
    if (checkObj(pbObj))
      pbObj.setValue(false)
  }

  function onWarbondsShop()
  {
    ::g_warbonds.openShop()
  }

  function getCurrentConfig()
  {
    let listBoxObj = getConfigsListObj()
    if (!checkObj(listBoxObj))
      return null

    return getConfigByValue(listBoxObj.getValue())
  }

  function onViewBattleTaskRequirements()
  {
    let config = getCurrentConfig()
    if (getTblValue("names", config, []).len() == 0)
      return

    let awardsList = []
    foreach(id in config.names)
      awardsList.append(::build_log_unlock_data(::build_conditions_config(::g_unlocks.getUnlockById(id))))

    showUnlocksGroupWnd([{
      unlocksList = awardsList
      titleText = loc("unlocks/requirements")
    }])
  }

  function switchPlaybackMode(obj)
  {
    let config = getConfigByValue(finishedTaskIdx)
    if (!config)
      return

    if (!obj.getValue())
      ::g_sound.stop()
    else
      ::g_sound.play(config.id)
  }

  function getTabsListObj()
  {
    return scene.findObject("tasks_sheet_list")
  }

  function onDestroy()
  {
    ::g_sound.stop()
  }
}

let function openBattleTasksWndFromPromo(params = [], obj = null) {
  let taskId = obj?.task_id ?? params?[0]
  ::g_warbonds_view.resetShowProgressBarFlag()
  ::gui_start_battle_tasks_wnd(taskId)
}

addPromoAction("battle_tasks", @(handler, params, obj) openBattleTasksWndFromPromo(params, obj))
