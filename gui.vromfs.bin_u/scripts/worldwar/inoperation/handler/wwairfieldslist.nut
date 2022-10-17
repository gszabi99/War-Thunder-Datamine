let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")

::gui_handlers.WwAirfieldsList <- class extends ::BaseGuiHandler
{
  wndType = handlerType.CUSTOM
  sceneTplName = "%gui/worldWar/airfieldObject"
  sceneBlkName = null
  airfieldBlockTplName = "%gui/worldWar/worldWarMapArmyItem"

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
    let selAirfield = ::ww_get_selected_airfield()
    let airfields = []
    let fieldsArray = ::g_world_war.getAirfieldsArrayBySide(side)
    foreach(idx, field in fieldsArray)
    {
      airfields.append({
        id = getAirfieldId(field.index)
        text = (idx+1)
        selected = selAirfield == field.index
        type = "".concat("ww_",field.airfieldType.objName)
      })
    }

    return airfields
  }

  function updateAirfields()
  {
    let airfields = getAirfields()
    let placeObj = scene.findObject("airfields_list")
    let view = { airfields = airfields }
    let data = ::handyman.renderCached("%gui/worldWar/wwAirfieldsList", view)
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)
    ownedAirfieldsNumber = airfields.len()
  }

  function fillTimer(airfieldIdx, cooldownView)
  {
    let placeObj = scene.findObject("airfield_object")
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

    let airfield = ::g_world_war.getAirfieldByIndex(airfieldIdx)
    if (!airfield)
      return

    if (cooldownView.army.len() != airfield.getCooldownsWithManageAccess().len())
    {
      updateSelectedAirfield(airfieldIdx)
      return
    }

    foreach (idx, item in cooldownView.army)
    {
      let blockObj = placeObj.findObject(item.getId())
      if (!::check_obj(blockObj))
        return
      let timerObj = blockObj.findObject("arrival_time_text")
      if (!::check_obj(timerObj))
        return

      let timerText = airfield.cooldownFormations[item.getFormationID()].getCooldownText()
      timerObj.setValue(timerText)
    }
  }

  function updateAirfieldFormation(index = -1)
  {
    let blockObj = scene.findObject("airfield_block")
    if (!::check_obj(blockObj))
      return
    let placeObj = blockObj.findObject("free_formations")
    if (!::check_obj(placeObj))
      return

    if (index < 0)
    {
      blockObj.show(false)
      guiScene.replaceContentFromText(placeObj, "", 0, this)
      return
    }

    let airfield = ::g_world_war.getAirfieldByIndex(index)
    let formationView = {
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
        let wwFormationView = formation.getView()
        if (wwFormationView && wwFormationView.unitsCount() > 0)
          formationView.army.append(formation.getView())
      }

    let data = ::handyman.renderCached(airfieldBlockTplName, formationView)
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
    let placeObj = scene.findObject("cooldowns_list")
    if (index < 0)
      guiScene.replaceContentFromText(placeObj, "", 0, this)

    let cooldownView = {
      army = []
      showArmyGroupText = false
      hasFormationData = true
      reqUnitTypeIcon = true
      addArmySelectCb = true
      checkMyArmy = true
      customCbName = "onChangeCooldownValue"
      formationType = "cooldown"
    }

    let airfield = ::g_world_war.getAirfieldByIndex(index)
    let cooldownFormations = airfield.getCooldownsWithManageAccess()
    foreach (i, cooldown in cooldownFormations)
      cooldownView.army.append(cooldown.getView())

    let data = ::handyman.renderCached(airfieldBlockTplName, cooldownView)
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)
    fillTimer(index, cooldownView)
  }

  function hasArmyOnCooldown(airfield)
  {
    if (!airfield)
      return false

    let cooldownFormations = airfield.getCooldownsWithManageAccess()
    return cooldownFormations.len() > 0
  }

  function updateAirfieldDescription(index = -1)
  {
    let airfieldBlockObj = scene.findObject("airfield_block")
    if (!::check_obj(airfieldBlockObj))
      return

    let airfield = ::g_world_war.getAirfieldByIndex(index)
    let isAirfielValid = airfield.isValid()

    airfieldBlockObj.show(isAirfielValid)
    if (!isAirfielValid)
      return

    let airfieldInfoObj = airfieldBlockObj.findObject("airfield_info_text")
    if (!::check_obj(airfieldInfoObj))
      return

    let airfieldUnitsText = "".concat(
      ::loc("".concat("worldwar/", airfield.airfieldType.objName, "_units")),
        ::loc("ui/colon"))
    let airfieldInFlyText = ::loc("worldwar/airfield_in_fly") + ::loc("ui/colon")
    let airfieldCapacityText = "".concat(
      ::loc("".concat("worldwar/", airfield.airfieldType.objName, "_capacity")),
        ::loc("ui/colon"))
    let iconText = airfield.airfieldType.unitType.fontIcon

    let airfieldUnitsNumber = airfield.getUnitsNumber()
    let inFlyUnitsNumber = airfield.getUnitsInFlyNumber()
    let airfieldCapacityNumber = airfield.getSize()
    let isFull = airfieldUnitsNumber + inFlyUnitsNumber >= airfieldCapacityNumber

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

    let hasFormationUnits = hasFormationsForFly(airfield)
    let hasCooldownUnits = hasArmyOnCooldown(airfield)
    let formationTextObj = airfieldBlockObj.findObject("free_formations_text")
    if (!::check_obj(formationTextObj))
      return

    let text = hasFormationUnits ? ::loc("worldwar/state/ready_to_fly") + ::loc("ui/colon")
      : hasCooldownUnits ? ::loc("worldwar/state/no_units_to_fly")
      : ::loc($"worldwar/state/{airfield.airfieldType.objName}_empty")
    formationTextObj.setValue(text)

    let hasEnoughToFly = airfield.hasEnoughUnitsToFly()
    this.showSceneBtn("control_help", hasEnoughToFly)
    this.showSceneBtn("alert_text", !hasEnoughToFly)

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
    let index = ::to_integer_safe(obj.id.slice(airfieldIdPrefix.len()), -1)
    let mapObj = ::get_cur_gui_scene()["worldwar_map"]
    ::ww_gui_bhv.worldWarMapControls.selectAirfield.call(
      ::ww_gui_bhv.worldWarMapControls, mapObj, {airfieldIdx = index})
  }

  function selectDefaultFormation()
  {
    let placeObj = scene.findObject("free_formations")
    selectRadioButtonBlock(placeObj, 0)
  }

  function updateSelectedAirfield(selectedAirfield = -1)
  {
    if (ownedAirfieldsNumber != getAirfields().len())
      updateAirfields()

    for (local index = 0; index < ::ww_get_airfields_count(); index++)
    {
      let airfieldObj = scene.findObject(getAirfieldId(index))
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
