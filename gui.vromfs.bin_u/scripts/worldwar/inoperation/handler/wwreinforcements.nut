class ::gui_handlers.WwReinforcements extends ::BaseGuiHandler
{
  wndType = handlerType.CUSTOM
  sceneTplName = "gui/worldWar/worldWarMapReinforcementsList"
  sceneBlkName = null
  reinforcementBlockTplName = "gui/worldWar/worldWarMapArmyItem"

  armiesBlocks = null
  readyArmiesNames = null

  timerHandler = null
  updateDelay = 1 //sec

  currentReinforcementName = null
  reinforcementSpeedup = -1

  function getSceneTplView()
  {
    return {
      consoleButtonsIconName = ::show_console_buttons ? WW_MAP_CONSPLE_SHORTCUTS.MOVE : null
      controlHelpText = ::show_console_buttons ? null : ::loc("key/RMB")
      controlHelpDesc = ::loc("worldwar/state/reinforcement_control")
    }
  }

  function getSceneTplContainerObj()
  {
    return scene
  }

  function initScreen()
  {
    readyArmiesNames = []
    armiesBlocks = []
    updateScene()
  }

  function isValid()
  {
    return ::checkObj(scene) && ::checkObj(scene.findObject("reinforcements_list"))
  }

  function updateScene()
  {
    fillReinforcementsList()
    fillTimer()
  }

  function onEventWWLoadOperation(params)
  {
    updateScene()
    readyArmiesNames.clear()
  }

  function updateReinforcementsList()
  {
    local playerSide = ::ww_get_player_side()

    armiesBlocks.clear()

    local existedArmies = []
    local newArmies = []

    local reinforcementsInfo = ::g_world_war.getReinforcementsInfo()
    if (reinforcementsInfo?.reinforcements == null)
      return

    for (local i = 0; i < reinforcementsInfo.reinforcements.blockCount(); i++)
    {
      local reinforcement = reinforcementsInfo.reinforcements.getBlock(i)
      local wwReinforcementArmy = ::WwReinforcementArmy(reinforcement)
      if (!::has_feature("worldWarMaster") &&
          (!wwReinforcementArmy.isMySide(playerSide) ||
           !wwReinforcementArmy.hasManageAccess())
          )
        continue

      if (::isInArray(wwReinforcementArmy.getView().getId(), readyArmiesNames))
        existedArmies.append(wwReinforcementArmy)
      else
        newArmies.append(wwReinforcementArmy)
    }

    existedArmies.sort(::WwReinforcementArmy.sortReadyReinforcements)
    newArmies.sort(::WwReinforcementArmy.sortNewReinforcements)

    armiesBlocks.extend(existedArmies)
    armiesBlocks.extend(newArmies)
  }

  function showDeployHint(isVisible = false)
  {
    showSceneBtn("deploy_hint_nest", isVisible)
  }

  function onChangeArmyValue(obj)
  {
    updateSelectedArmy(false, false)
    if (currentReinforcementName != obj.armyName)
      guiScene.playSound("ww_reinforcement_select")

    currentReinforcementName = obj.armyName
    showDeployHint(obj?.canDeploy == "yes")
    ::ww_event("SelectedReinforcement", { name = currentReinforcementName })
  }

  function onEventWWMapRequestReinforcement(params)
  {
    if (!currentReinforcementName)
      return

    local taskId = ::g_world_war.sendReinforcementRequest(
      params.cellIdx, currentReinforcementName)
    ::g_tasker.addTask(taskId, null, ::Callback(afterSendReinforcement, this),
      ::Callback(onSendReinforcementError, this))
  }

  function afterSendReinforcement()
  {
    if (!::checkObj(scene))
      return

    local mapObj = guiScene["worldwar_map"]
    ::ww_gui_bhv.worldWarMapControls.selectArmy.call(::ww_gui_bhv.worldWarMapControls, mapObj, currentReinforcementName)
    updateSelectedArmy(false, true)

    local selectedArmies = ::ww_get_selected_armies_names()
    if (!selectedArmies.len())
      return

    local wwArmy = ::g_world_war.getArmyByName(selectedArmies[0])
    if (wwArmy)
      ::g_world_war.playArmyActionSound("deploySound", wwArmy)
  }

  function onSendReinforcementError(err)
  {
    ::g_world_war.popupCharErrorMsg("reinforcement_deploy_error")
    ::ww_event("ShowRearZones", {name = currentReinforcementName})
  }

  function fillReinforcementsList()
  {
    updateReinforcementsList()

    showSceneBtn("no_reinforcements_text", armiesBlocks.len() == 0)

    local readyArmies = []
    local otherArmies = []
    foreach (army in armiesBlocks)
      if (army.isReady())
        readyArmies.append(army.getView())
      else
        otherArmies.append(army.getView())

    fillArmiesList(readyArmies, "ready_reinforcements_list", true)
    fillArmiesList(otherArmies, "reinforcements_list", false)
    showSceneBtn("no_ready_reinforcements_text", readyArmies.len() == 0)
    showSceneBtn("ready_label", readyArmies.len() > 0)
    showSceneBtn("ready_reinforcements_block", armiesBlocks.len() > 0)
    showSceneBtn("coming_reinforcements_block", otherArmies.len() > 0)

    updateSelectedArmy(true, false)
  }

  function fillReinforcementsSpeed(newSpeedup)
  {
    if (reinforcementSpeedup == newSpeedup)
      return

    local textObj = scene.findObject("arrival_speed_text")
    if (!::check_obj(textObj))
      return

    local speedText = ""
    if (newSpeedup > 0)
    {
      speedText = ::colorize("goodTextColor", ::loc("keysPlus") + newSpeedup)
      speedText = ::loc("worldwar/state/reinforcement_arrival_speed", {speedup = speedText})
    }
    else
      speedText = ::loc("worldwar/state/reinforcement_arrival_basic_speed")

    textObj.setValue(speedText)
    reinforcementSpeedup = newSpeedup
  }

  function fillArmiesList(viewsArray, id, isReady)
  {
    local placeObj = scene.findObject(id)
    if (!::checkObj(placeObj))
      return

    local view = {
      army = viewsArray
      reqUnitTypeIcon = true
      checkMyArmy = true
      showArmyGroupText = false
      addArmySelectCb = true
      isArmyReady = isReady
    }

    local data = ::handyman.renderCached(reinforcementBlockTplName, view)
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)
  }

  function onEventWWMapClearSelection(params)
  {
    updateSelectedArmy(false, false)
  }

  function onEventWWMapClearSelectionBySelectedObject(params)
  {
    updateSelectedArmy(false, false)
  }

  function onEventWWReinforcementSpeedupUpdated(params)
  {
    fillReinforcementsSpeed(params?.speedup ?? 0)
  }

  function updateSelectedArmy(select, destroy)
  {
    if (::u.isEmpty(currentReinforcementName))
      return

    local selectedArmy = ::u.search(armiesBlocks, (@(currentReinforcementName) function(reinf) {
        return reinf.name == currentReinforcementName
      })(currentReinforcementName))

    if (!selectedArmy)
    {
      //search in existed, because army can already be an army, not a reinforcement
      local army = ::g_world_war.getArmyByName(currentReinforcementName)
      if (!army.isValid())
        return

      selectedArmy = army
    }

    local obj = scene.findObject(selectedArmy.getView().getId())
    if (::checkObj(obj))
    {
      obj.setValue(select)
      if (destroy)
      {
        local placeObj = obj.getParent()
        guiScene.destroyElement(obj)
        showSceneBtn("no_reinforcements_text", placeObj.childrenCount() == 0)
      }
    }

    showDeployHint(select)
    if (!select)
      currentReinforcementName = null
  }

  function fillTimer()
  {
    local placeObj = scene.findObject("reinforcements_list")
    if (!::check_obj(placeObj))
      return

    timerHandler = ::Timer(
      placeObj,
      updateDelay,
      (@(placeObj) function() {
        local haveNewReinforcementsReady = false
        foreach (reinforcementHandler in armiesBlocks)
        {
          local id = reinforcementHandler.getView().getId()
          if (reinforcementHandler.isReady() && !::isInArray(id, readyArmiesNames))
          {
            readyArmiesNames.append(id)
            haveNewReinforcementsReady = true
          }

          local reinfObj = placeObj.findObject(id)
          if (!::check_obj(reinfObj))
            continue

          local timeTextObj = reinfObj.findObject("arrival_time_text")
          timeTextObj.setValue(reinforcementHandler.getArrivalStatusText())
        }
        if (haveNewReinforcementsReady)
          updateScene()
      })(placeObj),
      this, true)
  }

  function selectFirstArmyBySide(side)
  {
    local reinforcementsObj = scene.findObject("ready_reinforcements_list")
    if (reinforcementsObj.childrenCount())
      reinforcementsObj.getChild(0).setValue(true)

    foreach (army in armiesBlocks)
      if (army.isReady() && ::ww_side_val_to_name(army.getArmySide()) == side)
      {
        local armyView = army.getView()
        if (!armyView)
          continue

        local reinforcementObj = reinforcementsObj.findObject(armyView.getId())
        if (!::check_obj(reinforcementObj))
          continue

        reinforcementObj.setValue(true)
        break
      }
  }
}
