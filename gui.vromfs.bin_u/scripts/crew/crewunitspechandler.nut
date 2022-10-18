from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { trainCrewUnitWithoutSwitchCurrUnit } = require("%scripts/crew/crewActions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.CrewUnitSpecHandler <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/empty.blk"
  crew = null
  crewLevel = null
  units = null
  curCrewUnitType = null
  isHandlerVisible = true

  function setHandlerVisible(value)
  {
    isHandlerVisible = value
    this.scene.show(value)
    this.scene.enable(value)
  }

  function setHandlerData(newCrew, newCrewLevel, newUnits, newCrewUnitType)
  {
    crew = newCrew
    crewLevel = newCrewLevel
    units = newUnits
    curCrewUnitType = newCrewUnitType

    loadSceneTpl()
    updateDiscounts()

    let totalRows = this.scene.childrenCount()
    if (totalRows > 0 && totalRows <= this.scene.getValue())
      this.scene.setValue(0)
  }

  function loadSceneTpl()
  {
    let rows = []
    foreach(i, _unit in units)
      rows.append(getSpecRowConfig(i))

    local data = ::handyman.renderCached("%gui/crew/crewAirRow", { rows = rows })
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
  }

  function getRowName(rowIndex)
  {
    return format("skill_row%d", rowIndex)
  }

  function applyRowButton(obj)
  {
    // Here 'scene' is table object with id "specs_table".
    if (!checkObj(obj) || obj?.id != "buttonRowApply")
    {
      if (!checkObj(this.scene))
        return
      let idx = this.scene.getValue()
      let rowObj = this.scene.getChild(idx)
      if (!checkObj(rowObj))
        return
      obj = rowObj.findObject("buttonRowApply")
    }

    if (!checkObj(obj) || !obj.isEnabled())
      return

    let rowIndex = ::g_crew.getButtonRow(obj, this.scene, this.scene)
    let rowUnit = getTblValue(rowIndex, units)
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
    let rowIndex = ::g_crew.getButtonRow(obj, this.scene, this.scene)
    let rowUnit = getTblValue(rowIndex, units)
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
    let unit = units?[idx]
    if (!unit)
      return null

    let specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
    let hasNextType = specType.hasNextType()
    let nextType = specType.getNextType()
    let reqLevel = hasNextType ? nextType.getReqCrewLevel(unit) : 0
    let isRecrutedCrew = isRecrutedCurCrew()
    let needToTrainUnit = specType == ::g_crew_spec_type.UNKNOWN
    let isUsableUnit = unit.isUsable()
    let canCrewTrainUnit = isRecrutedCrew && needToTrainUnit
      && isUsableUnit
    let enableForBuy = !needToTrainUnit && reqLevel <= crewLevel
    let isProgressBarVisible = specType.needShowExpUpgrade(crew, unit)
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
          : loc("crew/qualifyRequirement", { reqLevel = reqLevel })
        : canCrewTrainUnit ? loc("mainmenu/btnTrainCrew")
        : isRecrutedCrew && !isUsableUnit ? loc("weaponry/unit_not_bought")
        : ""
      progressBarDisplay = isProgressBarVisible ? "show" : "hide"
      progressBarValue = progressBarValue

      btnSpec = [
        getRowSpecButtonConfig(::g_crew_spec_type.EXPERT, crewLevel, unit, specType), // warning disable: -param-pos
        getRowSpecButtonConfig(::g_crew_spec_type.ACE, crewLevel, unit, specType) // warning disable: -param-pos
      ]
    }
  }

  function getRowSpecButtonConfig(specType, crewLvl, unit, curSpecType)
  {
    let icon = specType.getIcon(curSpecType.code, crewLvl, unit)
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
      let rowObj = this.scene.findObject(getRowName(idx))
      if (!checkObj(rowObj))
        return

      let specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
      let discObj = rowObj.findObject("buy-discount")
      if (specType.hasNextType())
        ::showAirDiscount(discObj, unit.name, "specialization", specType.getNextType().specName)
      else
        ::hideBonus(discObj)
    }
  }

  isRecrutedCurCrew = @() crew.id != -1
}
