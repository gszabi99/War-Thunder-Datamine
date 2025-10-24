from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { hideBonus } = require("%scripts/bonusModule.nut")
let { format } = require("string")
let { trainCrewUnitWithoutSwitchCurrUnit, upgradeUnitSpec } = require("%scripts/crew/crewActionsWithMsgBox.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getCrewTrainCost, getCrewButtonRow } = require("%scripts/crew/crew.nut")
let { crewSpecTypes, getSpecTypeByCrewAndUnit } = require("%scripts/crew/crewSpecType.nut")
let { showAirDiscount } = require("%scripts/discounts/discountUtils.nut")

gui_handlers.CrewUnitSpecHandler <- class (gui_handlers.BaseGuiHandlerWT) {
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

    let rowIndex = getCrewButtonRow(obj, this.scene, this.scene) 
    let rowUnit = this.units?[rowIndex]
    if (rowUnit == null)
      return

    if (this.isRecrutedCurCrew()
      && rowUnit.isUsable()
      && getSpecTypeByCrewAndUnit(this.crew, rowUnit) == crewSpecTypes.UNKNOWN) {
        trainCrewUnitWithoutSwitchCurrUnit(this.crew, rowUnit)
        return
    }

    upgradeUnitSpec(this.crew, rowUnit)
  }

  function onButtonRowApply(obj) {
    this.applyRowButton(obj)
  }

  function increaseSpec(nextSpecType, obj = null) {
    let rowIndex = getCrewButtonRow(obj, this.scene, this.scene) 
    let rowUnit = this.units?[rowIndex]
    if (rowUnit)
      upgradeUnitSpec(this.crew, rowUnit, null, nextSpecType)
  }

  function onSpecIncrease1(obj) {
    this.increaseSpec(crewSpecTypes.EXPERT, obj)
  }

  function onSpecIncrease2(obj) {
    this.increaseSpec(crewSpecTypes.ACE, obj)
  }

  function getSpecRowConfig(idx) {
    let unit = this.units?[idx]
    if (!unit)
      return null

    let specType = getSpecTypeByCrewAndUnit(this.crew, unit)
    let hasNextType = specType.hasNextType()
    let nextType = specType.getNextType()
    let reqLevel = hasNextType ? nextType.getReqCrewLevel(unit) : 0
    let isRecrutedCrew = this.isRecrutedCurCrew()
    let needToTrainUnit = specType == crewSpecTypes.UNKNOWN
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
      unitName = getUnitName(unit.name)
      hasProgressBar = true
      rowTooltipId   = getTooltipType("CREW_SPECIALIZATION").getTooltipId(this.crew.id, unit.name)
      buySpecTooltipId1 = crewSpecTypes.EXPERT.getBtnBuyTooltipId(this.crew, unit)
      buySpecTooltipId2 = crewSpecTypes.ACE.getBtnBuyTooltipId(this.crew, unit)
      buySpecTooltipId = getTooltipType("BUY_CREW_SPEC").getTooltipId(this.crew.id, unit.name, -1)
      curValue = specType.getName()
      costText = hasNextType ? specType.getUpgradeCostByCrewAndByUnit(this.crew, unit).tostring()
        : canCrewTrainUnit ? getCrewTrainCost(this.crew, unit).getTextAccordingToBalance()
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
        this.getRowSpecButtonConfig(crewSpecTypes.EXPERT, this.crewLevel, unit, specType), 
        this.getRowSpecButtonConfig(crewSpecTypes.ACE, this.crewLevel, unit, specType) 
      ]
    }
  }

  function getRowSpecButtonConfig(specType, crewLvl, unit, curSpecType) {
    let icon = specType.getIcon(curSpecType.code, crewLvl, unit)
    return {
      id = specType.code
      icon = icon
      enable = (icon != "" && curSpecType.code < specType.code) ? "yes" : "no"
      isExpertSpecType = specType == crewSpecTypes.EXPERT
    }
  }

  function updateDiscounts() {
    foreach (idx, unit in this.units) {
      let rowObj = this.scene.findObject(this.getRowName(idx))
      if (!checkObj(rowObj))
        return

      let specType = getSpecTypeByCrewAndUnit(this.crew, unit)
      let discObj = rowObj.findObject("buy-discount")
      if (specType.hasNextType())
        showAirDiscount(discObj, unit.name, "specialization", specType.getNextType().specName)
      else
        hideBonus(discObj)
    }
  }

  isRecrutedCurCrew = @() this.crew.id != -1
}
