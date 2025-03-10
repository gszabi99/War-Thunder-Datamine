from "%scripts/dagui_natives.nut" import shop_get_country_excess_exp, shop_get_researchable_unit_name, is_era_available, shop_reset_researchable_unit, set_char_cb
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/rawShortcuts.nut" import GAMEPAD_ENTER_SHORTCUT
from "%scripts/utils_sa.nut" import get_flush_exp_text

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let tutorialModule = require("%scripts/user/newbieTutorialDisplay.nut")
let { research, flushExcessExpToUnit, CheckFeatureLockAction, checkFeatureLock } = require("%scripts/unit/unitActions.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { setColoredDoubleTextToButton, placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getUnitName, getUnitCountry, getUnitsNeedBuyToOpenNextInEra,
  getUnitReqExp, getUnitExp, getUnitCost
} = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { canBuyUnit } = require("%scripts/unit/unitShopInfo.nut")
let { canResearchUnit, isUnitGroup, isGroupPart, isUnitFeatureLocked, isUnitResearched,
  isPrevUnitBought
} = require("%scripts/unit/unitStatus.nut")
let { get_ranks_blk } = require("blkGetters")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { GuiBox } = require("%scripts/guiBox.nut")
let { gui_modal_tutor } = require("%scripts/guiTutorial.nut")
let { RESEARCHED_UNIT_FOR_CHECK } = require ("%scripts/researches/researchConsts.nut")
let { checkNonApprovedResearches } = require("%scripts/researches/researchActions.nut")

