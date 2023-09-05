//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { isBattleTasksAvailable, mkUnlockConfigByBattleTask, filterBattleTasksByGameModeId,
  getBattleTaskView
} = require("%scripts/unlocks/battleTasks.nut")
let DataBlock = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

::gui_start_battle_tasks_select_new_task_wnd <- function gui_start_battle_tasks_select_new_task_wnd(battleTasksArray = null) {
  if (!isBattleTasksAvailable() || u.isEmpty(battleTasksArray))
    return

  ::gui_start_modal_wnd(gui_handlers.BattleTasksSelectNewTaskWnd, { battleTasksArray = battleTasksArray })
}

gui_handlers.BattleTasksSelectNewTaskWnd <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/unlocks/battleTasksSelectNewTask.tpl"

  battleTasksArray = null
  battleTasksConfigsArray = null

  function getSceneTplView() {
    return {
      items = this.getBattleTasksViewData()
    }
  }

  function getSceneTplContainerObj() {
    return this.scene.findObject("root-box")
  }

  function getBattleTasksViewData() {
    this.battleTasksConfigsArray = this.battleTasksArray.map(@(task) mkUnlockConfigByBattleTask(task))
    return this.battleTasksConfigsArray.map(@(config) getBattleTaskView(config))
  }

  function initScreen() {
    let listObj = this.getConfigsListObj()
    if (listObj) {
      let currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
      let filteredTasksArray = filterBattleTasksByGameModeId(this.battleTasksArray, currentGameModeId)

      local index = 0
      if (filteredTasksArray.len())
        index = this.battleTasksArray.findindex(@(task) filteredTasksArray[0].id == task.id) ?? 0

      listObj.setValue(index)
    }
  }

  function getCurrentConfig() {
    let listObj = this.getConfigsListObj()
    if (listObj)
      return this.battleTasksConfigsArray[listObj.getValue()]

    return null
  }

  function onSelectTask(_obj) {
    let config = this.getCurrentConfig()
    let taskObj = this.getCurrentTaskObj()

    showObjById("btn_reroll", false, taskObj)
    this.showSceneBtn("btn_requirements_list", showConsoleButtons.value && this.isConfigHaveConditions(config))
  }

  function onSelect(_obj) {
    let config = this.getCurrentConfig()
    if (!config)
      return

    let blk = DataBlock()
    blk.addStr("mode", "accept")
    blk.addStr("unlockName", config.id)

    let taskId = ::char_send_blk("cln_management_personal_unlocks", blk)
    ::g_tasker.addTask(taskId,
      { showProgressBox = true },
      Callback(function() {
          this.goBack()
          broadcastEvent("BattleTasksIncomeUpdate")
        }, this)
    )
  }

  function isConfigHaveConditions(config) {
    return getTblValue("names", config, []).len() != 0
  }

  function onViewBattleTaskRequirements() {
    let config = this.getCurrentConfig()
    if (!this.isConfigHaveConditions(config))
      return

    let awardsList = config.names.map(@(id) ::build_log_unlock_data(
        ::build_conditions_config(getUnlockById(id))
      )
    )

    showUnlocksGroupWnd(awardsList, loc("unlocks/requirements"))
  }

  function getConfigsListObj() {
    if (checkObj(this.scene))
      return this.scene.findObject("tasks_list")
    return null
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

  function onTaskReroll(_obj) {}
}