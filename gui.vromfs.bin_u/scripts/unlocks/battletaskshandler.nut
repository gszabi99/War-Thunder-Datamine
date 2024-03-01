//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/unlocks/battleTasksWndConsts.nut" import BattleTasksWndTab
from "%scripts/mainConsts.nut" import SEEN

let { g_difficulty } = require("%scripts/difficulty.nut")
let { isHandlerInScene } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { move_mouse_on_obj, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let time = require("%scripts/time.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { EASY_TASK, MEDIUM_TASK, HARD_TASK } = require("%scripts/unlocks/battleTaskDifficulty.nut")
let { isHardTaskIncomplete, getCurrentBattleTasks, getActiveBattleTasks, getWidgetsTable,
  isBattleTaskActual, isBattleTask, isSpecialBattleTask, isBattleTasksAvailable, isBattleTaskDone,
  isBattleTaskSameDiff, isBattleTaskNew, getBattleTaskRerollCost, canGetBattleTaskReward,
  getBattleTaskById, getBattleTaskWithAvailableAward, getShowAllTasks, mkUnlockConfigByBattleTask,
  getBattleTasksByDiff, markBattleTaskSeen, markAllBattleTasksSeen, saveSeenBattleTasksData,
  requestBattleTaskReward, rerollBattleTask, rerollSpecialTask,
  setBattleTasksUpdateTimer, getBattleTaskNameById, getBattleTaskView,
  canPlayerInteractWithDifficulty, withdrawTasksArrayByDifficulty
} = require("%scripts/unlocks/battleTasks.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let newIconWidget = require("%scripts/newIconWidget.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getCurrentGameMode } = require("%scripts/gameModes/gameModeManagerState.nut")

function guiStartBattleTasksWnd(taskId = null, tabType = null) {
  if (!isBattleTasksAvailable())
    return showInfoMsgBox(loc("msgbox/notAvailbleYet"))

  loadHandler(gui_handlers.BattleTasksWnd, {
    currentTaskId = taskId,
    currentTabType = tabType
  })
}

gui_handlers.BattleTasksWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/unlocks/battleTasks.tpl"
  sceneTplDescriptionName = "%gui/unlocks/battleTasksDescription.tpl"
  battleTaskItemTpl = "%gui/unlocks/battleTasksItem.tpl"

  configsArrayByTabType = {
    [BattleTasksWndTab.BATTLE_TASKS] = null,
    [BattleTasksWndTab.BATTLE_TASKS_HARD] = null,
  }

  difficultiesByTabType = {
    [BattleTasksWndTab.BATTLE_TASKS] = [EASY_TASK, MEDIUM_TASK],
    [BattleTasksWndTab.BATTLE_TASKS_HARD] = [HARD_TASK]
  }

  newIconWidgetByTaskId = null

  finishedTaskIdx = -1
  usingDifficulties = null

  currentTaskId = null
  currentTabType = null

  userglogFinishedTasksFilter = {
    show = [EULT_NEW_UNLOCK]
    checkFunc = function(userlog) { return isBattleTask(userlog.body.unlockId) }
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

  function initScreen() {
    this.updateBattleTasksData()
    this.updateButtons()

    let tabType = this.currentTabType ? this.currentTabType : this.findTabSheetByTaskId()
    this.getTabsListObj().setValue(tabType)

    this.updateWarbondsBalance()
  }

  function findTabSheetByTaskId() {
    if (this.currentTaskId)
      foreach (tabType, tasksArray in this.configsArrayByTabType) {
        let task = tasksArray && u.search(tasksArray, function(task) { return this.currentTaskId == task.id }.bindenv(this))
        if (!task)
          continue

        let tab = u.search(this.tabsList, @(tabData) tabData.tabType == tabType)
        if (!("isVisible" in tab) || tab.isVisible())
          return tabType
        break
      }

    return BattleTasksWndTab.BATTLE_TASKS
  }

  function getSceneTplView() {
    return {
      radiobuttons = this.getRadioButtonsView()
      tabs = this.getTabsView()
      showAllTasksValue = getShowAllTasks() ? "yes" : "no"
      unseenIcon = SEEN.WARBONDS_SHOP
    }
  }

  function getSceneTplContainerObj() {
    return this.scene.findObject("root-box")
  }

  function getSelectedGmDifficulty() {
    let obj = this.scene.findObject("battle_tasks_modes_radiobuttons")
    let diffCode = this.usingDifficulties?[obj.getValue()] ?? DIFFICULTY_ARCADE
    return g_difficulty.getDifficultyByDiffCode(diffCode)
  }

  function buildBattleTasksArray(tabType) {
    let gmDiff = (tabType == BattleTasksWndTab.BATTLE_TASKS) ? this.getSelectedGmDifficulty() : null
    let tasks = getShowAllTasks() // debug
      ? getCurrentBattleTasks().filter(@(t) isBattleTaskActual(t))
      : getActiveBattleTasks().filter(@(t) isBattleTaskActual(t))

    let res = []
    foreach (diff in this.difficultiesByTabType[tabType]) {
      let canInteract = getShowAllTasks() // debug
        || canPlayerInteractWithDifficulty(diff, getCurrentBattleTasks())
      if (!canInteract)
        continue

      let tasksByDiff = withdrawTasksArrayByDifficulty(diff, tasks)
      if (tasksByDiff.len() == 0)
        continue

      let taskWithReward = getBattleTaskWithAvailableAward(tasksByDiff)
      if (taskWithReward != null)
        res.append(taskWithReward)
      else
        res.extend(tasksByDiff.filter(@(t) isBattleTaskDone(t)
          || gmDiff == null || isBattleTaskSameDiff(t, gmDiff)))
    }

    this.configsArrayByTabType[tabType] = res.map(@(t) mkUnlockConfigByBattleTask(t))
  }

  function fillBattleTasksList() {
    let listBoxObj = this.getConfigsListObj()
    if (!checkObj(listBoxObj))
      return

    let view = { items = [] }
    foreach (idx, config in this.configsArrayByTabType[this.currentTabType]) {
      view.items.append(getBattleTaskView(config))
      if (canGetBattleTaskReward(getBattleTaskById(config)))
        this.finishedTaskIdx = this.finishedTaskIdx < 0 ? idx : this.finishedTaskIdx
      else if (this.finishedTaskIdx < 0 && config.id == this.currentTaskId)
        this.finishedTaskIdx = idx
    }

    this.updateNoTasksText(view.items)
    let data = handyman.renderCached(this.battleTaskItemTpl, view)
    this.guiScene.replaceContentFromText(listBoxObj, data, data.len(), this)

    foreach (config in this.configsArrayByTabType[this.currentTabType]) {
      let task = config.originTask
      setBattleTasksUpdateTimer(task, this.scene.findObject(task.id))
    }

    this.updateWidgetsVisibility()
    if (this.finishedTaskIdx < 0 || this.finishedTaskIdx >= this.configsArrayByTabType[this.currentTabType].len())
      this.finishedTaskIdx = 0
    if (this.finishedTaskIdx < listBoxObj.childrenCount())
      listBoxObj.setValue(this.finishedTaskIdx)

    if (this.currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD) {
      let obj = this.scene.findObject("warbond_shop_progress_block")
      let curWb = ::g_warbonds.getCurrentWarbond()
      ::g_warbonds_view.createSpecialMedalsProgress(curWb, obj, this, !isHardTaskIncomplete.value)
    }
  }

  function updateNoTasksText(items = []) {
    let tabsListObj = this.getTabsListObj()
    let tabData = this.getSelectedTabData(tabsListObj)

    local text = ""
    if (items.len() == 0 && "noTasksLocId" in tabData)
      text = loc(tabData.noTasksLocId)
    this.scene.findObject("battle_tasks_no_tasks_text").setValue(text)
  }

  function updateWidgetsVisibility() {
    let listBoxObj = this.getConfigsListObj()
    if (!checkObj(listBoxObj))
      return

    foreach (taskId, _w in this.newIconWidgetByTaskId) {
      let newIconWidgetContainer = listBoxObj.findObject("new_icon_widget_" + taskId)
      if (!checkObj(newIconWidgetContainer))
        continue

      let widget = newIconWidget(this.guiScene, newIconWidgetContainer)
      this.newIconWidgetByTaskId[taskId] = widget
      widget.setWidgetVisible(isBattleTaskNew(taskId))
    }
  }

  function updateBattleTasksData() {
    this.newIconWidgetByTaskId = getWidgetsTable()
    this.buildBattleTasksArray(BattleTasksWndTab.BATTLE_TASKS)
    this.buildBattleTasksArray(BattleTasksWndTab.BATTLE_TASKS_HARD)
  }

  function fillTasksHistory() {
    let finishedTasksUserlogsArray = ::getUserLogsList(this.userglogFinishedTasksFilter)

    let view = {
      doneTasksTable = {}
    }

    if (finishedTasksUserlogsArray.len()) {
      view.doneTasksTable.rows <- ""
      view.doneTasksTable.rows += ::buildTableRow("tr_header",
               [{ textType = "textareaNoTab", text = loc("unlocks/battletask"), tdalign = "left", width = "65%pw" },
               { textType = "textarea", text = loc("debriefing/sessionTime"), tdalign = "right", width = "35%pw" }])

      foreach (idx, uLog in finishedTasksUserlogsArray) {
        let config = ::build_log_unlock_data(uLog)
        local text = config.name
        if (!u.isEmpty(config.rewardText))
          text += loc("ui/parentheses/space", { text = config.rewardText })
        text = colorize("activeTextColor", text)

        let timeStr = time.buildDateTimeStr(uLog.time, true)
        let rowData = [{ textType = "textareaNoTab", text = text, tooltip = text, width = "65%pw", textRawParam = "pare-text:t='yes'; width:t='pw'; max-height:t='ph'" },
                         { textType = "textarea", text = timeStr, tooltip = timeStr, tdalign = "right", width = "35%pw" }]

        view.doneTasksTable.rows += ::buildTableRow("tr_" + idx, rowData, idx % 2 == 0)
      }
    }

    let data = handyman.renderCached(this.sceneTplDescriptionName, view)
    this.guiScene.replaceContentFromText(this.scene.findObject("tasks_history_frame"), data, data.len(), this)
  }

  function onChangeTab(obj) {
    if (!checkObj(obj))
      return

    let curTabData = this.getSelectedTabData(obj)
    this.currentTabType = curTabData.tabType
    this.changeFrameVisibility()
    this.updateTabButtons()

    if (curTabData.fillFunc in this)
      this[curTabData.fillFunc]()

    this.guiScene.applyPendingChanges(false)
  }

  function getSelectedTabData(listObj) {
    local val = 0
    if (checkObj(listObj))
      val = listObj.getValue()

    return val in this.tabsList ? this.tabsList[val] : {}
  }

  function changeFrameVisibility() {
    showObjById("tasks_list_frame", this.currentTabType != BattleTasksWndTab.HISTORY, this.scene)
    showObjById("tasks_history_frame", this.currentTabType == BattleTasksWndTab.HISTORY, this.scene)
  }

  function onEventBattleTasksFinishedUpdate(_params) {
    this.updateBattleTasksData()
    this.onChangeTab(this.getTabsListObj())
  }

  function onEventBattleTasksTimeExpired(_params) {
    this.onChangeTab(this.getTabsListObj())
  }

  function onShowAllTasks(obj) {
    broadcastEvent("BattleTasksShowAll", { showAllTasksValue = obj.getValue() })
  }

  function onSelectTask(obj) {
    let val = obj.getValue()
    this.finishedTaskIdx = val

    let config = this.getConfigByValue(val)
    this.updateButtons(config)
    this.hideTaskWidget(config)

    this.guiScene.applyPendingChanges(false)
    move_mouse_on_obj(obj.getChild(val))
  }

  function hideTaskWidget(config) {
    if (!config)
      return

    let uid = config.id
    let widget = getTblValue(uid, this.newIconWidgetByTaskId)
    if (!widget)
      return

    widget.setWidgetVisible(false)
    markBattleTaskSeen(uid)
  }

  function updateButtons(config = null) {
    showObjById("btn_warbonds_shop",
      ::g_warbonds.isShopButtonVisible() && !isHandlerInScene(gui_handlers.WarbondsShop), this.scene)

    let task = getBattleTaskById(config)
    let isTask = isBattleTask(task)
    let isDone = isBattleTaskDone(task)
    let canGetReward = isTask && canGetBattleTaskReward(task)
    let showRerollButton = isTask && !isDone && !canGetReward && !u.isEmpty(getBattleTaskRerollCost())
    let taskObj = this.getCurrentTaskObj()
    if (!checkObj(taskObj))
      return

    showObjById("btn_reroll", showRerollButton, taskObj)
    showObjById("btn_receive_reward", canGetReward, taskObj)
    if (showRerollButton)
      placePriceTextToButton(taskObj, "btn_reroll", loc("mainmenu/battleTasks/reroll"), getBattleTaskRerollCost())
    showObjById("btn_requirements_list", showConsoleButtons.value && getTblValue("names", config, []).len() != 0, this.scene)
  }

  function updateTabButtons() {
    showObjById("show_all_tasks", hasFeature("ShowAllBattleTasks") && this.currentTabType != BattleTasksWndTab.HISTORY, this.scene)
    showObjById("battle_tasks_modes_radiobuttons", this.currentTabType == BattleTasksWndTab.BATTLE_TASKS, this.scene)
    showObjById("warbond_shop_progress_block", this.isBattleTasksTab(), this.scene)
    showObjById("medal_icon", this.currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD, this.scene)
  }

  function isBattleTasksTab() {
    return this.currentTabType == BattleTasksWndTab.BATTLE_TASKS
    || this.currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD
  }

  function getCurrentTaskObj() {
    let listObj = this.getConfigsListObj()
    if (!checkObj(listObj))
      return null

    let value = listObj.getValue()
    if (value < 0 || value >= listObj.childrenCount())
      return null

    return listObj.getChild(value)
  }

  function getRadioButtonsView() {
    this.usingDifficulties = []
    let tplView = []
    let curMode = getCurrentGameMode()
    let selDiff = g_difficulty.getDifficultyByDiffCode(curMode ? curMode.diffCode : DIFFICULTY_ARCADE)

    foreach (_idx, diff in g_difficulty.types) {
      if (diff.diffCode < 0 || !diff.isAvailable(GM_DOMINATION))
        continue

      let arr = getBattleTasksByDiff(getCurrentBattleTasks(), diff)
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

  function getTabsView() {
    let view = { tabs = [] }
    foreach (idx, tabData in this.tabsList) {
      view.tabs.append({
        tabName = tabData.text
        navImagesText = ::get_navigation_images_text(idx, this.tabsList.len())
        hidden = ("isVisible" in tabData) && !tabData.isVisible()
      })
    }

    return handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
  }

  function onChangeShowMode() {
    broadcastEvent("BattleTasksIncomeUpdate")
  }

  function getConfigByValue(value) {
    let checkArray = getTblValue(this.currentTabType, this.configsArrayByTabType, [])
    return getTblValue(value, checkArray)
  }

  function onGetRewardForTask(obj) {
    requestBattleTaskReward(obj?.task_id)
  }

  function onTaskReroll(obj) {
    let taskId = obj?.task_id
    if (!taskId)
      return

    let task = getBattleTaskById(taskId)
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

  function getConfigsListObj() {
    if (checkObj(this.scene))
      return this.scene.findObject("tasks_list")
    return null
  }

  function goBack() {
    markAllBattleTasksSeen()
    saveSeenBattleTasksData()
    base.goBack()
  }

  function updateWarbondsBalance() {
    if (!hasFeature("Warbonds"))
      return

    let warbondsObj = this.scene.findObject("warbonds_balance")
    warbondsObj.setValue(::g_warbonds.getBalanceText())
    warbondsObj.tooltip = loc("warbonds/maxAmount", { warbonds = ::g_warbonds.getLimit() })
  }

  function onEventProfileUpdated(_p) {
    this.updateWarbondsBalance()
  }

  function onWarbondsShop() {
    ::g_warbonds.openShop()
  }

  function getCurrentConfig() {
    let listBoxObj = this.getConfigsListObj()
    if (!checkObj(listBoxObj))
      return null

    return this.getConfigByValue(listBoxObj.getValue())
  }

  function onViewBattleTaskRequirements() {
    let config = this.getCurrentConfig()
    if (getTblValue("names", config, []).len() == 0)
      return

    let awardsList = []
    foreach (id in config.names)
      awardsList.append(::build_log_unlock_data(::build_conditions_config(getUnlockById(id))))

    showUnlocksGroupWnd(awardsList, loc("unlocks/requirements"))
  }

  function getTabsListObj() {
    return this.scene.findObject("tasks_sheet_list")
  }
}

function openBattleTasksWndFromPromo(params = [], obj = null) {
  let taskId = obj?.task_id ?? params?[0]
  guiStartBattleTasksWnd(taskId)
}

addPromoAction("battle_tasks", @(_handler, params, obj) openBattleTasksWndFromPromo(params, obj))

return {
  guiStartBattleTasksWnd
}