gui_handlers.ShopCheckResearch <- class (gui_handlers.ShopMenuHandler) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/shop/shopCheckResearch.tpl"
  sceneNavBlkName = "%gui/shop/shopNav.blk"
  shouldBlurSceneBgFn = needUseHangarDof
  canQuitByGoBack = false

  researchedUnit = null
  researchBlock = null

  curResearchingUnit = null
  lastResearchUnit = null
  unitCountry = ""
  unitType = ""

  setResearchManually = false
  showRankLockedMsgBoxOnce = false

  shopResearchMode = true
  slotbarActions = [ "research", "buy", "take", "sec_weapons", "info", "repair" ]

  function getSceneTplView() {
    return {
      hasMaxWindowSize = isSmallScreen
      hideGamercard = true
    }
  }

  function initScreen() {
    let unitName = this.researchBlock?[RESEARCHED_UNIT_FOR_CHECK]
    this.unitCountry = this.researchBlock.country
    if (unitName) {
      this.curAirName = unitName
      this.researchedUnit = getAircraftByName(unitName)
      this.unitType = getEsUnitType(this.researchedUnit)
      this.sendUnitResearchedStatistic(this.researchedUnit)
      this.updateResearchVariables()
    }

    base.initScreen()

    showObjById("modesRadiobuttons", false, this.scene)

    if (!isSmallScreen)
      this.createSlotbar(
        {
          showNewSlot = true,
          showEmptySlot = true,
          isCountryChoiceAllowed = false,
          customCountry = this.unitCountry,
          showTopPanel = false
        },
        "slotbar_place")

    this.selectRequiredUnit()
  }

  function getNotResearchedUnitByFeature() {
    foreach (unit in getAllUnits())
      if ((!this.unitCountry || getUnitCountry(unit) == this.unitCountry)
           && (this.unitType == null || getEsUnitType(unit) == this.unitType)
           && isUnitFeatureLocked(unit)
         )
        return unit
    return null
  }

  function getMaxEraAvailableByCountry() {
    for (local era = 1; era <= MAX_COUNTRY_RANK; era++)
      if (!is_era_available(this.unitCountry, era, this.unitType))
        return (era - 1)
    return MAX_COUNTRY_RANK
  }

  function showRankRestrictionMsgBox() {
    if (!this.hasNextResearch() || this.showRankLockedMsgBoxOnce || !this.isSceneActiveNoModals())
      return

    this.showRankLockedMsgBoxOnce = true

    let rank = this.getMaxEraAvailableByCountry()
    let nextRank = rank + 1

    if (nextRank > MAX_COUNTRY_RANK)
      return

    let unitLockedByFeature = this.getNotResearchedUnitByFeature()
    if (unitLockedByFeature && !checkFeatureLock(unitLockedByFeature, CheckFeatureLockAction.RESEARCH))
      return

    let ranksBlk = get_ranks_blk()
    let unitsCount = this.boughtVehiclesCount[rank]
    let unitsNeed = getUnitsNeedBuyToOpenNextInEra(this.unitCountry, this.unitType, rank, ranksBlk)
    let reqUnits = max(0, unitsNeed - unitsCount)
    if (reqUnits > 0) {
      let text = "\n".concat(loc("shop/unlockTier/locked", { rank = get_roman_numeral(nextRank) }),
        loc("shop/unlockTier/reqBoughtUnitsPrevRank", { amount = reqUnits, prevRank = get_roman_numeral(rank) }))
      this.msgBox("locked_rank", text, [["ok", function() {}]], "ok", { cancel_fn = function() {} })
    }
  }

  function updateHeaderText() {
    let headerObj = this.scene.findObject("shop_header")
    if (!checkObj(headerObj))
      return

    let expText = get_flush_exp_text(this.availableFlushExp)
    local headerText = loc("mainmenu/nextResearch/title")
    if (expText != "")
      headerText = "".concat(headerText, loc("ui/parentheses/space", { text = expText }))
    headerObj.setValue(headerText)
  }

  function updateResearchVariables() {
    this.updateCurResearchingUnit()
    this.updateExcessExp()
  }

  function updateCurResearchingUnit() {
    let curUnitName = shop_get_researchable_unit_name(this.unitCountry, this.unitType)
    if (curUnitName == getTblValue("name", this.curResearchingUnit, ""))
      return

    this.curResearchingUnit = getAircraftByName(curUnitName)
  }

  function updateExcessExp() {
    this.availableFlushExp = shop_get_country_excess_exp(this.unitCountry, this.unitType)
    this.updateHeaderText()
  }

  function hasNextResearch() {
    return this.availableFlushExp > 0 &&
      (this.curResearchingUnit == null || isUnitResearched(this.curResearchingUnit))
  }

  function getMaxRankUnboughtUnitByCountry() {
    local unit = null
    foreach (newUnit in getAllUnits())
      if (!this.unitCountry || this.unitCountry == getUnitCountry(newUnit))
        if (getTblValue("rank", newUnit, 0) > getTblValue("rank", unit, 0))
          if (this.unitType == getEsUnitType(newUnit)
              && !isUnitSpecial(newUnit)
              && canBuyUnit(newUnit)
              && isPrevUnitBought(newUnit))
            unit = newUnit
    return unit
  }

  function getMaxRankResearchingUnitByCountry() {
    local unit = null
    foreach (newUnit in getAllUnits())
      if (this.unitCountry == getUnitCountry(newUnit) && !newUnit.isSquadronVehicle()
        && this.unitType == getEsUnitType(newUnit) && canResearchUnit(newUnit))
          unit = newUnit.rank > (unit?.rank ?? 0) ? newUnit : unit
    return unit
  }

  function selectRequiredUnit() {
    local unit = null
    if (this.availableFlushExp > 0) {
      if (this.curResearchingUnit && !isUnitResearched(this.curResearchingUnit))
        unit = this.curResearchingUnit
      else {
        unit = this.getMaxRankResearchingUnitByCountry()
        this.setUnitOnResearch(unit)
      }
    }
    else if (!this.curResearchingUnit || isUnitResearched(this.curResearchingUnit)) {
      let nextResearchingUnit = this.getMaxRankResearchingUnitByCountry()
      if (nextResearchingUnit)
        unit = nextResearchingUnit
      else
        unit = this.getMaxRankUnboughtUnitByCountry()
    }
    else
      unit = this.curResearchingUnit

    if (!unit) {
      this.guiScene.performDelayed(this, function() {
        if (!this.isSceneActiveNoModals())
          return
        this.showRankRestrictionMsgBox()
      })
      return unit
    }

    this.destroyGroupChoose(isGroupPart(unit) ? unit.group : "")

    if (isGroupPart(unit))
      this.guiScene.performDelayed(this, function() {
        if (!this.isSceneActiveNoModals())
          return
        this.checkSelectAirGroup(this.getItemBlockFromShopTree(unit.group), unit.name)
      })

    this.selectCellByUnitName(unit.name)
    return unit
  }

  function showResearchUnitTutorial() {
    if (!tutorialModule.needShowTutorial("researchUnit", 1))
      return

    tutorialModule.saveShowedTutorial("researchUnit")

    let visibleObj = this.scene.findObject("shop_items_visible_div")
    if (!visibleObj)
      return

    let visibleBox = GuiBox().setFromDaguiObj(visibleObj)
    let unitsObj = []
    foreach (newUnit in getAllUnits())
      if (this.unitCountry == getUnitCountry(newUnit) && !newUnit.isSquadronVehicle()
        && this.unitType == getEsUnitType(newUnit) && canResearchUnit(newUnit)) {
        local newUnitName = ""
        if (isGroupPart(newUnit))
          newUnitName = newUnit.group
        else
          newUnitName = newUnit.name

        let unitObj = this.scene.findObject(newUnitName)
        if (unitObj) {
          let unitBox = GuiBox().setFromDaguiObj(unitObj)
          if (unitBox.isInside(visibleBox))
            unitsObj.append(unitObj)
        }
      }
    unitsObj.append("btn_spend_exp")

    let steps = [
      {
        obj = unitsObj
        text = loc("tutorials/research_next_aircraft")
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        haveArrow = false
        shortcut = GAMEPAD_ENTER_SHORTCUT
      }]
    gui_modal_tutor(steps, this)
  }

  function onUnitSelect() {
    this.updateButtons()
  }

  function getDefaultUnitInGroup(unitGroup) {
    let unitsList = getTblValue("airsGroup", unitGroup)
    if (!unitsList)
      return null

    local res = null
    foreach (unit in unitsList)
      if (canResearchUnit(unit)) {
        res = unit
        break
      }
      else if (!res && (canBuyUnit(unit) || ::canBuyUnitOnline(unit)))
        res = unit

    return res || getTblValue(0, unitsList)
  }

  function updateButtons() {
    if (!checkObj(this.scene))
      return

    this.updateRepairAllButton()
    let unit = this.getCurAircraft(true, true)
    if (!unit)
      return

    this.updateSpendExpBtn(unit)

    let isFakeUnit = unit?.isFakeUnit ?? false
    let canBuyIngame = !isFakeUnit && canBuyUnit(unit)
    let canBuyOnline = !isFakeUnit && ::canBuyUnitOnline(unit)
    let showBuyUnit = canBuyIngame || canBuyOnline
    this.showNavButton("btn_buy_unit", showBuyUnit)
    if (showBuyUnit) {
      let locText = loc("shop/btnOrderUnit", { unit = getUnitName(unit.name) })
      let unitCost = (canBuyIngame && !canBuyOnline) ? getUnitCost(unit) : Cost()
      placePriceTextToButton(this.navBarObj,      "btn_buy_unit", locText, unitCost)
      placePriceTextToButton(this.navBarGroupObj, "btn_buy_unit", locText, unitCost)
    }
  }

  canSpendExp = @(unit) unit != null && !isUnitGroup(unit) && !unit?.isFakeUnit
    && canResearchUnit(unit) && !unit.isSquadronVehicle()

  function updateSpendExpBtn(unit) {
    let showSpendBtn = this.canSpendExp(unit)
    local coloredText = ""
    if (showSpendBtn) {
      let reqExp = getUnitReqExp(unit) - getUnitExp(unit)
      let flushExp = reqExp < this.availableFlushExp ? reqExp : this.availableFlushExp
      let textSample = loc("shop/researchUnit", { unit = getUnitName(unit.name) })
      let textValue = flushExp ? loc("ui/parentheses/space",
        { text = Cost().setRp(flushExp).tostring() }) : ""
      coloredText = "".concat(textSample, textValue)
    }

    foreach (navBar in [this.navBarObj, this.navBarGroupObj]) {
      if (!checkObj(navBar))
        continue
      let spendExpBtn = navBar.findObject("btn_spend_exp")
      if (!checkObj(spendExpBtn))
        continue

      spendExpBtn.inactive = showSpendBtn ? "no" : "yes"
      spendExpBtn.show(showSpendBtn)
      spendExpBtn.enable(showSpendBtn)
      if (showSpendBtn)
        setColoredDoubleTextToButton(navBar, "btn_spend_exp", coloredText)
    }
  }

  function updateGroupObjNavBar() {
    base.updateGroupObjNavBar()
  }

  function onSpendExcessExp() {
    if (this.hasSpendExpProcess)
      return
    this.hasSpendExpProcess = true
    let unit = this.getCurAircraft(true, true)
    this.flushItemExp(unit, @() this.setUnitOnResearch(unit, function() {
      this.hasSpendExpProcess = false
      sendBqEvent("CLIENT_GAMEPLAY_1", "choosed_new_research_unit", { unitName = unit.name })
      this.sendUnitResearchedStatistic(unit)
    }))
  }

  























  function setUnitOnResearch(unit = null, afterDoneFunc = null) {
    let executeAfterDoneFunc =  function() {
        if (afterDoneFunc)
          afterDoneFunc()
      }

    if (unit && isUnitResearched(unit)) {
      executeAfterDoneFunc()
      return
    }

    if (unit) {
      this.lastResearchUnit = unit
      research(unit, false)
    }
    else
      shop_reset_researchable_unit(this.unitCountry, this.unitType)
    this.updateButtons()
  }

  function flushItemExp(unitOnResearch, afterDoneFunc = null) {
    let executeAfterDoneFunc = function() {
      if (!this.isValid())
        return

      this.setResearchManually = true
      this.updateResearchVariables()
      this.fillAircraftsList()
      this.updateButtons()

      this.selectRequiredUnit()

      if (afterDoneFunc)
        afterDoneFunc()
    }

    if (this.availableFlushExp <= 0) {
      executeAfterDoneFunc()
      return
    }

    this.taskId = flushExcessExpToUnit(unitOnResearch.name)
    if (this.taskId >= 0) {
      set_char_cb(this, this.slotOpCb)
      this.afterSlotOp = executeAfterDoneFunc
      this.afterSlotOpError = @(_res) executeAfterDoneFunc()
    }
  }

  function onTryCloseShop() {
    if (!this.hasNextResearch() && this.canSpendExp(this.getCurAircraft(true, true))) {
      this.onSpendExcessExp()
      return
    }

    let unit = this.selectRequiredUnit()
    if (unit == null) {
      this.onCloseShop()
      return
    }
    let unitName = getUnitName(unit.name)
    let reqExp = getUnitReqExp(unit) - getUnitExp(unit)
    let flushExp = reqExp < this.availableFlushExp ? reqExp : this.availableFlushExp
    let expText = Cost().setRp(flushExp).tostring()

    this.msgBox("close_research", loc("msgbox/close_research_wnd_message", {exp = expText, unitName}),
      [["yes", function() {this.onSpendExcessExp()}], ["no", function() {} ]], "yes", { cancel_fn = function() {} })
  }

  function onCloseShop() {
    this.destroyGroupChoose()
    let curResName = shop_get_researchable_unit_name(this.unitCountry, this.unitType)
    if (getTblValue("name", this.lastResearchUnit, "") != curResName)
      this.setUnitOnResearch(getAircraftByName(curResName))

    gui_handlers.BaseGuiHandlerWT.goBack.call(this)
  }

  goBack = @() this.onTryCloseShop()

  function onEventModalWndDestroy(params) {
    base.onEventModalWndDestroy(params)
    let closedHandler = getTblValue("handler", params, null)
    if (!closedHandler)
      return

    if (closedHandler.getclass() == gui_handlers.researchUnitNotification) {
      this.showResearchUnitTutorial()
      this.selectRequiredUnit()
      this.showRankRestrictionMsgBox()
    }
  }

  function afterModalDestroy() {
    checkNonApprovedResearches(true)
  }

  function sendUnitResearchedStatistic(unit) {
    sendBqEvent("CLIENT_GAMEPLAY_1", "completed_new_research_unit", { unit = unit.name
      howResearched = "earned_exp" })
  }
}
