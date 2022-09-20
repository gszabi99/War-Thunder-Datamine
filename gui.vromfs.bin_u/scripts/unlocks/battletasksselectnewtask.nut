let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")

::gui_start_battle_tasks_select_new_task_wnd <- function gui_start_battle_tasks_select_new_task_wnd(battleTasksArray = null)
{
  if (!::g_battle_tasks.isAvailableForUser() || ::u.isEmpty(battleTasksArray))
    return

  ::gui_start_modal_wnd(::gui_handlers.BattleTasksSelectNewTaskWnd, {battleTasksArray = battleTasksArray})
}

::gui_handlers.BattleTasksSelectNewTaskWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/unlocks/battleTasksSelectNewTask"

  battleTasksArray = null
  battleTasksConfigsArray = null

  function getSceneTplView()
  {
    return {
      items = getBattleTasksViewData()
    }
  }

  function getSceneTplContainerObj()
  {
    return scene.findObject("root-box")
  }

  function getBattleTasksViewData()
  {
    battleTasksConfigsArray = ::u.map(battleTasksArray, @(task) ::g_battle_tasks.generateUnlockConfigByTask(task))
    return ::u.map(battleTasksConfigsArray, @(config) ::g_battle_tasks.generateItemView(config))
  }

  function initScreen()
  {
    let listObj = getConfigsListObj()
    if (listObj)
    {
      let currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
      let filteredTasksArray = ::g_battle_tasks.filterTasksByGameModeId(battleTasksArray, currentGameModeId)

      local index = 0
      if (filteredTasksArray.len())
        index = battleTasksArray.findindex(@(task) filteredTasksArray[0].id == task.id) ?? 0

      listObj.setValue(index)
    }
  }

  function getCurrentConfig()
  {
    let listObj = getConfigsListObj()
    if (listObj)
      return battleTasksConfigsArray[listObj.getValue()]

    return null
  }

  function onSelectTask(obj)
  {
    let config = getCurrentConfig()
    let taskObj = getCurrentTaskObj()

    ::showBtn("btn_reroll", false, taskObj)
    this.showSceneBtn("btn_requirements_list", ::show_console_buttons && isConfigHaveConditions(config))
  }

  function onSelect(obj)
  {
    let config = getCurrentConfig()
    if (!config)
      return

    let blk = ::DataBlock()
    blk.addStr("mode", "accept")
    blk.addStr("unlockName", config.id)

    let taskId = ::char_send_blk("cln_management_personal_unlocks", blk)
    ::g_tasker.addTask(taskId,
      {showProgressBox = true},
      ::Callback(function() {
          goBack()
          ::broadcastEvent("BattleTasksIncomeUpdate")
        }, this)
    )
  }

  function isConfigHaveConditions(config)
  {
    return ::getTblValue("names", config, []).len() != 0
  }

  function onViewBattleTaskRequirements()
  {
    let config = getCurrentConfig()
    if (!isConfigHaveConditions(config))
      return

    let awardsList = ::u.map(config.names,
      @(id) ::build_log_unlock_data(
        ::build_conditions_config(
          ::g_unlocks.getUnlockById(id)
        )
      )
    )

    showUnlocksGroupWnd([{
      unlocksList = awardsList
      titleText = ::loc("unlocks/requirements")
    }])
  }

  function getConfigsListObj()
  {
    if (::checkObj(scene))
      return scene.findObject("tasks_list")
    return null
  }

  function getCurrentTaskObj()
  {
    let listObj = getConfigsListObj()
    if (!::checkObj(listObj))
      return null

    let value = listObj.getValue()
    if (value < 0 || value >= listObj.childrenCount())
      return null

    return listObj.getChild(value)
  }

  function onTaskReroll(obj) {}
}