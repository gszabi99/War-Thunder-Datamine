from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { fatal } = require("dagor.debug")
let tutorialModule = require("%scripts/user/newbieTutorialDisplay.nut")
let unitActions = require("%scripts/unit/unitActions.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { setColoredDoubleTextToButton, placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")

::gui_handlers.ShopCheckResearch <- class extends ::gui_handlers.ShopMenuHandler
{
  wndType = handlerType.MODAL
  sceneTplName = "%gui/shop/shopCheckResearch"
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
  slotbarActions = [ "research", "buy", "take", "sec_weapons", "weapons", "info", "repair" ]

  function getSceneTplView() { return {hasMaxWindowSize = isSmallScreen} }

  function initScreen()
  {
    let unitName = getTblValue(::researchedUnitForCheck, researchBlock)
    this.curAirName = unitName
    researchedUnit = ::getAircraftByName(unitName)
    unitCountry = researchBlock.country
    unitType = ::get_es_unit_type(researchedUnit)
    sendUnitResearchedStatistic(researchedUnit)
    updateResearchVariables()

    base.initScreen()

    this.showSceneBtn("modesRadiobuttons", false)

    if(!isSmallScreen)
      this.createSlotbar(
        {
          showNewSlot = true,
          showEmptySlot = true,
          isCountryChoiceAllowed = false,
          customCountry = unitCountry,
          showTopPanel = false
        },
        "slotbar_place")

    selectRequiredUnit()
  }

  function getNotResearchedUnitByFeature()
  {
    foreach(unit in ::all_units)
      if (    (!unitCountry || ::getUnitCountry(unit) == unitCountry)
           && (unitType == null || ::get_es_unit_type(unit) == unitType)
           && ::isUnitFeatureLocked(unit)
         )
        return unit
    return null
  }

  function getMaxEraAvailableByCountry()
  {
    for (local era = 1; era <= ::max_country_rank; era++)
      if (!::is_era_available(unitCountry, era, unitType))
        return (era - 1)
    return ::max_country_rank
  }

  function showRankRestrictionMsgBox()
  {
    if (!hasNextResearch() || showRankLockedMsgBoxOnce || !this.isSceneActiveNoModals())
      return

    showRankLockedMsgBoxOnce = true

    let rank = getMaxEraAvailableByCountry()
    let nextRank = rank + 1

    if (nextRank > ::max_country_rank)
      return

    let unitLockedByFeature = getNotResearchedUnitByFeature()
    if (unitLockedByFeature && !::checkFeatureLock(unitLockedByFeature, CheckFeatureLockAction.RESEARCH))
      return

    let ranksBlk = ::get_ranks_blk()
    let unitsCount = this.boughtVehiclesCount[rank]
    let unitsNeed = ::getUnitsNeedBuyToOpenNextInEra(unitCountry, unitType, rank, ranksBlk)
    let reqUnits = max(0, unitsNeed - unitsCount)
    if (reqUnits > 0)
    {
      let text = loc("shop/unlockTier/locked", {rank = ::get_roman_numeral(nextRank)}) + "\n"
                    + loc("shop/unlockTier/reqBoughtUnitsPrevRank", {amount = reqUnits, prevRank = ::get_roman_numeral(rank)})
      this.msgBox("locked_rank", text, [["ok", function(){}]], "ok", { cancel_fn = function(){}})
    }
  }

  function updateHeaderText()
  {
    let headerObj = this.scene.findObject("shop_header")
    if (!checkObj(headerObj))
      return

    let expText = ::get_flush_exp_text(this.availableFlushExp)
    local headerText = loc("mainmenu/nextResearch/title")
    if (expText != "")
      headerText += loc("ui/parentheses/space", {text = expText})
    headerObj.setValue(headerText)
  }

  function updateResearchVariables()
  {
    updateCurResearchingUnit()
    updateExcessExp()
  }

  function updateCurResearchingUnit()
  {
    let curUnitName = ::shop_get_researchable_unit_name(unitCountry, unitType)
    if (curUnitName == getTblValue("name", curResearchingUnit, ""))
      return

    curResearchingUnit = ::getAircraftByName(curUnitName)
  }

  function updateExcessExp()
  {
    this.availableFlushExp = ::shop_get_country_excess_exp(unitCountry, unitType)
    updateHeaderText()
  }

  function hasNextResearch()
  {
    return this.availableFlushExp > 0 &&
      (curResearchingUnit == null || ::isUnitResearched(curResearchingUnit))
  }

  function getMaxRankUnboughtUnitByCountry()
  {
    local unit = null
    foreach (newUnit in ::all_units)
      if (!unitCountry || unitCountry == ::getUnitCountry(newUnit))
        if (getTblValue("rank", newUnit, 0) > getTblValue("rank", unit, 0))
          if (unitType == ::get_es_unit_type(newUnit)
              && !::isUnitSpecial(newUnit)
              && ::canBuyUnit(newUnit)
              && ::isPrevUnitBought(newUnit))
            unit = newUnit
    return unit
  }

  function getMaxRankResearchingUnitByCountry()
  {
    local unit = null
    foreach (newUnit in ::all_units)
      if (unitCountry == ::getUnitCountry(newUnit) && !newUnit.isSquadronVehicle()
        && unitType == ::get_es_unit_type(newUnit) && ::canResearchUnit(newUnit))
          unit = newUnit.rank > (unit?.rank ?? 0) ? newUnit : unit
    return unit
  }

  function selectRequiredUnit()
  {
    local unit = null
    if (this.availableFlushExp > 0)
    {
      if (curResearchingUnit && !::isUnitResearched(curResearchingUnit))
        unit = curResearchingUnit
      else
      {
        unit = getMaxRankResearchingUnitByCountry()
        setUnitOnResearch(unit)
      }
    }
    else if (!curResearchingUnit || ::isUnitResearched(curResearchingUnit))
    {
      let nextResearchingUnit = getMaxRankResearchingUnitByCountry()
      if (nextResearchingUnit)
        unit = nextResearchingUnit
      else
        unit = getMaxRankUnboughtUnitByCountry()
    }
    else
      unit = curResearchingUnit

    if (!unit)
    {
      this.guiScene.performDelayed(this, function() {
        if (!this.isSceneActiveNoModals())
          return
        showRankRestrictionMsgBox()
      })
      return
    }

    this.destroyGroupChoose(::isGroupPart(unit)? unit.group : "")

    if (::isGroupPart(unit))
      this.guiScene.performDelayed(this, (@(unit) function() {
        if (!this.isSceneActiveNoModals())
          return
        this.checkSelectAirGroup(this.getItemBlockFromShopTree(unit.group), unit.name)
      })(unit))

    this.selectCellByUnitName(unit.name)
  }

  function showResearchUnitTutorial()
  {
    if (!tutorialModule.needShowTutorial("researchUnit", 1))
      return

    tutorialModule.saveShowedTutorial("researchUnit")

    let visibleObj = this.scene.findObject("shop_items_visible_div")
    if (!visibleObj)
      return

    let visibleBox = ::GuiBox().setFromDaguiObj(visibleObj)
    let unitsObj = []
    foreach (newUnit in ::all_units)
      if (unitCountry == ::getUnitCountry(newUnit) && !newUnit.isSquadronVehicle()
        && unitType == ::get_es_unit_type(newUnit) && ::canResearchUnit(newUnit))
      {
        local newUnitName = ""
        if (::isGroupPart(newUnit))
          newUnitName = newUnit.group
        else
          newUnitName = newUnit.name

        let unitObj = this.scene.findObject(newUnitName)
        if (unitObj)
        {
          let unitBox = ::GuiBox().setFromDaguiObj(unitObj)
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
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
      }]
    ::gui_modal_tutor(steps, this)
  }

  function onUnitSelect()
  {
    updateButtons()
  }

  function getDefaultUnitInGroup(unitGroup)
  {
    let unitsList = getTblValue("airsGroup", unitGroup)
    if (!unitsList)
      return null

    local res = null
    foreach(unit in unitsList)
      if (::canResearchUnit(unit))
      {
        res = unit
        break
      }
      else if (!res && (::canBuyUnit(unit) || ::canBuyUnitOnline(unit)))
        res = unit

    return res || getTblValue(0, unitsList)
  }

  function updateButtons()
  {
    if (!checkObj(this.scene))
      return

    this.updateRepairAllButton()
    this.showSceneBtn("btn_back", curResearchingUnit == null || ::isUnitResearched(curResearchingUnit))

    let unit = this.getCurAircraft(true, true)
    if (!unit)
      return

    updateSpendExpBtn(unit)

    let isFakeUnit = unit?.isFakeUnit ?? false
    let canBuyIngame = !isFakeUnit && ::canBuyUnit(unit)
    let canBuyOnline = !isFakeUnit && ::canBuyUnitOnline(unit)
    let showBuyUnit = canBuyIngame || canBuyOnline
    this.showNavButton("btn_buy_unit", showBuyUnit)
    if (showBuyUnit)
    {
      let locText = loc("shop/btnOrderUnit", { unit = ::getUnitName(unit.name) })
      let unitCost = (canBuyIngame && !canBuyOnline) ? ::getUnitCost(unit) : ::Cost()
      placePriceTextToButton(this.navBarObj,      "btn_buy_unit", locText, unitCost)
      placePriceTextToButton(this.navBarGroupObj, "btn_buy_unit", locText, unitCost)
    }
  }

  function updateSpendExpBtn(unit)
  {
    let showSpendBtn = !::isUnitGroup(unit) && !unit?.isFakeUnit
                         && ::canResearchUnit(unit) && !unit.isSquadronVehicle()
    local coloredText = ""
    if (showSpendBtn)
    {
      let reqExp = ::getUnitReqExp(unit) - ::getUnitExp(unit)
      let flushExp = reqExp < this.availableFlushExp ? reqExp : this.availableFlushExp
      let textSample = loc("shop/researchUnit", { unit = ::getUnitName(unit.name) }) + "%s"
      let textValue = flushExp ? loc("ui/parentheses/space",
        {text = ::Cost().setRp(flushExp).tostring()}) : ""
      coloredText = format(textSample, textValue)
    }

    foreach(navBar in [this.navBarObj, this.navBarGroupObj])
    {
      if (!checkObj(navBar))
        continue
      let spendExpBtn = navBar.findObject("btn_spend_exp")
      if (!checkObj(spendExpBtn))
        continue

      spendExpBtn.inactive = showSpendBtn? "no" : "yes"
      spendExpBtn.show(showSpendBtn)
      spendExpBtn.enable(showSpendBtn)
      if (showSpendBtn)
        setColoredDoubleTextToButton(navBar, "btn_spend_exp", coloredText)
    }
  }

  function updateGroupObjNavBar()
  {
    base.updateGroupObjNavBar()
  }

  function onSpendExcessExp()
  {
    if (this.hasSpendExpProcess)
      return

    this.hasSpendExpProcess = true
    let unit = this.getCurAircraft(true, true)
    flushItemExp(unit, @() setUnitOnResearch(unit, function() {
      this.hasSpendExpProcess = false
      ::add_big_query_record("choosed_new_research_unit", unit.name)
      sendUnitResearchedStatistic(unit)
    }))
  }

  /*
  function automaticallySpendAllExcessiveExp() //!!!TEMP function, true func must be from code
  {
    updateResearchVariables()

    local afterDoneFunc = function() {
      destroyProgressBox()
      updateButtons()
      onCloseShop()
    }

    if (availableFlushExp <= 0)
      setUnitOnResearch(curResearchingUnit)

    if (!curResearchingUnit || availableFlushExp <= 0)
    {
      afterDoneFunc()
      return
    }

    flushItemExp(curResearchingUnit, automaticallySpendAllExcessiveExp)
  }
  */

  function setUnitOnResearch(unit = null, afterDoneFunc = null)
  {
    let executeAfterDoneFunc = (@(afterDoneFunc) function() {
        if (afterDoneFunc)
          afterDoneFunc()
      })(afterDoneFunc)

    if (unit && ::isUnitResearched(unit))
    {
      executeAfterDoneFunc()
      return
    }

    if (unit)
    {
      lastResearchUnit = unit
      unitActions.research(unit, false)
    }
    else
      ::shop_reset_researchable_unit(unitCountry, unitType)
    updateButtons()
  }

  function flushItemExp(unitOnResearch, afterDoneFunc = null)
  {
    let executeAfterDoneFunc = (@(_unitOnResearch, afterDoneFunc) function() {
        if (!this.isValid())
          return

        setResearchManually = true
        updateResearchVariables()
        this.fillAircraftsList()
        updateButtons()

        selectRequiredUnit()

        if (afterDoneFunc)
          afterDoneFunc()
      })(unitOnResearch, afterDoneFunc)

    if (this.availableFlushExp <= 0)
    {
      executeAfterDoneFunc()
      return
    }

    this.taskId = ::flushExcessExpToUnit(unitOnResearch.name)
    if (this.taskId >= 0)
    {
      ::set_char_cb(this, this.slotOpCb)
      this.afterSlotOp = executeAfterDoneFunc
      this.afterSlotOpError = (@(executeAfterDoneFunc) function(_res) {
          executeAfterDoneFunc()
        })(executeAfterDoneFunc)
    }
  }

  function onCloseShop()
  {
    this.destroyGroupChoose()
    let curResName = ::shop_get_researchable_unit_name(unitCountry, unitType)
    if (getTblValue("name", lastResearchUnit, "") != curResName)
      setUnitOnResearch(::getAircraftByName(curResName))

    ::gui_handlers.BaseGuiHandlerWT.goBack.call(this)
  }

  function onEventModalWndDestroy(params)
  {
    let closedHandler = getTblValue("handler", params, null)
    if (!closedHandler)
      return

    if (closedHandler.getclass() == ::gui_handlers.researchUnitNotification)
    {
      showResearchUnitTutorial()
      selectRequiredUnit()
      showRankRestrictionMsgBox()
    }
  }

  function afterModalDestroy()
  {
    ::checkNonApprovedResearches(true)
  }

  function sendUnitResearchedStatistic(unit)
  {
    ::add_big_query_record("completed_new_research_unit",
        ::save_to_json({ unit = unit.name
          howResearched = "earned_exp" }))
  }
}

