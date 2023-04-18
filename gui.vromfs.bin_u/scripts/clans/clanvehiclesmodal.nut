//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let vehiclesModal = require("%scripts/unit/vehiclesModal.nut")
let unitActions = require("%scripts/unit/unitActions.nut")
let { isAllClanUnitsResearched } = require("%scripts/unit/squadronUnitAction.nut")
let { setColoredDoubleTextToButton, placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")

local handlerClass = class extends vehiclesModal.handlerClass {
  canQuitByGoBack       = false

  wndTitleLocId         = "clan/vehicles"
  slotbarActions        = [ "research", "buy", "take", "info" ]
  unitsFilter = @(u) u.isVisibleInShop() && u.isSquadronVehicle() && ::canResearchUnit(u)

  hasSpendExpProcess = false

  function initScreen() {
    this.lastSelectedUnit = ::getAircraftByName(::clan_get_researching_unit())
    base.initScreen()
  }

  function getWndTitle() {
    local locId = "shop/distributeSquadronExp"
    let flushExp = ::clan_get_exp()
    if (flushExp <= 0 || this.needChosenResearchOfSquadron())
      locId = "mainmenu/nextResearchSquadronVehicle"

    local expText = flushExp ? loc("ui/parentheses/space",
        { text = ::Balance(0, 0, 0, 0, flushExp).getTextAccordingToBalance() }) : ""
    expText = loc(locId) + expText

    return expText
  }

  function getNavBarView() {
    return {
      right = [
        {
          id = "btn_spend_exp"
          text = "#mainmenu/btnApply"
          shortcut = "X"
          funcName = "onSpendExcessExp"
          button = true
          visualStyle = "secondary"
        },
        {
          id = "btn_buy_unit"
          text = "#shop/btnOrderUnit"
          shortcut = "X"
          funcName = "onBuy"
          button = true
          visualStyle = "purchase"
        }
      ]
    }
  }

  function updateButtons() {
    this.updateTitle()
    this.updateBuyBtn()
    this.updateSpendExpBtn()
  }

  function updateTitle() {
    let titleObj = this.scene.findObject("header_text")
    if (!checkObj(titleObj))
      return

    titleObj.setValue(this.getWndTitle())
  }

  function updateBuyBtn() {
    if (!this.lastSelectedUnit)
      return this.showSceneBtn("btn_buy_unit", false)

    let canBuyIngame = ::canBuyUnit(this.lastSelectedUnit)
    let canBuyOnline = ::canBuyUnitOnline(this.lastSelectedUnit)
    let needShowBuyUnitBtn = canBuyIngame || canBuyOnline
    this.showSceneBtn("btn_buy_unit", needShowBuyUnitBtn)
    if (!needShowBuyUnitBtn)
      return

    let locText = loc("shop/btnOrderUnit", { unit = ::getUnitName(this.lastSelectedUnit.name) })
    let unitCost = (canBuyIngame && !canBuyOnline) ? ::getUnitCost(this.lastSelectedUnit) : ::Cost()
    placePriceTextToButton(this.scene.findObject("nav-help"),      "btn_buy_unit", locText, unitCost)
  }

  function updateSpendExpBtn() {
    if (!this.lastSelectedUnit)
      return this.showSceneBtn("btn_spend_exp", false)

    let flushExp = min(::clan_get_exp(), ::getUnitReqExp(this.lastSelectedUnit) - ::getUnitExp(this.lastSelectedUnit))
    let needShowSpendBtn = (flushExp > 0 || this.needChosenResearchOfSquadron())
      && this.lastSelectedUnit.isSquadronVehicle() && ::canResearchUnit(this.lastSelectedUnit)

    this.showSceneBtn("btn_spend_exp", needShowSpendBtn)
    if (!needShowSpendBtn)
      return

    let textWord = loc(
      (flushExp <= 0 || this.needChosenResearchOfSquadron())
        ? "shop/researchUnit"
        : "shop/investToUnit",
      { unit = ::getUnitName(this.lastSelectedUnit.name) })
    let textValue = flushExp > 0 ? loc("ui/parentheses/space",
      { text = ::Cost().setSap(flushExp).tostring() }) : ""
    let coloredText = textWord + textValue

    setColoredDoubleTextToButton(this.scene, "btn_spend_exp", coloredText)
  }

  function onSpendExcessExp() {
    if (this.hasSpendExpProcess)
      return

    let unit = this.lastSelectedUnit
    if (!unit?.isSquadronVehicle?() || !::canResearchUnit(unit))
      return

    this.hasSpendExpProcess = true

    let afterDoneFunc = Callback(function() { this.hasSpendExpProcess = false }, this)
    if (!::isUnitInResearch(unit)) {
      unitActions.setResearchClanVehicleWithAutoFlush(unit, afterDoneFunc)
      return
    }

    let flushExp = min(::clan_get_exp(), ::getUnitReqExp(unit) - ::getUnitExp(unit))
    if (flushExp > 0) {
      unitActions.flushSquadronExp(unit, { afterDoneFunc })
      return
    }
    this.hasSpendExpProcess = false
    this.goBack()
  }

  getParamsForActionsList = @() {
    setResearchManually  = true
    isSquadronResearchMode = true
    needChosenResearchOfSquadron = this.needChosenResearchOfSquadron()
    isSlotbarEnabled = false
    onSpendExcessExp = Callback(this.onSpendExcessExp, this)
  }

  needChosenResearchOfSquadron = @() ::clan_get_researching_unit() == ""

  function onBuy() {
    unitActions.buy(this.lastSelectedUnit, "clan_vehicles")
  }

  function onEventFlushSquadronExp(params) {
    let unit = params?.unit
    let isAllResearched = isAllClanUnitsResearched()
    if (!isAllResearched && ::clan_get_exp() > 0)
      return base.onEventFlushSquadronExp(params)

    if (unit && ::canBuyUnit(unit))
      ::buyUnit(unit)
    this.goBack()
  }

  function onEventUnitBought(p) {
    if (isAllClanUnitsResearched())
      return this.goBack()

    base.onEventFlushSquadronExp(p)
  }

  function onEventUnitResearch(p) {
    base.onEventUnitResearch(p)
    this.onEventFlushSquadronExp(p)
  }

}

::gui_handlers.clanVehiclesModal <- handlerClass

return {
  open = @() ::handlersManager.loadHandler(handlerClass)
}
