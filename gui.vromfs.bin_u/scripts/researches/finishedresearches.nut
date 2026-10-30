import "%scripts/slotbar/guiStartSelectingCrew.nut" as guiStartSelectingCrew
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/slotbar/slotbarView.nut" import buildUnitSlot, fillUnitSlotTimers
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/unit/unitShopInfo.nut" import isUnitBought
from "%scripts/unit/unitStatus.nut" import isUnitUsable
from "%scripts/unit/unitActions.nut" import buyUnit
from "%scripts/dagui_library.nut" import *

let { RESEARCHED_UNIT_FOR_CHECK } = require ("%scripts/researches/researchConsts.nut")

let researchUnitNotification = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/researchedModifications.blk"

  researchBlock = null
  unit = null

  function initScreen() {
    if (!this.researchBlock) {
      this.goBack()
      return
    }

    let unitName = this.researchBlock?[RESEARCHED_UNIT_FOR_CHECK]
    this.unit = getAircraftByName(unitName)
    if (!this.unit) {
      this.goBack()
      return
    }

    this.updateResearchedUnit()
    this.updateButtons()
  }

  function updateResearchedUnit() {
    let placeObj = this.getUnitPlaceObj()
    if (!checkObj(placeObj))
      return

    let unit_blk = buildUnitSlot(this.unit.name, this.unit, {
      tooltipParams = { canOpenOtherWindows = false }
    })
    this.guiScene.replaceContentFromText(placeObj, unit_blk, unit_blk.len(), this)
    placeObj.tooltipId = getTooltipType("UNIT").getTooltipId(this.unit.name)
    fillUnitSlotTimers(placeObj.findObject(this.unit.name), this.unit)
  }

  function onEventCrewTakeUnit(_params) {
    this.goBack()
  }

  function onEventUnitBought(params) {
    let { unitName = null, needSelectCrew = false } = params
    if (unitName != this.unit.name) {
      this.purchaseUnit()
      return
    }

    if (!needSelectCrew) {
      this.goBack()
      return
    }

    this.updateResearchedUnit()
    this.updateButtons()
    this.trainCrew()
  }

  function getUnitPlaceObj() {
    if (!checkObj(this.scene))
      return null

    return this.scene.findObject("rankup_aircraft_table")
  }

  function updateButtons() {
    let isBought = isUnitBought(this.unit)
    let isUsable = isUnitUsable(this.unit)

    showObjById("btn_buy", !isBought, this.scene)
    showObjById("btn_exit", isBought, this.scene)
    showObjById("btn_trainCrew", isUsable, this.scene)
  }

  function purchaseUnit() {
    buyUnit(this.unit)
  }

  function trainCrew() {
    if (!isUnitUsable(this.unit))
      return

    guiStartSelectingCrew({
      unit = this.unit
      unitObj = this.scene.findObject(this.unit.name)
      cellClass = "slotbarClone"
      isNewUnit = true
    })
  }
}
register_gui_handler("researchUnitNotification", researchUnitNotification)

return freeze({ researchUnitNotification })
