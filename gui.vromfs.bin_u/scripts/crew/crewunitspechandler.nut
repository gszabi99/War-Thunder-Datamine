//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

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

  function setHandlerVisible(value) {
    this.isHandlerVisible = value
    this.scene.show(value)
    this.scene.enable(value)
  }

  function setHandlerData(newCrew, newCrewLevel, newUnits, newCrewUnitType) {
    this.crew = newCrew
    this.crewLevel = newCrewLevel
    this.units = newUnits
    this.curCrewUnitType = newCrewUnitType

    this.loadSceneTpl()
    this.updateDiscounts()

    let totalRows = this.scene.childrenCount()
    if (totalRows > 0 && totalRows <= this.scene.getValue())
      this.scene.setValue(0)
  }

  function loadSceneTpl() {
    let rows = []
    foreach (i, _unit in this.units)
      rows.append(this.getSpecRowConfig(i))

    local data = handyman.renderCached("%gui/crew/crewAirRow.tpl", { rows = rows })
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
  }

  function getRowName(rowIndex) {
    return format("skill_row%d", rowIndex)
  }

  function applyRowButton(obj) {
    // Here 'scene' is table object with id "specs_table".
    if (!checkObj(obj) || obj?.id != "buttonRowApply") {
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
    let rowUnit = getTblValue(rowIndex, this.units)
    if (rowUnit == null)
      return

    if (this.isRecrutedCurCrew()
      && rowUnit.isUsable()
      && ::g_crew_spec_type.getTypeByCrewAndUnit(this.crew, rowUnit) == ::g_crew_spec_type.UNKNOWN) {
        trainCrewUnitWithoutSwitchCurrUnit(this.crew, rowUnit)
        return
    }

    ::g_crew.upgradeUnitSpec(this.crew, rowUnit)
  }

  function onButtonRowApply(obj) {
    this.applyRowButton(obj)
  }

  function increaseSpec(nextSpecType, obj = null) {
    let rowIndex = ::g_crew.getButtonRow(obj, this.scene, this.scene)
    let rowUnit = getTblValue(rowIndex, this.units)
    if (rowUnit)
      ::g_crew.upgradeUnitSpec(this.crew, rowUnit, null, nextSpecType)
  }

  function onSpecIncrease1(obj) {
    this.increaseSpec(::g_crew_spec_type.EXPERT, obj)
  }

  function onSpecIncrease2(obj) {
    this.increaseSpec(::g_crew_spec_type.ACE, obj)
  }

  function getSpecRowConfig(idx) {
    let unit = this.units?[idx]
    if (!unit)
      return null

    let specType = ::g_crew_spec_type.getTypeByCrewAndUnit(this.crew, unit)
    let hasNextType = specType.hasNextType()
    let nextType = specType.getNextType()
    let reqLevel = hasNextType ? nextType.getReqCrewLevel(unit) : 0
    let isRecrutedCrew = this.isRecrutedCurCrew()
    let needToTrainUnit = specType == ::g_crew_spec_type.UNKNOWN
    let isUsableUnit = unit.isUsable()
    let canCrewTrainUnit = isRecrutedCrew && needToTrainUnit
      && isUsableUnit
    let enableForBuy = !needToTrainUnit && reqLevel <= this.crewLevel
    let isProgressBarVisible = specType.needShowExpUpgrade(this.crew, unit)
    local progressBarValue = 0
    if (isProgressBarVisible)
      progressBarValue = 1000 * specType.getExpLeftByCrewAndUnit(this.crew, unit)
        / specType.getTotalExpByUnit(unit)

    return {
      id = this.getRowName(idx)
      even = idx % 2 == 0
      holderId = idx
      unitName = ::getUnitName(unit.name)
      hasProgressBar = true
      rowTooltipId   = ::g_tooltip.getIdCrewSpecialization(this.crew.id, unit.name, -1)
      buySpecTooltipId1 = ::g_crew_spec_type.EXPERT.getBtnBuyTooltipId(this.crew, unit)
      buySpecTooltipId2 = ::g_crew_spec_type.ACE.getBtnBuyTooltipId(this.crew, unit)
      buySpecTooltipId = ::g_tooltip.getIdBuyCrewSpec(this.crew.id, unit.name, -1)
      curValue = specType.getName()
      costText = hasNextType ? specType.getUpgradeCostByCrewAndByUnit(this.crew, unit).tostring()
        : canCrewTrainUnit ? ::g_crew.getCrewTrainCost(this.crew, unit).getTextAccordingToBalance()
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
        this.getRowSpecButtonConfig(::g_crew_spec_type.EXPERT, this.crewLevel, unit, specType), // warning disable: -param-pos
        this.getRowSpecButtonConfig(::g_crew_spec_type.ACE, this.crewLevel, unit, specType) // warning disable: -param-pos
      ]
    }
  }

  function getRowSpecButtonConfig(specType, crewLvl, unit, curSpecType) {
    let icon = specType.getIcon(curSpecType.code, crewLvl, unit)
    return {
      id = specType.code
      icon = icon
      enable = (icon != "" && curSpecType.code < specType.code) ? "yes" : "no"
      isExpertSpecType = specType == ::g_crew_spec_type.EXPERT
    }
  }

  function updateDiscounts() {
    foreach (idx, unit in this.units) {
      let rowObj = this.scene.findObject(this.getRowName(idx))
      if (!checkObj(rowObj))
        return

      let specType = ::g_crew_spec_type.getTypeByCrewAndUnit(this.crew, unit)
      let discObj = rowObj.findObject("buy-discount")
      if (specType.hasNextType())
        ::showAirDiscount(discObj, unit.name, "specialization", specType.getNextType().specName)
      else
        ::hideBonus(discObj)
    }
  }

  isRecrutedCurCrew = @() this.crew.id != -1
}
