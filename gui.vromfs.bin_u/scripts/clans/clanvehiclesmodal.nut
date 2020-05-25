local vehiclesModal = require("scripts/unit/vehiclesModal.nut")
local unitActions = require("scripts/unit/unitActions.nut")
local squadronUnitAction = require("scripts/unit/squadronUnitAction.nut")
local { setColoredDoubleTextToButton, placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

local handlerClass = class extends vehiclesModal.handlerClass
{
  canQuitByGoBack       = false

  wndTitleLocId         = "clan/vehicles"
  slotbarActions        = [ "research", "buy", "take", "weapons", "info" ]
  unitsFilter = @(u) u.isVisibleInShop() && u.isSquadronVehicle() && ::canResearchUnit(u)

  hasSpendExpProcess = false

  function initScreen()
  {
    lastSelectedUnit = ::getAircraftByName(::clan_get_researching_unit())
    base.initScreen()
  }

  function getWndTitle()
  {
    if (::clan_get_researching_unit() == "")
      return null

    local locId = "shop/distributeSquadronExp"
    local flushExp = ::clan_get_exp()
    if (flushExp <= 0 || needChosenResearchOfSquadron())
      locId = "mainmenu/nextResearchSquadronVehicle"

    local expText = flushExp ? ::loc("ui/parentheses/space",
        {text = ::Balance(0, 0, 0, 0, flushExp).getTextAccordingToBalance()}) : ""
    expText = ::loc(locId) + expText

    return expText
  }

  function getNavBarView()
  {
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

  function updateButtons()
  {
    updateTitle()
    updateBuyBtn()
    updateSpendExpBtn()
  }

  function updateTitle()
  {
    local titleObj = scene.findObject("header_text")
    if (!::check_obj(titleObj))
      return

    titleObj.setValue(getWndTitle())
  }

  function updateBuyBtn()
  {
    if (!lastSelectedUnit)
      return showSceneBtn("btn_buy_unit", false)

    local canBuyIngame = ::canBuyUnit(lastSelectedUnit)
    local canBuyOnline = ::canBuyUnitOnline(lastSelectedUnit)
    local needShowBuyUnitBtn = canBuyIngame || canBuyOnline
    showSceneBtn("btn_buy_unit", needShowBuyUnitBtn)
    if (!needShowBuyUnitBtn)
      return

    local locText = ::loc("shop/btnOrderUnit", { unit = ::getUnitName(lastSelectedUnit.name) })
    local unitCost = (canBuyIngame && !canBuyOnline) ? ::getUnitCost(lastSelectedUnit) : ::Cost()
    placePriceTextToButton(scene.findObject("nav-help"),      "btn_buy_unit", locText, unitCost)
  }

  function updateSpendExpBtn()
  {
    if (!lastSelectedUnit)
      return showSceneBtn("btn_spend_exp", false)

    local flushExp = ::min(::clan_get_exp(), ::getUnitReqExp(lastSelectedUnit) - ::getUnitExp(lastSelectedUnit))
    local needShowSpendBtn = (flushExp > 0 || needChosenResearchOfSquadron())
      && lastSelectedUnit.isSquadronVehicle() && ::canResearchUnit(lastSelectedUnit)

    showSceneBtn("btn_spend_exp", needShowSpendBtn)
    if (!needShowSpendBtn)
      return

    local textWord = ::loc(
      (flushExp <= 0 || needChosenResearchOfSquadron())
        ? "shop/researchUnit"
        : "shop/investToUnit",
      { unit = ::getUnitName(lastSelectedUnit.name) })
    local textValue = flushExp > 0 ? ::loc("ui/parentheses/space",
      {text = ::Cost().setSap(flushExp).tostring()}) : ""
    local coloredText = textWord + textValue

    setColoredDoubleTextToButton(scene, "btn_spend_exp", coloredText)
  }

  function onSpendExcessExp()
  {
    if (hasSpendExpProcess)
      return

    local unit = lastSelectedUnit
    if (!unit?.isSquadronVehicle?() || !::canResearchUnit(unit))
      return

    hasSpendExpProcess = true
    local flushExp = ::min(::clan_get_exp(), ::getUnitReqExp(unit) - ::getUnitExp(unit))
    local canFlushExp = flushExp > 0

    local afterDoneFunc = function() {
      if (unit.isSquadronVehicle() && needChosenResearchOfSquadron())
        squadronUnitAction.saveResearchChosen(true)
      if(canFlushExp)
        return unitActions.flushSquadronExp(unit,
          {afterDoneFunc = ::Callback(function() {hasSpendExpProcess = false}, this)})

      hasSpendExpProcess = false
      goBack()
    }

    if (::isUnitInResearch(unit))
      afterDoneFunc()

    unitActions.research(unit, true, ::Callback(afterDoneFunc, this) )
  }

  getParamsForActionsList = @() {
    setResearchManually  = true
    isSquadronResearchMode = true
    needChosenResearchOfSquadron = needChosenResearchOfSquadron()
    isSlotbarEnabled = false
    onSpendExcessExp = ::Callback(onSpendExcessExp, this)
  }

  needChosenResearchOfSquadron = @() !squadronUnitAction.hasChosenResearch()

  function onBuy()
  {
    unitActions.buy(lastSelectedUnit, "clan_vehicles")
  }

  static function isHaveNonApprovedResearches()
  {
    if (!::isInMenu() || !::has_feature("ClanVehicles")
      || ::checkIsInQueue()
      || squadronUnitAction.isAllVehiclesResearched())
      return false

    local researchingUnitName = ::clan_get_researching_unit()
    if (researchingUnitName == "")
      return false

    local curSquadronExp = ::clan_get_exp()
    local hasChosenResearchOfSquadron = squadronUnitAction.hasChosenResearch()
    if (hasChosenResearchOfSquadron && curSquadronExp <=0)
      return false

    local unit = ::getAircraftByName(researchingUnitName)
    if (!unit || !unit.isVisibleInShop())
      return false

    if ((hasChosenResearchOfSquadron || !::is_in_clan())
      && (curSquadronExp <= 0 || curSquadronExp < unit.reqExp - ::getUnitExp(unit)))
      return false

    return true
  }

  function onEventFlushSquadronExp(params)
  {
    local unit = params?.unit
    if (::clan_get_researching_unit() != "" && ::isUnitResearched(unit) && ::clan_get_exp() > 0)
      return base.onEventFlushSquadronExp(params)

    if (squadronUnitAction.isAllVehiclesResearched())
      squadronUnitAction.saveResearchChosen(false)

    if (unit && ::canBuyUnit(unit))
      ::buyUnit(unit)
    goBack()
  }

  function onEventUnitBought(p)
  {
    if (squadronUnitAction.isAllVehiclesResearched())
      return goBack()

    base.onEventFlushSquadronExp(p)
  }
}

::gui_handlers.clanVehiclesModal <- handlerClass

return {
  open = @() ::handlersManager.loadHandler(handlerClass)
  isHaveNonApprovedResearches = handlerClass.isHaveNonApprovedResearches
}
