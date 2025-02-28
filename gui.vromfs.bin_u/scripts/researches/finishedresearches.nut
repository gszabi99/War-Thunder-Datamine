from "%scripts/dagui_natives.nut" import shop_set_researchable_unit_module, shop_get_units_list_with_autoset_modules, get_auto_buy_modifications, shop_get_countries_list_with_autoset_units
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let guiStartSelectingCrew = require("%scripts/slotbar/guiStartSelectingCrew.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let { isUnitUsable } = require("%scripts/unit/unitStatus.nut")
let { buyUnit } = require("%scripts/unit/unitActions.nut")
let { RESEARCHED_UNIT_FOR_CHECK } = require ("%scripts/researches/researchConsts.nut")

gui_handlers.researchUnitNotification <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/researchedModifications.blk"

  researchBlock = null
  unit = null

  function initScreen() {
    if (!this.researchBlock) {
      this.goBack()
      return
    }

    let unitName = getTblValue(RESEARCHED_UNIT_FOR_CHECK, this.researchBlock)
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

    let unit_blk = buildUnitSlot(this.unit.name, this.unit)
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