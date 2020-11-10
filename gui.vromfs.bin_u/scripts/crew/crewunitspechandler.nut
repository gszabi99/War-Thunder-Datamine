local { trainCrewUnitWithoutSwitchCurrUnit } = require("scripts/crew/crewActions.nut")

class ::gui_handlers.CrewUnitSpecHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/empty.blk"
  crew = null
  crewLevel = null
  units = null
  curCrewUnitType = null
  isHandlerVisible = true

  function setHandlerVisible(value)
  {
    isHandlerVisible = value
    scene.show(value)
    scene.enable(value)
  }

  function setHandlerData(newCrew, newCrewLevel, newUnits, newCrewUnitType)
  {
    crew = newCrew
    crewLevel = newCrewLevel
    units = newUnits
    curCrewUnitType = newCrewUnitType

    loadSceneTpl()
    updateDiscounts()

    local totalRows = scene.childrenCount()
    if (totalRows > 0 && totalRows <= scene.getValue())
      scene.setValue(0)
  }

  function loadSceneTpl()
  {
    local rows = []
    foreach(i, unit in units)
      rows.append(getSpecRowConfig(i))

    local data = ::handyman.renderCached("gui/crew/crewAirRow", { rows = rows })
    guiScene.replaceContentFromText(scene, data, data.len(), this)
  }

  function getRowName(rowIndex)
  {
    return ::format("skill_row%d", rowIndex)
  }

  function applyRowButton(obj)
  {
    // Here 'scene' is table object with id "specs_table".
    if (!checkObj(obj) || obj?.id != "buttonRowApply")
    {
      if (!::checkObj(scene))
        return
      local idx = scene.getValue()
      local rowObj = scene.getChild(idx)
      if (!::checkObj(rowObj))
        return
      obj = rowObj.findObject("buttonRowApply")
    }

    if (!checkObj(obj) || !obj.isEnabled())
      return

    local rowIndex = ::g_crew.getButtonRow(obj, scene, scene)
    local rowUnit = ::getTblValue(rowIndex, units)
    if (rowUnit == null)
      return

    if (isRecrutedCurCrew()
      && rowUnit.isUsable()
      && ::g_crew_spec_type.getTypeByCrewAndUnit(crew, rowUnit) == ::g_crew_spec_type.UNKNOWN) {
        trainCrewUnitWithoutSwitchCurrUnit(crew, rowUnit)
        return
    }

    ::g_crew.upgradeUnitSpec(crew, rowUnit)
  }

  function onButtonRowApply(obj)
  {
    applyRowButton(obj)
  }

  function increaseSpec(nextSpecType, obj = null)
  {
    local rowIndex = ::g_crew.getButtonRow(obj, scene, scene)
    local rowUnit = ::getTblValue(rowIndex, units)
    if (rowUnit)
      ::g_crew.upgradeUnitSpec(crew, rowUnit, null, nextSpecType)
  }

  function onSpecIncrease1(obj)
  {
    increaseSpec(::g_crew_spec_type.EXPERT, obj)
  }

  function onSpecIncrease2(obj)
  {
    increaseSpec(::g_crew_spec_type.ACE, obj)
  }

  function getSpecRowConfig(idx)
  {
    local unit = units?[idx]
    if (!unit)
      return null

    local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
    local hasNextType = specType.hasNextType()
    local nextType = specType.getNextType()
    local reqLevel = hasNextType ? nextType.getReqCrewLevel(unit) : 0
    local isRecrutedCrew = isRecrutedCurCrew()
    local needToTrainUnit = specType == ::g_crew_spec_type.UNKNOWN
    local isUsableUnit = unit.isUsable()
    local canCrewTrainUnit = isRecrutedCrew && needToTrainUnit
      && isUsableUnit
    local enableForBuy = !needToTrainUnit && reqLevel <= crewLevel
    local isProgressBarVisible = specType.needShowExpUpgrade(crew, unit)
    local progressBarValue = 0
    if (isProgressBarVisible)
      progressBarValue = 1000 * specType.getExpLeftByCrewAndUnit(crew, unit)
        / specType.getTotalExpByUnit(unit)

    return {
      id = getRowName(idx)
      even = idx % 2 == 0
      holderId = idx
      unitName = ::getUnitName(unit.name)
      hasProgressBar = true
      rowTooltipId   = ::g_tooltip.getIdCrewSpecialization(crew.id, unit.name, -1)
      buySpecTooltipId1 = ::g_crew_spec_type.EXPERT.getBtnBuyTooltipId(crew, unit)
      buySpecTooltipId2 = ::g_crew_spec_type.ACE.getBtnBuyTooltipId(crew, unit)
      buySpecTooltipId = ::g_tooltip.getIdBuyCrewSpec(crew.id, unit.name, -1)
      curValue = specType.getName()
      costText = hasNextType ? specType.getUpgradeCostByCrewAndByUnit(crew, unit).tostring()
        : canCrewTrainUnit ? ::g_crew.getCrewTrainCost(crew, unit).getTextAccordingToBalance()
        : ""
      enableForBuy = enableForBuy || canCrewTrainUnit
      buttonRowDisplay = (hasNextType || canCrewTrainUnit
        || (isRecrutedCrew && !isUsableUnit)) ? "show" : "hide"
      buttonRowText = hasNextType
        ? enableForBuy
          ? specType.getButtonLabel()
          : ::loc("crew/qualifyRequirement", { reqLevel = reqLevel })
        : canCrewTrainUnit ? ::loc("mainmenu/btnTrainCrew")
        : isRecrutedCrew && !isUsableUnit ? ::loc("weaponry/unit_not_bought")
        : ""
      progressBarDisplay = isProgressBarVisible ? "show" : "hide"
      progressBarValue = progressBarValue

      btnSpec = [
        getRowSpecButtonConfig(::g_crew_spec_type.EXPERT, crewLevel, unit, specType),
        getRowSpecButtonConfig(::g_crew_spec_type.ACE, crewLevel, unit, specType)
      ]
    }
  }

  function getRowSpecButtonConfig(specType, crewLvl, unit, curSpecType)
  {
    local icon = specType.getIcon(curSpecType.code, crewLvl, unit)
    return {
      id = specType.code
      icon = icon
      enable = (icon != "" && curSpecType.code < specType.code) ? "yes" : "no"
      isExpertSpecType = specType == ::g_crew_spec_type.EXPERT
    }
  }

  function updateDiscounts()
  {
    foreach(idx, unit in units)
    {
      local rowObj = scene.findObject(getRowName(idx))
      if (!::checkObj(rowObj))
        return

      local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
      local discObj = rowObj.findObject("buy-discount")
      if (specType.hasNextType())
        ::showAirDiscount(discObj, unit.name, "specialization", specType.getNextType().specName)
      else
        ::hideBonus(discObj)
    }
  }

  isRecrutedCurCrew = @() crew.id != -1
}
