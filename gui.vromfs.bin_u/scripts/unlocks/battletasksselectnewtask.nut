::gui_start_battle_tasks_select_new_task_wnd <- function gui_start_battle_tasks_select_new_task_wnd(battleTasksArray = null)
{
  if (!::g_battle_tasks.isAvailableForUser() || ::u.isEmpty(battleTasksArray))
    return

  ::gui_start_modal_wnd(::gui_handlers.BattleTasksSelectNewTaskWnd, {battleTasksArray = battleTasksArray})
}

class ::gui_handlers.BattleTasksSelectNewTaskWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/modalSceneWithGamercard.blk"
  sceneTplName = "gui/unlocks/battleTasksSelectNewTask"

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
    local listObj = getConfigsListObj()
    if (listObj)
    {
      local currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
      local filteredTasksArray = ::g_battle_tasks.filterTasksByGameModeId(battleTasksArray, currentGameModeId)

      local index = 0
      if (filteredTasksArray.len())
        index = battleTasksArray.findindex(@(task) filteredTasksArray[0].id == task.id) ?? 0

      listObj.setValue(index)
    }
  }

  function getCurrentConfig()
  {
    local listObj = getConfigsListObj()
    if (listObj)
      return battleTasksConfigsArray[listObj.getValue()]

    return null
  }

  function onSelectTask(obj)
  {
    local config = getCurrentConfig()
    local taskObj = getCurrentTaskObj()

    ::showBtn("btn_reroll", false, taskObj)
    showSceneBtn("btn_requirements_list", ::show_console_buttons && isConfigHaveConditions(config))
  }

  function onSelect(obj)
  {
    local config = getCurrentConfig()
    if (!config)
      return

    local blk = ::DataBlock()
    blk.addStr("mode", "accept")
    blk.addStr("unlockName", config.id)

    local taskId = ::char_send_blk("cln_management_personal_unlocks", blk)
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
    local config = getCurrentConfig()
    if (!isConfigHaveConditions(config))
      return

    local awardsList = ::u.map(config.names,
      @(id) ::build_log_unlock_data(
        ::build_conditions_config(
          ::g_unlocks.getUnlockById(id)
        )
      )
    )

    ::showUnlocksGroupWnd([{
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
    local listObj = getConfigsListObj()
    if (!::checkObj(listObj))
      return null

    local value = listObj.getValue()
    if (value < 0 || value >= listObj.childrenCount())
      return null

    return listObj.getChild(value)
  }

  function onTaskReroll(obj) {}
}