::getSteamMarkUp <- function getSteamMarkUp()
{
  let blk = ::get_discounts_blk()

  let blocksCount = blk.blockCount()
  for (local i = 0; i < blocksCount; i++) {
    let block = blk.getBlock(i)
    if(block.getBlockName() == "steam_markup")
      return block.all
  }

  return 0
}

::checkShopBlk <- function checkShopBlk()
{
  local resText = ""
  let shopBlk = ::get_shop_blk()
  for (local tree = 0; tree < shopBlk.blockCount(); tree++)
  {
    let tblk = shopBlk.getBlock(tree)
    let country = tblk.getBlockName()

    for (local page = 0; page < tblk.blockCount(); page++)
    {
      let pblk = tblk.getBlock(page)
      let groups = []
      for (local range = 0; range < pblk.blockCount(); range++)
      {
        let rblk = pblk.getBlock(range)
        for (local a = 0; a < rblk.blockCount(); a++)
        {
          let airBlk = rblk.getBlock(a)
          let airName = airBlk.getBlockName()
          local air = ::getAircraftByName(airName)
          if (!air)
          {
            let groupTotal = airBlk.blockCount()
            if (groupTotal == 0)
            {
              resText += ((resText!="")? "\n":"") + "Not found aircraft " + airName + " in " + country
              continue
            }
            groups.append(airName)
            for(local ga=0; ga<groupTotal; ga++)
            {
              let gAirBlk = airBlk.getBlock(ga)
              air = ::getAircraftByName(gAirBlk.getBlockName())
              if (!air)
                resText += ((resText!="")? "\n":"") + "Not found aircraft " + gAirBlk.getBlockName() + " in " + country
            }
          } else
            if ((airBlk?.reqAir ?? "") != "")
            {
              let reqAir = ::getAircraftByName(airBlk.reqAir)
              if (!reqAir && !isInArray(airBlk.reqAir, groups))
                resText += ((resText!="")? "\n":"") + "Not found reqAir " + airBlk.reqAir + " for " + airName + " in " + country
            }
        }
      }
    }
  }
  if (resText=="")
    log("Shop.blk checked.")
  else
    fatal("Incorrect shop.blk!\n" + resText)
}
