local wwActionsWithUnitsList = require("scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")

class ::gui_handlers.WwAirfieldsList extends ::BaseGuiHandler
{
  wndType = handlerType.CUSTOM
  sceneTplName = "gui/worldWar/airfieldObject"
  sceneBlkName = null
  airfieldBlockTplName = "gui/worldWar/worldWarMapArmyItem"

  airfieldIdPrefix = "airfield_"

  side = ::SIDE_NONE

  ownedAirfieldsNumber = -1
  updateTimer = null
  updateDelay = 1

  function getSceneTplView()
  {
    return {
      isControlHelpCentered = true
      consoleButtonsIconName = ::show_console_buttons ? WW_MAP_CONSPLE_SHORTCUTS.MOVE : null
      controlHelpText = ::show_console_buttons ? null : ::loc("key/RMB")
      controlHelpDesc = ::loc("worldwar/state/air_fly_out_control")
    }
  }

  function initScreen()
  {
    updateAirfields()
    if (::ww_get_selected_airfield() >= 0)
    {
      updateSelectedAirfield(::ww_get_selected_airfield())
      selectDefaultFormation()
    }
  }

  function getSceneTplContainerObj()
  {
    return scene
  }

  function isValid()
  {
    return ::checkObj(scene) && ::checkObj(scene.findObject("airfields_list"))
  }

  function getAirfields()
  {
    local selAirfield = ::ww_get_selected_airfield()
    local airfields = []
    local fieldsArray = ::g_world_war.getAirfieldsArrayBySide(side)
    foreach(idx, field in fieldsArray)
    {
      airfields.append({
        id = getAirfieldId(field.index)
        text = (idx+1)
        selected = selAirfield == field.index
      })
    }

    return airfields
  }

