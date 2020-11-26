local tutorialModule = require("scripts/user/newbieTutorialDisplay.nut")
local unitActions = require("scripts/unit/unitActions.nut")
local tutorAction = require("scripts/tutorials/tutorialActions.nut")
local { setColoredDoubleTextToButton, placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

class ::gui_handlers.ShopCheckResearch extends ::gui_handlers.ShopMenuHandler
{
  wndType = handlerType.MODAL
  sceneTplName = "gui/shop/shopCheckResearch"
  sceneNavBlkName = "gui/shop/shopNav.blk"
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

  function getSceneTplView() { return {hasMaxWindowSize = ::is_small_screen} }

  function initScreen()
  {
    local unitName = ::getTblValue(::researchedUnitForCheck, researchBlock)
    curAirName = unitName
    researchedUnit = ::getAircraftByName(unitName)
    unitCountry = researchBlock.country
    unitType = ::get_es_unit_type(researchedUnit)
    sendUnitResearchedStatistic(researchedUnit)
    updateResearchVariables()

    base.initScreen()

    showSceneBtn("modesRadiobuttons", false)

    if(!::is_small_screen)
      createSlotbar(
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
    if (!hasNextResearch() || showRankLockedMsgBoxOnce || !isSceneActiveNoModals())
      return

    showRankLockedMsgBoxOnce = true

    local rank = getMaxEraAvailableByCountry()
    local nextRank = rank + 1

    if (nextRank > ::max_country_rank)
      return

    local unitLockedByFeature = getNotResearchedUnitByFeature()
    if (unitLockedByFeature && !::checkFeatureLock(unitLockedByFeature, CheckFeatureLockAction.RESEARCH))
      return

    local ranksBlk = ::get_ranks_blk()
    local unitsCount = boughtVehiclesCount[rank]
    local unitsNeed = ::getUnitsNeedBuyToOpenNextInEra(unitCountry, unitType, rank, ranksBlk)
    local reqUnits = max(0, unitsNeed - unitsCount)
    if (reqUnits > 0)
    {
      local text = ::loc("shop/unlockTier/locked", {rank = ::get_roman_numeral(nextRank)}) + "\n"
                    + ::loc("shop/unlockTier/reqBoughtUnitsPrevRank", {amount = reqUnits, prevRank = ::get_roman_numeral(rank)})
      msgBox("locked_rank", text, [["ok", function(){}]], "ok", { cancel_fn = function(){}})
    }
  }

  function updateHeaderText()
  {
    local headerObj = scene.findObject("shop_header")
    if (!::checkObj(headerObj))
      return

    local expText = ::get_flush_exp_text(availableFlushExp)
    local headerText = ::loc("mainmenu/nextResearch/title")
    if (expText != "")
      headerText += ::loc("ui/parentheses/space", {text = expText})
    headerObj.setValue(headerText)
  }

  function updateResearchVariables()
  {
    updateCurResearchingUnit()
    updateExcessExp()
  }

  function updateCurResearchingUnit()
  {
    local curUnitName = ::shop_get_researchable_unit_name(unitCountry, unitType)
    if (curUnitName == ::getTblValue("name", curResearchingUnit, ""))
      return

    curResearchingUnit = ::getAircraftByName(curUnitName)
  }

  function updateExcessExp()
  {
    availableFlushExp = ::shop_get_country_excess_exp(unitCountry, unitType)
    updateHeaderText()
  }

  function hasNextResearch()
  {
    return availableFlushExp > 0 &&
      (curResearchingUnit == null || ::isUnitResearched(curResearchingUnit))
  }

  function getMaxRankUnboughtUnitByCountry()
  {
    local unit = null
    foreach (newUnit in ::all_units)
      if (!unitCountry || unitCountry == ::getUnitCountry(newUnit))
        if (::getTblValue("rank", newUnit, 0) > ::getTblValue("rank", unit, 0))
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
    if (availableFlushExp > 0)
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
      local nextResearchingUnit = getMaxRankResearchingUnitByCountry()
      if (nextResearchingUnit)
        unit = nextResearchingUnit
      else
        unit = getMaxRankUnboughtUnitByCountry()
    }
    else
      unit = curResearchingUnit

    if (!unit)
    {
      guiScene.performDelayed(this, function() {
        if (!isSceneActiveNoModals())
          return
        showRankRestrictionMsgBox()
      })
      return
    }

    destroyGroupChoose(::isGroupPart(unit)? unit.group : "")

    if (::isGroupPart(unit))
      guiScene.performDelayed(this, (@(unit) function() {
        if (!isSceneActiveNoModals())
          return
        checkSelectAirGroup(getItemBlockFromShopTree(unit.group), unit.name)
      })(unit))

    selectCellByUnitName(unit.name)
  }

  function showResearchUnitTutorial()
  {
    if (!tutorialModule.needShowTutorial("researchUnit", 1))
      return

    tutorialModule.saveShowedTutorial("researchUnit")

    local visibleObj = scene.findObject("shop_items_visible_div")
    if (!visibleObj)
      return

    local visibleBox = ::GuiBox().setFromDaguiObj(visibleObj)
    local unitsObj = []
    foreach (newUnit in ::all_units)
      if (unitCountry == ::getUnitCountry(newUnit) && !newUnit.isSquadronVehicle()
        && unitType == ::get_es_unit_type(newUnit) && ::canResearchUnit(newUnit))
      {
        local newUnitName = ""
        if (::isGroupPart(newUnit))
          newUnitName = newUnit.group
        else
          newUnitName = newUnit.name

        local unitObj = scene.findObject(newUnitName)
        if (unitObj)
        {
          local unitBox = ::GuiBox().setFromDaguiObj(unitObj)
          if (unitBox.isInside(visibleBox))
            unitsObj.append(unitObj)
        }
      }
    unitsObj.append("btn_spend_exp")

    local steps = [
      {
        obj = unitsObj
        text = ::loc("tutorials/research_next_aircraft")
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
    local unitsList = ::getTblValue("airsGroup", unitGroup)
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

    return res || ::getTblValue(0, unitsList)
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    updateRepairAllButton()
    showSceneBtn("btn_back", curResearchingUnit == null || ::isUnitResearched(curResearchingUnit))

    local unit = getCurAircraft(true, true)
    if (!unit)
      return

    updateSpendExpBtn(unit)

    local isFakeUnit = unit?.isFakeUnit ?? false
    local canBuyIngame = !isFakeUnit && ::canBuyUnit(unit)
    local canBuyOnline = !isFakeUnit && ::canBuyUnitOnline(unit)
    local showBuyUnit = canBuyIngame || canBuyOnline
    showNavButton("btn_buy_unit", showBuyUnit)
    if (showBuyUnit)
    {
      local locText = ::loc("shop/btnOrderUnit", { unit = ::getUnitName(unit.name) })
      local unitCost = (canBuyIngame && !canBuyOnline) ? ::getUnitCost(unit) : ::Cost()
      placePriceTextToButton(navBarObj,      "btn_buy_unit", locText, unitCost)
      placePriceTextToButton(navBarGroupObj, "btn_buy_unit", locText, unitCost)
    }
  }

  function updateSpendExpBtn(unit)
  {
    local showSpendBtn = !::isUnitGroup(unit) && !unit?.isFakeUnit
                         && ::canResearchUnit(unit) && !unit.isSquadronVehicle()
    local coloredText = ""
    if (showSpendBtn)
    {
      local reqExp = ::getUnitReqExp(unit) - ::getUnitExp(unit)
      local flushExp = reqExp < availableFlushExp ? reqExp : availableFlushExp
      local textSample = ::loc("shop/researchUnit", { unit = ::getUnitName(unit.name) }) + "%s"
      local textValue = flushExp ? ::loc("ui/parentheses/space",
        {text = ::Cost().setRp(flushExp).tostring()}) : ""
      coloredText = ::format(textSample, textValue)
    }

    foreach(navBar in [navBarObj, navBarGroupObj])
    {
      if (!::checkObj(navBar))
        continue
      local spendExpBtn = navBar.findObject("btn_spend_exp")
      if (!::checkObj(spendExpBtn))
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
    if (hasSpendExpProcess)
      return

    hasSpendExpProcess = true
    local unit = getCurAircraft(true, true)
    flushItemExp(unit, @() setUnitOnResearch(unit, function() {
      hasSpendExpProcess = false
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
    local executeAfterDoneFunc = (@(afterDoneFunc) function() {
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
    local executeAfterDoneFunc = (@(unitOnResearch, afterDoneFunc) function() {
        if (!isValid())
          return

        setResearchManually = true
        updateResearchVariables()
        fillAircraftsList()
        updateButtons()

        selectRequiredUnit()

        if (afterDoneFunc)
          afterDoneFunc()
      })(unitOnResearch, afterDoneFunc)

    if (availableFlushExp <= 0)
    {
      executeAfterDoneFunc()
      return
    }

    taskId = ::flushExcessExpToUnit(unitOnResearch.name)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      afterSlotOp = executeAfterDoneFunc
      afterSlotOpError = (@(executeAfterDoneFunc) function(res) {
          executeAfterDoneFunc()
        })(executeAfterDoneFunc)
    }
  }

  function onCloseShop()
  {
    destroyGroupChoose()
    local curResName = ::shop_get_researchable_unit_name(unitCountry, unitType)
    if (::getTblValue("name", lastResearchUnit, "") != curResName)
      setUnitOnResearch(::getAircraftByName(curResName))

    ::gui_handlers.BaseGuiHandlerWT.goBack.call(this)
  }

  function onEventModalWndDestroy(params)
  {
    local closedHandler = ::getTblValue("handler", params, null)
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
  local blk = ::DataBlock()
  blk = ::get_discounts_blk()

  foreach(name, block in blk)
    if(name == "steam_markup")
      return block.all

  return 0
}

::checkShopBlk <- function checkShopBlk()
{
  local resText = ""
  local shopBlk = ::get_shop_blk()
  for (local tree = 0; tree < shopBlk.blockCount(); tree++)
  {
    local tblk = shopBlk.getBlock(tree)
    local country = tblk.getBlockName()

    for (local page = 0; page < tblk.blockCount(); page++)
    {
      local pblk = tblk.getBlock(page)
      local groups = []
      for (local range = 0; range < pblk.blockCount(); range++)
      {
        local rblk = pblk.getBlock(range)
        for (local a = 0; a < rblk.blockCount(); a++)
        {
          local airBlk = rblk.getBlock(a)
          local airName = airBlk.getBlockName()
          local air = getAircraftByName(airName)
          if (!air)
          {
            local groupTotal = airBlk.blockCount()
            if (groupTotal == 0)
            {
              resText += ((resText!="")? "\n":"") + "Not found aircraft " + airName + " in " + country
              continue
            }
            groups.append(airName)
            for(local ga=0; ga<groupTotal; ga++)
            {
              local gAirBlk = airBlk.getBlock(ga)
              air = getAircraftByName(gAirBlk.getBlockName())
              if (!air)
                resText += ((resText!="")? "\n":"") + "Not found aircraft " + gAirBlk.getBlockName() + " in " + country
            }
          } else
            if ((airBlk?.reqAir ?? "") != "")
            {
              local reqAir = getAircraftByName(airBlk.reqAir)
              if (!reqAir && !isInArray(airBlk.reqAir, groups))
                resText += ((resText!="")? "\n":"") + "Not found reqAir " + airBlk.reqAir + " for " + airName + " in " + country
            }
        }
      }
    }
  }
  if (resText=="")
    dagor.debug("Shop.blk checked.")
  else
    dagor.fatal("Incorrect shop.blk!\n" + resText)
}
