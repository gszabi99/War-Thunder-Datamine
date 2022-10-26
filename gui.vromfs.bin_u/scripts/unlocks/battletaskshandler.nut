from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

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
  sceneTplName = "%gui/unlocks/battleTasks.tpl"
  sceneTplDescriptionName = "%gui/unlocks/battleTasksDescription.tpl"
  battleTaskItemTpl = "%gui/unlocks/battleTasksItem.tpl"

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
    this.updateBattleTasksData()
    this.updateButtons()

    let tabType = this.currentTabType? this.currentTabType : this.findTabSheetByTaskId()
    this.getTabsListObj().setValue(tabType)

    this.updateWarbondsBalance()
  }

  function findTabSheetByTaskId()
  {
    if (this.currentTaskId)
      foreach (tabType, tasksArray in this.configsArrayByTabType)
      {
        let task = tasksArray && ::u.search(tasksArray, function(task) { return this.currentTaskId == task.id }.bindenv(this) )
        if (!task)
          continue

        let tab = ::u.search(this.tabsList, @(tabData) tabData.tabType == tabType)
        if (!("isVisible" in tab) || tab.isVisible())
          return tabType
        break
      }

    return BattleTasksWndTab.BATTLE_TASKS
  }

  function getSceneTplView()
  {
    return {
      radiobuttons = this.getRadioButtonsView()
      tabs = this.getTabsView()
      showAllTasksValue = ::g_battle_tasks.showAllTasksValue? "yes" : "no"
      unseenIcon = SEEN.WARBONDS_SHOP
    }
  }

  function getSceneTplContainerObj()
  {
    return this.scene.findObject("root-box")
  }

  function buildBattleTasksArray(tabType)
  {
    let filteredByDiffArray = []
    local haveRewards = false
    foreach(t in this.difficultiesByTabType[tabType])
    {
      // 0) Prepare: Receive tasks list by available battle tasks difficulty
      let arr = ::g_battle_task_difficulty.withdrawTasksArrayByDifficulty(t, this.currentTasksArray)
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
        let obj = this.getDifficultySwitchObj()
        let val = obj.getValue()
        let diffCode = getTblValue(val, this.usingDifficulties, DIFFICULTY_ARCADE)
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

    this.configsArrayByTabType[tabType] = resultArray.map(@(task) ::g_battle_tasks.generateUnlockConfigByTask(task))
  }

  function fillBattleTasksList()
  {
    let listBoxObj = this.getConfigsListObj()
    if (!checkObj(listBoxObj))
      return

    let view = {items = []}
    foreach (idx, config in this.configsArrayByTabType[this.currentTabType])
    {
      view.items.append(::g_battle_tasks.generateItemView(config))
      if (::g_battle_tasks.canGetReward(::g_battle_tasks.getTaskById(config)))
        this.finishedTaskIdx = this.finishedTaskIdx < 0? idx : this.finishedTaskIdx
      else if (this.finishedTaskIdx < 0 && config.id == this.currentTaskId)
        this.finishedTaskIdx = idx
    }

    this.updateNoTasksText(view.items)
    let data = ::handyman.renderCached(this.battleTaskItemTpl, view)
    this.guiScene.replaceContentFromText(listBoxObj, data, data.len(), this)

    foreach(config in this.configsArrayByTabType[this.currentTabType])
    {
      let task = config.originTask
      ::g_battle_tasks.setUpdateTimer(task, this.scene.findObject(task.id))
    }

    this.updateWidgetsVisibility()
    if (this.finishedTaskIdx < 0 || this.finishedTaskIdx >= this.configsArrayByTabType[this.currentTabType].len())
      this.finishedTaskIdx = 0
    if (this.finishedTaskIdx < listBoxObj.childrenCount())
      listBoxObj.setValue(this.finishedTaskIdx)

    let needShowWarbondProgress = !hasFeature("BattlePass")
    let obj = this.scene.findObject("warbond_shop_progress_block")
    let curWb = ::g_warbonds.getCurrentWarbond()
    if (needShowWarbondProgress && this.currentTabType == BattleTasksWndTab.BATTLE_TASKS)
      ::g_warbonds_view.createProgressBox(curWb, obj, this)
    else if (this.currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD)
      ::g_warbonds_view.createSpecialMedalsProgress(curWb, obj, this, !::g_battle_tasks.hasInCompleteHardTask.value)
  }

  function updateNoTasksText(items = [])
  {
    let tabsListObj = this.getTabsListObj()
    let tabData = this.getSelectedTabData(tabsListObj)

    local text = ""
    if (items.len() == 0 && "noTasksLocId" in tabData)
      text = loc(tabData.noTasksLocId)
    this.scene.findObject("battle_tasks_no_tasks_text").setValue(text)
  }

  function updateWidgetsVisibility()
  {
    let listBoxObj = this.getConfigsListObj()
    if (!checkObj(listBoxObj))
      return

    foreach(taskId, _w in this.newIconWidgetByTaskId)
    {
      let newIconWidgetContainer = listBoxObj.findObject("new_icon_widget_" + taskId)
      if (!checkObj(newIconWidgetContainer))
        continue

      let widget = ::NewIconWidget(this.guiScene, newIconWidgetContainer)
      this.newIconWidgetByTaskId[taskId] = widget
      widget.setWidgetVisible(::g_battle_tasks.isBattleTaskNew(taskId))
    }
  }

  function updateBattleTasksData()
  {
    this.currentTasksArray = ::g_battle_tasks.getTasksArray()
    this.newIconWidgetByTaskId = ::g_battle_tasks.getWidgetsTable()
    this.buildBattleTasksArray(BattleTasksWndTab.BATTLE_TASKS)
    this.buildBattleTasksArray(BattleTasksWndTab.BATTLE_TASKS_HARD)
  }

  function fillTasksHistory()
  {
    let finishedTasksUserlogsArray = ::getUserLogsList(this.userglogFinishedTasksFilter)

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

    let data = ::handyman.renderCached(this.sceneTplDescriptionName, view)
    this.guiScene.replaceContentFromText(this.scene.findObject("tasks_history_frame"), data, data.len(), this)
  }

  function onChangeTab(obj)
  {
    if (!checkObj(obj))
      return

    ::g_sound.stop()
    let curTabData = this.getSelectedTabData(obj)
    this.currentTabType = curTabData.tabType
    this.changeFrameVisibility()
    this.updateTabButtons()

    if (curTabData.fillFunc in this)
      this[curTabData.fillFunc]()

    this.guiScene.applyPendingChanges(false)
  }

  function getSelectedTabData(listObj)
  {
    local val = 0
    if (checkObj(listObj))
      val = listObj.getValue()

    return val in this.tabsList? this.tabsList[val] : {}
  }

  function changeFrameVisibility()
  {
    this.showSceneBtn("tasks_list_frame", this.currentTabType != BattleTasksWndTab.HISTORY)
    this.showSceneBtn("tasks_history_frame", this.currentTabType == BattleTasksWndTab.HISTORY)
  }

  function onEventBattleTasksFinishedUpdate(_params)
  {
    this.updateBattleTasksData()
    this.onChangeTab(this.getTabsListObj())
  }

  function onEventBattleTasksTimeExpired(_params)
  {
    this.onChangeTab(this.getTabsListObj())
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
    let config = this.getConfigByValue(value)
    let task = ::g_battle_tasks.getTaskById(config)
    if (!task)
      return

    if (::g_battle_tasks.canGetReward(task))
      return ::g_battle_tasks.requestRewardForTask(task.id)

    let isActive = ::g_battle_tasks.isTaskActive(task)
    if (isActive && ::g_battle_tasks.canCancelTask(task))
      return this.onCancel(config)

    if (!isActive)
      return this.onActivate()
  }

  function onSelectTask(obj)
  {
    let val = obj.getValue()
    this.finishedTaskIdx = val

    ::g_sound.stop()

    let config = this.getConfigByValue(val)
    this.preparePlaybackForConfig(config)

    this.updateButtons(config)
    this.hideTaskWidget(config)

    this.guiScene.applyPendingChanges(false)
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
    let widget = getTblValue(uid, this.newIconWidgetByTaskId)
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

    ::showBtnTable(this.scene, {
      btn_activate = showActivateButton
      btn_cancel = showCancelButton
      btn_warbonds_shop = ::g_warbonds.isShopButtonVisible() && !::isHandlerInScene(::gui_handlers.WarbondsShop)
    })

    let showRerollButton = isBattleTask && !isDone && !canGetReward && !::u.isEmpty(::g_battle_tasks.rerollCost)
    let taskObj = this.getCurrentTaskObj()
    if (!checkObj(taskObj))
      return

    ::showBtn("btn_reroll", showRerollButton, taskObj)
    ::showBtn("btn_recieve_reward", canGetReward, taskObj)
    if (showRerollButton)
      placePriceTextToButton(taskObj, "btn_reroll", loc("mainmenu/battleTasks/reroll"), ::g_battle_tasks.rerollCost)
    this.showSceneBtn("btn_requirements_list", ::show_console_buttons && getTblValue("names", config, []).len() != 0)

    let id = config?.id ?? ""
    ::enableBtnTable(taskObj, {[this.getConfigPlaybackButtonId(id)] = ::g_sound.canPlay(id)})
  }

  function updateTabButtons()
  {
    this.showSceneBtn("show_all_tasks", hasFeature("ShowAllBattleTasks") && this.currentTabType != BattleTasksWndTab.HISTORY)
    this.showSceneBtn("battle_tasks_modes_radiobuttons", this.currentTabType == BattleTasksWndTab.BATTLE_TASKS)
    this.showSceneBtn("warbond_shop_progress_block", this.isBattleTasksTab())
    this.showSceneBtn("progress_box_place", this.currentTabType == BattleTasksWndTab.BATTLE_TASKS
      && !hasFeature("BattlePass"))
    this.showSceneBtn("medal_icon", this.currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD)
    this.updateProgressText()
  }

  function isBattleTasksTab()
  {
    return this.currentTabType == BattleTasksWndTab.BATTLE_TASKS
    || this.currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD
  }

  function updateProgressText()
  {
    let textObj = this.scene.findObject("progress_text")
    if (!checkObj(textObj))
      return

    let curWb = ::g_warbonds.getCurrentWarbond()
    local text = ""
    let tooltip = ""
    if (curWb && this.currentTabType == BattleTasksWndTab.BATTLE_TASKS && !hasFeature("BattlePass"))
      text = ::g_warbonds_view.getCurrentShopProgressBarText(curWb)

    textObj.setValue(text)
    textObj.tooltip = tooltip
  }

  function getCurrentTaskObj()
  {
    let listObj = this.getConfigsListObj()
    if (!checkObj(listObj))
      return null

    let value = listObj.getValue()
    if (value < 0 || value >= listObj.childrenCount())
      return null

    return listObj.getChild(value)
  }

  function getRadioButtonsView()
  {
    this.usingDifficulties = []
    let tplView = []
    let curMode = ::game_mode_manager.getCurrentGameMode()
    let selDiff = ::g_difficulty.getDifficultyByDiffCode(curMode ? curMode.diffCode : DIFFICULTY_ARCADE)

    foreach(_idx, diff in ::g_difficulty.types)
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
      this.usingDifficulties.append(diff.diffCode)
    }

    if (tplView.len() && "diffCode" in selDiff && this.usingDifficulties.indexof(selDiff.diffCode) == null)
      tplView.top().selected = true

    return tplView
  }

  function getTabsView()
  {
    let view = {tabs = []}
    foreach (idx, tabData in this.tabsList)
    {
      view.tabs.append({
        tabName = tabData.text
        navImagesText = ::get_navigation_images_text(idx, this.tabsList.len())
        hidden = ("isVisible" in tabData) && !tabData.isVisible()
      })
    }

    return ::handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
  }

  function onChangeShowMode(_obj)
  {
    this.notifyUpdate()
  }

  function getCurrentSelectedTask()
  {
    let config = this.getCurrentConfig()
    return ::g_battle_tasks.getTaskById(config)
  }

  function getConfigByValue(value)
  {
    let checkArray = getTblValue(this.currentTabType, this.configsArrayByTabType, [])
    return getTblValue(value, checkArray)
  }

  function onGetRewardForTask(obj)
  {
    ::g_battle_tasks.requestRewardForTask(obj?.task_id)
  }

  function madeTaskAction(mode)
  {
    let task = this.getCurrentSelectedTask()
    if (!getTblValue("id", task))
      return

    let blk = ::DataBlock()
    blk.setStr("mode", mode)
    blk.setStr("unlockName", task.id)

    let taskId = ::char_send_blk("cln_management_personal_unlocks", blk)
    ::g_tasker.addTask(taskId, {showProgressBox = true}, this.notifyUpdate)
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
    let task = this.getCurrentSelectedTask()
    if (!::g_battle_tasks.canActivateTask(task))
      return

    this.madeTaskAction("accept")
  }

  function onCancel(config)
  {
    if (getTblValue("curVal", config, 0) <= 0)
      return this.madeTaskAction("cancel")

    this.msgBox("battletasks_confirm_cancel", loc("msgbox/battleTasks/clarifyCancel"),
    [["ok", function(){ this.madeTaskAction("cancel") }],
     ["cancel", function() {}]], "cancel")
  }

  function getConfigPlaybackButtonId(btnId)
  {
    return btnId + "_sound"
  }

  function getConfigsListObj()
  {
    if (checkObj(this.scene))
      return this.scene.findObject("tasks_list")
    return null
  }

  function getDifficultySwitchObj()
  {
    return this.scene.findObject("battle_tasks_modes_radiobuttons")
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

    let warbondsObj = this.scene.findObject("warbonds_balance")
    warbondsObj.setValue(::g_warbonds.getBalanceText())
    warbondsObj.tooltip = loc("warbonds/maxAmount", {warbonds = ::g_warbonds.getLimit()})
  }

  function onEventProfileUpdated(_p)
  {
    this.updateWarbondsBalance()
  }

  function onEventPlaybackDownloaded(p)
  {
    if (!checkObj(this.scene))
      return

    let pbObj = this.scene.findObject(this.getConfigPlaybackButtonId(p.id))
    if (!checkObj(pbObj))
      return

    pbObj.enable(p.success)
    pbObj.downloading = p.success? "no" : "yes"

    if (p.success)
      return

    let config = this.getConfigByValue(this.finishedTaskIdx)
    if (config)
      this.preparePlaybackForConfig(config, true)
  }

  function onEventFinishedPlayback(_p)
  {
    let config = this.getConfigByValue(this.finishedTaskIdx)
    if (!config)
      return

    let pbObjId = this.getConfigPlaybackButtonId(config.id)
    let pbObj = this.scene.findObject(pbObjId)
    if (checkObj(pbObj))
      pbObj.setValue(false)
  }

  function onWarbondsShop()
  {
    ::g_warbonds.openShop()
  }

  function getCurrentConfig()
  {
    let listBoxObj = this.getConfigsListObj()
    if (!checkObj(listBoxObj))
      return null

    return this.getConfigByValue(listBoxObj.getValue())
  }

  function onViewBattleTaskRequirements()
  {
    let config = this.getCurrentConfig()
    if (getTblValue("names", config, []).len() == 0)
      return

    let awardsList = []
    foreach(id in config.names)
      awardsList.append(::build_log_unlock_data(::build_conditions_config(::g_unlocks.getUnlockById(id))))

    showUnlocksGroupWnd(awardsList, loc("unlocks/requirements"))
  }

  function switchPlaybackMode(obj)
  {
    let config = this.getConfigByValue(this.finishedTaskIdx)
    if (!config)
      return

    if (!obj.getValue())
      ::g_sound.stop()
    else
      ::g_sound.play(config.id)
  }

  function getTabsListObj()
  {
    return this.scene.findObject("tasks_sheet_list")
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

addPromoAction("battle_tasks", @(_handler, params, obj) openBattleTasksWndFromPromo(params, obj))