  function updateAirfields()
  {
    local airfields = getAirfields()
    local placeObj = scene.findObject("airfields_list")
    local view = { airfields = airfields }
    local data = ::handyman.renderCached("gui/worldWar/wwAirfieldsList", view)
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)
    ownedAirfieldsNumber = airfields.len()
  }

  function fillTimer(airfieldIdx, cooldownView)
  {
    local placeObj = scene.findObject("airfield_object")
    if (!::check_obj(placeObj))
      return

    if (updateTimer)
      updateTimer.destroy()

    updateTimer = ::Timer(placeObj, updateDelay,
      (@(placeObj, airfieldIdx, cooldownView) function() {
        onUpdateTimer(placeObj, airfieldIdx, cooldownView)
      })(placeObj, airfieldIdx, cooldownView), this, true)

    onUpdateTimer(placeObj, airfieldIdx, cooldownView)
  }

  function onUpdateTimer(placeObj, airfieldIdx, cooldownView)
  {
    if (!::getTblValue("army", cooldownView))
      return

    local airfield = ::g_world_war.getAirfieldByIndex(airfieldIdx)
    if (!airfield)
      return

    if (cooldownView.army.len() != airfield.getCooldownsWithManageAccess().len())
    {
      updateSelectedAirfield(airfieldIdx)
      return
    }

    foreach (idx, item in cooldownView.army)
    {
      local blockObj = placeObj.findObject(item.getId())
      if (!::check_obj(blockObj))
        return
      local timerObj = blockObj.findObject("arrival_time_text")
      if (!::check_obj(timerObj))
        return

      local timerText = airfield.cooldownFormations[item.getFormationID()].getCooldownText()
      timerObj.setValue(timerText)
    }
  }

  function updateAirfieldFormation(index = -1)
  {
    local blockObj = scene.findObject("airfield_block")
    if (!::check_obj(blockObj))
      return
    local placeObj = blockObj.findObject("free_formations")
    if (!::check_obj(placeObj))
      return

    if (index < 0)
    {
      blockObj.show(false)
      guiScene.replaceContentFromText(placeObj, "", 0, this)
      return
    }

    local airfield = ::g_world_war.getAirfieldByIndex(index)
    local formationView = {
      army = []
      showArmyGroupText = false
      hasFormationData = true
      reqUnitTypeIcon = true
      addArmySelectCb = true
      checkMyArmy = true
      customCbName = "onChangeFormationValue"
      formationType = "formation"
    }

    foreach (i, formation in [airfield.clanFormation, airfield.allyFormation])
      if (formation)
      {
        local wwFormationView = formation.getView()
        if (wwFormationView && wwFormationView.unitsCount() > 0)
          formationView.army.append(formation.getView())
      }

    local data = ::handyman.renderCached(airfieldBlockTplName, formationView)
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)

    blockObj.show(true)
  }

  function hasFormationsForFly(airfield)
  {
    if (!airfield)
      return false

    foreach (formation in [airfield.clanFormation, airfield.allyFormation])
      if (formation)
        if (wwActionsWithUnitsList.unitsCount(formation.getUnits()))
          return true

    return false
  }

  function updateAirfieldCooldownList(index = -1)
  {
    local placeObj = scene.findObject("cooldowns_list")
    if (index < 0)
      guiScene.replaceContentFromText(placeObj, "", 0, this)

    local cooldownView = {
      army = []
      showArmyGroupText = false
      hasFormationData = true
      reqUnitTypeIcon = true
      addArmySelectCb = true
      checkMyArmy = true
      customCbName = "onChangeCooldownValue"
      formationType = "cooldown"
    }

    local airfield = ::g_world_war.getAirfieldByIndex(index)
    local cooldownFormations = airfield.getCooldownsWithManageAccess()
    foreach (i, cooldown in cooldownFormations)
      cooldownView.army.append(cooldown.getView())

    local data = ::handyman.renderCached(airfieldBlockTplName, cooldownView)
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)
    fillTimer(index, cooldownView)
  }

  function hasArmyOnCooldown(airfield)
  {
    if (!airfield)
      return false

    local cooldownFormations = airfield.getCooldownsWithManageAccess()
    return cooldownFormations.len() > 0
  }

  function updateAirfieldDescription(index = -1)
  {
    local airfieldBlockObj = scene.findObject("airfield_block")
    if (!::check_obj(airfieldBlockObj))
      return

    local airfield = ::g_world_war.getAirfieldByIndex(index)
    local isAirfielValid = airfield.isValid()

    airfieldBlockObj.show(isAirfielValid)
    if (!isAirfielValid)
      return

    local airfieldInfoObj = airfieldBlockObj.findObject("airfield_info_text")
    if (!::check_obj(airfieldInfoObj))
      return

    local airfieldUnitsText = ::loc("worldwar/airfield_units") + ::loc("ui/colon")
    local airfieldInFlyText = ::loc("worldwar/airfield_in_fly") + ::loc("ui/colon")
    local airfieldCapacityText = ::loc("worldwar/airfield_capacity") + ::loc("ui/colon")
    local iconText = ::g_ww_unit_type.AIR.fontIcon

    local airfieldUnitsNumber = airfield.getUnitsNumber()
    local inFlyUnitsNumber = airfield.getUnitsInFlyNumber()
    local airfieldCapacityNumber = airfield.getSize()
    local isFull = airfieldUnitsNumber + inFlyUnitsNumber >= airfieldCapacityNumber

    local airfieldInfoValue = airfieldUnitsNumber
    local airfieldTooltip = airfieldUnitsText +
      ::colorize("@white", airfieldUnitsNumber + " " + iconText)
    if (inFlyUnitsNumber > 0)
    {
      airfieldInfoValue += "+" + inFlyUnitsNumber
      airfieldTooltip += "\n" + airfieldInFlyText +
        ::colorize("@white", inFlyUnitsNumber + " " + iconText)
    }
    airfieldInfoValue += "/" + airfieldCapacityNumber + " " + iconText
    airfieldTooltip += "\n" + airfieldCapacityText +
      ::colorize("@white", airfieldCapacityNumber + " " + iconText)
    if (isFull)
      airfieldTooltip += "\n" + ::colorize("@badTextColor", ::loc("worldwar/airfield_is_full"))

    airfieldInfoObj.setValue(airfieldCapacityText +
      ::colorize(isFull ? "@badTextColor" : "@white", airfieldInfoValue))
    airfieldInfoObj.tooltip = airfieldTooltip

    local hasFormationUnits = hasFormationsForFly(airfield)
    local hasCooldownUnits = hasArmyOnCooldown(airfield)
    local formationTextObj = airfieldBlockObj.findObject("free_formations_text")
    if (!::check_obj(formationTextObj))
      return

    local text = hasFormationUnits ? ::loc("worldwar/state/ready_to_fly") + ::loc("ui/colon")
      : hasCooldownUnits ? ::loc("worldwar/state/no_units_to_fly")
      : ::loc("worldwar/state/airfield_empty")
    formationTextObj.setValue(text)

    local hasEnoughToFly = airfield.hasEnoughUnitsToFly()
    showSceneBtn("control_help", hasEnoughToFly)
    showSceneBtn("alert_text", !hasEnoughToFly)

    if (!hasFormationUnits && !hasCooldownUnits)
      ::ww_event("MapClearSelection", {})
  }

  function getAirfieldId(index)
  {
    return airfieldIdPrefix + index
  }

  function selectRadioButtonBlock(rbObj, idx)
  {
    if (::check_obj(rbObj))
      if (rbObj.childrenCount() > idx && idx >= 0)
        if (rbObj.getChild(idx))
          rbObj.getChild(idx).setValue(true)
  }

  function deselectRadioButtonBlocks(rbObj)
  {
    if (::check_obj(rbObj))
      for (local i = 0; i < rbObj.childrenCount(); i++)
        rbObj.getChild(i).setValue(false)
  }

  function onChangeFormationValue(obj)
  {
    deselectRadioButtonBlocks(scene.findObject("cooldowns_list"))
    ::ww_event("MapAirfieldFormationSelected", {
      airfieldIdx = ::ww_get_selected_airfield(),
      formationType = "formation",
      formationId = obj.formationId.tointeger()})
  }

  function onChangeCooldownValue(obj)
  {
    deselectRadioButtonBlocks(scene.findObject("free_formations"))
    ::ww_event("MapAirfieldFormationSelected", {
      airfieldIdx = ::ww_get_selected_airfield(),
      formationType = "cooldown",
      formationId = obj.formationId.tointeger()})
  }

  function onAirfieldClick(obj)
  {
    local index = ::to_integer_safe(obj.id.slice(airfieldIdPrefix.len()), -1)
    local mapObj = ::get_cur_gui_scene()["worldwar_map"]
    ::ww_gui_bhv.worldWarMapControls.selectAirfield.call(
      ::ww_gui_bhv.worldWarMapControls, mapObj, {airfieldIdx = index})
  }

  function selectDefaultFormation()
  {
    local placeObj = scene.findObject("free_formations")
    selectRadioButtonBlock(placeObj, 0)
  }

  function updateSelectedAirfield(selectedAirfield = -1)
  {
    if (ownedAirfieldsNumber != getAirfields().len())
      updateAirfields()

    for (local index = 0; index < ::ww_get_airfields_count(); index++)
    {
      local airfieldObj = scene.findObject(getAirfieldId(index))
      if (::checkObj(airfieldObj))
        airfieldObj.selected = selectedAirfield == index? "yes" : "no"
    }
    updateAirfieldFormation(selectedAirfield)
    updateAirfieldCooldownList(selectedAirfield)
    updateAirfieldDescription(selectedAirfield)
    selectDefaultFormation()
  }

  function onEventWWMapAirfieldSelected(params)
  {
    if (!::checkObj(scene))
      return

    updateSelectedAirfield(::ww_get_selected_airfield())
  }

  function onEventWWMapAirfieldCleared(params)
  {
    updateSelectedAirfield()
  }

  function onEventWWLoadOperation(params = {})
  {
    updateSelectedAirfield(::ww_get_selected_airfield())
  }

  function onEventWWMapClearSelectionBySelectedObject(params)
  {
    if (params.objSelected != mapObjectSelect.AIRFIELD)
      updateSelectedAirfield()
  }
}
