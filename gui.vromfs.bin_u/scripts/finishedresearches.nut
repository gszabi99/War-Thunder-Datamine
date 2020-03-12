local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local { getModificationName } = require("scripts/weaponry/bulletsInfo.nut")
local { AMMO, getAmmoMaxAmount } = require("scripts/weaponry/ammoInfo.nut")

::researched_items_table <- null
::abandoned_researched_items_for_session <- []
::researchedModForCheck <- "prevMod"
::researchedUnitForCheck <- "prevUnit"
::min_new_researches_for_list_wnd <- 3
::units_with_finished_researches <- {}

::g_script_reloader.registerPersistentData("finishedResearchesGlobals", ::getroottable(),
  ["researched_items_table", "abandoned_researched_items_for_session", "units_with_finished_researches"])

::gui_show_all_researches_wnd <- function gui_show_all_researches_wnd(researchData = null)
{
  ::gui_start_modal_wnd(::gui_handlers.showAllResearchedItems, {researchData = researchData})
}

::gui_start_choose_next_research <- function gui_start_choose_next_research(researchBlock = null)
{
  if (!::isResearchForModification(researchBlock))
  {
    ::gui_start_shop_research({researchBlock = researchBlock})
    ::gui_start_modal_wnd(::gui_handlers.researchUnitNotification, {researchBlock = researchBlock})
  }
  else
  {
    local unit = ::getAircraftByName(::getUnitNameFromResearchItem(researchBlock))
    ::open_weapons_for_unit(unit, { researchMode = true, researchBlock = researchBlock })
  }
}

::isResearchEqual <- function isResearchEqual(research1, research2)
{
  foreach(key in ["name", ::researchedModForCheck, ::researchedUnitForCheck])
  {
    local haveValue = key in research1
    if (haveValue != (key in research2))
      return false
    if (haveValue && research1[key] != research2[key])
      return false
  }
  return true
}

::isResearchAbandoned <- function isResearchAbandoned(research)
{
  foreach(idx, abandoned in ::abandoned_researched_items_for_session)
    if (::isResearchEqual(research, abandoned))
      return true
  return false
}

::isResearchLast <- function isResearchLast(research, checkUnit = false)
{
  if (isResearchForModification(research))
    return ::getTblValue("mod", research, "") == ""
  else if (checkUnit)
    return ::getTblValue("unit", research, "") == ""
  return false
}

::isResearchForModification <- function isResearchForModification(research)
{
  if ("name" in research && ::researchedModForCheck in research)
    return true
  return false
}

::removeResearchBlock <- function removeResearchBlock(researchBlock)
{
  if (!researchBlock)
    return

  if (!::isResearchAbandoned(researchBlock))
    ::abandoned_researched_items_for_session.append(researchBlock)

  foreach(idx, newResearch in ::researched_items_table)
    if (::isResearchEqual(researchBlock, newResearch))
    {
      ::researched_items_table.remove(idx)
      break
    }
}

::getNextResearchItem <- function getNextResearchItem(research)
{
  local searchParam = ::isResearchForModification(research)? "mod" : "unit"
  return ::getTblValue(searchParam, research, "")
}

::getUnitNameFromResearchItem <- function getUnitNameFromResearchItem(research)
{
  local searchParam = ::isResearchForModification(research)? "name" : "unit"
  return ::getTblValue(searchParam, research, "")
}

::checkNonApprovedResearches <- function checkNonApprovedResearches(needUpdateResearchTable = false, needResearchAction = true)
{
  if (!::isInMenu() || ::checkIsInQueue())
    return false

  if (needUpdateResearchTable)
  {
    ::researched_items_table = ::shop_get_countries_list_with_autoset_units()
    ::researched_items_table.extend(::shop_get_units_list_with_autoset_modules())
  }

  if (!::researched_items_table || !::researched_items_table.len())
    return false

  for (local i = ::researched_items_table.len()-1; i >= 0; --i)
  {
    if (::isResearchAbandoned(::researched_items_table[i]) ||
      !::getAircraftByName(::getUnitNameFromResearchItem(::researched_items_table[i]))?.unitType.isAvailable()
    )
      ::removeResearchBlock(::researched_items_table[i])
  }

  if (!::researched_items_table.len())
    return false

  foreach (research in ::researched_items_table)
  {
    if (!::isResearchLast(research))
      continue

    if (::isResearchForModification(research))
    {
      local unit = ::getAircraftByName(::getUnitNameFromResearchItem(research))
      ::add_big_query_record("completed_new_research_modification",
        ::save_to_json({ unit = unit.name
          modification = research.name }))
      ::shop_set_researchable_unit_module(unit.name, "")
      ::prepareUnitsForPurchaseMods.addUnit(unit)
    }
    ::removeResearchBlock(research)
  }

  if (!::researched_items_table.len())
  {
    if (::prepareUnitsForPurchaseMods.haveUnits())
    {
      if (needResearchAction)
        ::prepareUnitsForPurchaseMods.checkUnboughtMods(::get_auto_buy_modifications())
      return true
    }
    else
      return false
  }

  if (needResearchAction)
  {
    local resBlock = ::researched_items_table[0]
    if (::isResearchForModification(resBlock)
      && ::isHandlerInScene(::gui_handlers.WeaponsModalHandler))
      return true

    if (::isHandlerInScene(::gui_handlers.ShopCheckResearch))
      return true

    ::gui_start_choose_next_research(resBlock)
    ::removeResearchBlock(resBlock)
  }

  return true
}

::checkNewModuleResearchForUnit <- function checkNewModuleResearchForUnit(unit)
{
  local resList = ::shop_get_units_list_with_autoset_modules()
  foreach(research in resList)
    if (research.name == unit.name && !::isResearchAbandoned(research))
    {
      ::gui_start_choose_next_research(research)
      return true
    }
  return false
}

::checkNewUnitResearchForCountry <- function checkNewUnitResearchForCountry(country, unitType)
{
  local resList = ::shop_get_countries_list_with_autoset_units()
  foreach(research in resList)
    if (research.country == country && ::get_es_unit_type(::getAircraftByName(research[::researchedUnitForCheck])) == unitType
        && !::isResearchAbandoned(research))
    {
      ::gui_start_choose_next_research(research)
      return true
    }
  return false
}

class ::gui_handlers.showAllResearchedItems extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/researchedModifications.blk"

  researchData = null
  lastBlockIsMod = null
  statementTablesArray = null

  researchTableObj = null
  needDoneMsgBox = false
  haveAnyAvailableResearches = false

  buyQueue = null // array

  function initScreen()
  {
    buyQueue = []
    statementTablesArray = []
    if (!scene || !researchData)
      return goBack()

    researchTableObj = scene.findObject("ready_researches_block")
    if (!::checkObj(researchTableObj))
      return goBack()

    fillGamercard()
    foreach(idx, block in researchData)
      fillResearchedItem(idx, block)

    updateButtons()
    researchTableObj.select()
  }

  function getUnitNameFromBlock(block, isMod)
  {
    local unitName = ""
    if(isMod)
      unitName = block.name
    else if (::researchedUnitForCheck in block)
      unitName = block[::researchedUnitForCheck]
    return unitName
  }

  function generateResearchConfig(research)
  {
    local isMod = ::isResearchForModification(research)
    local unitName = getUnitNameFromBlock(research, isMod)
    local unit = ::getAircraftByName(unitName)
    if (!unit)
      return null

    return {
      isMod = isMod,
      researchInfo = research
      unitName = unitName,
      unit = unit,
      setItem = isMod? research.mod : research.unit
      prevModName = isMod? research[::researchedModForCheck] : ""
      country = isMod? "" : research.country
      isItemApproved = false
    }
  }

  function fillResearchedItem(idx, research)
  {
    local config = generateResearchConfig(research)
    if (!config)
      return false

    if (config.isMod != lastBlockIsMod)
    {
      lastBlockIsMod = config.isMod
      createDivideLineObj(researchTableObj, lastBlockIsMod? "Modifications" : "Units")
    }

    local exampleObj = scene.findObject("example_row")
    local clonedObj = exampleObj.getClone(researchTableObj, this)
    if (!::checkObj(clonedObj))
      return false

    clonedObj.show(true)
    clonedObj.id = "tr_" + config.unitName

    config.idx <- statementTablesArray.len()

    local result = fillRowByTable(config)
    if (!result)
      return false

    if (config.isMod && !(config.unitName in ::units_with_finished_researches))
      ::units_with_finished_researches[config.unitName] <- config.unit

    statementTablesArray.append(config)
    return true
  }

  function fillRowByTable(dataTable)
  {
    if (!dataTable)
      return false

    local unitName = dataTable.unitName
    local unit = dataTable.unit
    local autoSetItemName = dataTable.setItem
    local isMod = dataTable.isMod

    local curRowObj = scene.findObject("tr_" + unitName)
    if (!::checkObj(curRowObj))
      return false

    local airItemObj = curRowObj.findObject("cur_air_place")
    if (::checkObj(airItemObj))
    {
      local unitItem = ::build_aircraft_item(unitName, unit)
      guiScene.replaceContentFromText(airItemObj, unitItem, unitItem.len(), this)
      ::fill_unit_item_timers(airItemObj.findObject(unitName), unit)
      ::showUnitDiscount(airItemObj.findObject(unitName + "-discount"), ::getAircraftByName(unitName))
    }

    if (isMod)
      updateRowMods(curRowObj, dataTable)
    else
    {
      local startObj = curRowObj.findObject("research_start")
      if (!::checkObj(startObj))
        return false

      if (autoSetItemName != "" && autoSetItemName != unitName)
      {
        prepareNextResearchBlocks(curRowObj, true)
        local autoSetItem = ::getAircraftByName(autoSetItemName)
        local params = { forceNotInResearch = !dataTable.isItemApproved }
        local unitItem = ::build_aircraft_item(autoSetItemName, autoSetItem, params)
        guiScene.replaceContentFromText(startObj, unitItem, unitItem.len(), this)
        ::fill_unit_item_timers(startObj.findObject(autoSetItemName), autoSetItem, params)
        ::showAirDiscount(startObj.findObject(autoSetItemName + "-discount"), autoSetItemName)
      }
      else
        setNoResearchText(curRowObj, unit, isMod)
    }
    return true
  }

  function updateRowMods(rowObj, dataTable)
  {
    local unit = dataTable.unit
    local modObj = rowObj.findObject("research_done")
    if (!::checkObj(modObj) || !unit)
      return false

    local prevModName = dataTable.prevModName
    modObj.show(true)
    updateMod(modObj, "mod_done_" + dataTable.idx, unit, prevModName)

    local newModName = dataTable.setItem
    if (newModName != "" && newModName != prevModName)
    {
      prepareNextResearchBlocks(rowObj, true)
      updateMod(rowObj.findObject("research_start"), "mod_start_" + dataTable.idx, unit, newModName, dataTable.isItemApproved)
    } else
      setNoResearchText(rowObj, unit, true)
  }

  function updateMod(obj, id, unit, modName, canShowResearch = true)
  {
    local mod = ::getModificationByName(unit, modName)
    if (!mod)
      return

    local modObj = obj.findObject(id)
    if (!modObj)
      modObj = ::weaponVisual.createItem(id, mod, weaponsItem.modification, obj, this)
    ::weaponVisual.updateItem(unit, mod, modObj, false, this, { canShowResearch = canShowResearch })
  }

  function updateButtons()
  {
    local currentItem = getCurRowTbl()
    if (!currentItem)
      return

    local navObj = scene.findObject("nav-help")
    if (!::checkObj(navObj))
      return

    local showBuyAllButton = !isAllBought()
    ::showBtn("btn_buy_all", showBuyAllButton, navObj)
    if (showBuyAllButton)
    {
      local buyAllBtnObj = navObj.findObject("btn_buy_all")
      if (::checkObj(buyAllBtnObj))
        buyAllBtnObj.inactiveColor = isAllNotPurchasable() ? "yes" : "no"
    }

    local changeResObj = navObj.findObject("btn_change_research")
    if (::checkObj(changeResObj))
      changeResObj.inactiveColor = currentItem.setItem == "" ? "yes" : "no"
  }

  function onRowSelect()
  {
    updateButtons()
  }

  function onModificationTooltipOpen(obj)
  {
    local idx = ::getObjIdByPrefix(obj, "tooltip_mod_done_")
    local modField = "prevModName"
    if (idx==null)
    {
      idx = ::getObjIdByPrefix(obj, "tooltip_mod_start_")
      modField = "setItem"
    }
    if (idx==null || !(idx.tointeger() in statementTablesArray))
      return
    local dataTable = statementTablesArray[idx.tointeger()]
    if (!dataTable)
      return

    local unit = dataTable.unit
    local modItem = ::getModificationByName(unit, dataTable[modField])
    if (modItem)
      ::weaponVisual.updateWeaponTooltip(obj, unit, modItem, this)
  }

  function prepareNextResearchBlocks(curRowObj, haveMod)
  {
    local arrowObj = curRowObj.findObject("horizontal_arrow")
    if (::checkObj(arrowObj))
      arrowObj.show(haveMod)

    local noResearchObj = curRowObj.findObject("no_next_research_block")
    if (::checkObj(noResearchObj))
      noResearchObj.show(!haveMod)

    local nextResearchObj = curRowObj.findObject("research_start")
    if (::checkObj(nextResearchObj))
      nextResearchObj.show(haveMod)
  }

  function setNoResearchText(nestObj, unit, isMod)
  {
    prepareNextResearchBlocks(nestObj, false)

    local noResearchObj = nestObj.findObject("no_next_research_block")
    if (!::checkObj(noResearchObj))
      return

    local suffics = "noUnits"
    if (isMod)
      suffics = "noModifications"
    else if (::isUnitElite(unit))
      suffics = "eliteUnit"

    local textObj = noResearchObj.findObject("no_next_research_text")
    if (::checkObj(textObj))
      textObj.setValue(::loc("mainmenu/nextResearch/" + suffics))
  }

  function createDivideLineObj(nextObj, blockType)
  {
    local divObj = scene.findObject("divide_row")
    local clonedObj = divObj.getClone(nextObj, this)
    if (::checkObj(clonedObj))
    {
      clonedObj.show(true)
      local divText = clonedObj.findObject("divide_text")
      if (::checkObj(divText))
      {
        divText.setValue(::loc("mainmenu/btn" + blockType))
        statementTablesArray.append(null)
      }
    }
  }

  function getCurRowTbl()
  {
    if (!::check_obj(researchTableObj) || !researchTableObj?.cur_row)
      return null

    local idx = researchTableObj.cur_row.tointeger()
    return (idx in statementTablesArray)? statementTablesArray[idx] : null
  }

  function changeResearch()
  {
    local reqTable = getCurRowTbl()
    if (!reqTable)
      return

    if (reqTable.setItem != "")
      ::gui_start_choose_next_research(reqTable.researchInfo)
    else
    {
      local suffics = "noUnits"
      if (reqTable.isMod)
        suffics = "noModifications"
      else if (::isUnitElite(reqTable.unit))
        suffics = "eliteUnit"

      msgBox("no_setItem", ::loc("mainmenu/nextResearch/" + suffics), [["ok", function() {} ]], "ok")
    }
  }

  function onEventModalWndDestroy(params)
  {
    base.onEventModalWndDestroy(params)
    local reqTable = getCurRowTbl()
    if (!reqTable)
      return

    local researchingItem = reqTable.isMod
                            ? ::shop_get_researchable_module_name(reqTable.unitName)
                            : ::shop_get_researchable_unit_name(reqTable.country, ::get_es_unit_type(reqTable.unit))

    reqTable.isItemApproved = reqTable.isItemApproved ||
                              (("handler" in params && params.handler instanceof ::gui_handlers.nextResearchChoice)
                                ? true : researchingItem != reqTable.setItem)

    reqTable.setItem = researchingItem
    reInitTable()
  }

  function reInitTable()
  {
    foreach(idx, table in statementTablesArray)
    {
      local result = fillRowByTable(table)
      if (!result)
        continue
    }
    updateButtons()
  }

  function endApproving()
  {
    statementTablesArray.reverse()
    acceptNotApprovedItems()
  }

  function flushItemExp(item, setName, afterDoneFunc = null)
  {
    local needFlushExp = false
    if (item.isMod)
      needFlushExp = ::shop_get_unit_excess_exp(item.unitName) > 0
    else
      needFlushExp = ::shop_get_country_excess_exp(item.country, ::get_es_unit_type(item.unit)) > 0

    if (!needFlushExp)
    {
      if (afterDoneFunc)
        afterDoneFunc()
      return
    }

    if (item.isMod)
      taskId = ::flushExcessExpToModule(item.unitName, setName)
    else
      taskId = ::flushExcessExpToUnit(setName)

    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      afterSlotOp = afterDoneFunc
      afterSlotOpError = (@(afterDoneFunc) function(res) { if (afterDoneFunc) afterDoneFunc() })(afterDoneFunc)
    }
    else if (afterDoneFunc)
      afterDoneFunc()
  }

  function acceptNotApprovedItems()
  {
    if (statementTablesArray.len() == 0)
    {
      needDoneMsgBox = true
      base.goBack()
      return
    }

    local config = statementTablesArray.remove(0)
    if (!config)
      acceptNotApprovedItems()
    else if (config.isItemApproved)
      removeNotUsingArray(config.researchInfo)
    else
    {
      if (config.setItem == (config.isMod? config.prevModName : config.unitName))
      {
        removeNotUsingArray(config.researchInfo)
        return
      }

      haveAnyAvailableResearches = true
      if (config.isMod)
        taskId = ::shop_set_researchable_unit_module(config.unitName, config.setItem)
      else
        taskId = ::setOrClearNextUnitToResearch(::getAircraftByName(config.setItem), config.country, ::get_es_unit_type(config.unit))

      if (taskId >= 0)
      {
        ::set_char_cb(this, slotOpCb)
        showTaskProgressBox()
        afterSlotOp = (@(config) function() {
          if (config.isMod && config.setItem!="")
            flushItemExp(config, config.setItem, (@(config) function() {
              removeNotUsingArray(config.researchInfo)
            })(config))
          else
            removeNotUsingArray(config.researchInfo)
        })(config)
        afterSlotOpError = (@(config) function(result) {
          removeNotUsingArray(config)
        })(config)
      }
      else
        removeNotUsingArray(config)
    }
  }

  function removeNotUsingArray(research, useCycle = true)
  {
    if (research)
    {
      if (!::isResearchAbandoned(research))
        ::abandoned_researched_items_for_session.append(research)

      foreach(idx, newResearch in ::researched_items_table)
        if (::isResearchEqual(research, newResearch))
        {
          ::researched_items_table.remove(idx)
          break
        }
    }
    if (useCycle)
      acceptNotApprovedItems()
  }

  function onBuyAll()
  {
    buyQueue = []
    local totalPrice = 0
    local itemsSkipped = []
    foreach (item in statementTablesArray)
    {
      if (item && !isItemBought(item))
      {
        if (canBuyItem(item))
        {
          buyQueue.append(item)
          totalPrice += getItemPrice(item)
        }
        else
        {
          itemsSkipped.append(item)
        }
      }
    }

    local nothingToBuy = buyQueue.len() == 0
    local somethingWasSkipped = itemsSkipped.len() != 0

    if (nothingToBuy && isAllBought())
    {
      msgBox("msg_cant_buy_anything", ::loc("msgbox/all_researched_items_bought"), [["ok", function () {}]], "ok")
      return
    }

    local mboxComment = null
    if (somethingWasSkipped)
    {
      local skipList = ""
      foreach (item in itemsSkipped)
      {
        local text = "<color=@activeTextColor>" + getItemNameLoc(item) + "</color>"
        local reason = getCantBuyItemReason(item)
        if (reason != "")
          text += " (" + reason + ")"
        skipList += (skipList.len() ? ::loc("ui/comma") : "") + text
      }

      local comment = ::loc(nothingToBuy ? "multi_purchase/those_items_wont_be_bought/list" : "multi_purchase/everything_will_be_bought_except/list")
      comment += ::loc("ui/colon") + skipList
      local data = ::format("textarea{overlayTextColor:t='bad'; text:t='%s'}", comment)
      mboxComment = { data_below_text = data }
    }

    if (nothingToBuy)
    {
      msgBox("msg_cant_buy_anything", ::loc("msgbox/cant_buy_any_researched_item"), [["ok", function () {}]], "ok", mboxComment)
      return
    }

    local price = ::Cost(totalPrice, 0)
    local msgText = ::format(::loc("shop/needMoneyQuestion_all_researched"), price.getTextAccordingToBalance())
    msgBox("msgbox_buy_all", msgText, [
      ["ok", function () {
        if (::check_balance_msgBox(price))
          buyNext()

      }],
      ["cancel", @() buyQueue = [] ]
    ], "ok", mboxComment)
  }

  function onBuyItem()
  {
    local itemToBuy = getCurRowTbl()
    if (!itemToBuy)
      return

    buyItem(itemToBuy)
  }

  function buyItem(itemToBuy)
  {
    if (isItemBought(itemToBuy))
      return msgBox("msg_item_bought", ::loc("msgbox/item_bought"), [["ok", function () {}]], "ok")

    buyQueue = [ itemToBuy ]
    buyNext(false)
  }

  function updateBoughtItems()
  {
    fillGamercard()
    reInitTable()
  }

  function buyNext(silent = true)
  {
    if (!buyQueue || !buyQueue.len())
      return updateBoughtItems()
    local itemToBuy = buyQueue.pop()

    if (isItemBought(itemToBuy))
    {
      if (silent)
        return buyNext(silent)
      else
        return msgBox("msg_item_bought", ::loc("msgbox/item_bought"), [["ok", function () {}]], "ok")
    }

    local success = itemToBuy.isMod ? buyModification(itemToBuy.unit, itemToBuy.prevModName, silent) : ::buyUnit(itemToBuy.unit, silent)

    if (!success)
      return buyNext(silent)
  }

  function canBuyItem(item)
  {
    if (!item)
      return true
    return item.isMod ? canBuyModification(item.unit, item.prevModName) : ::canBuyUnit(item.unit)
  }

  function isItemBought(item)
  {
    if (!item)
      return true
    return item.isMod ? isModificationBought(item.unit, item.prevModName) : ::isUnitBought(item.unit)
  }

  function isAllBought()
  {
    foreach (item in statementTablesArray)
      if (item && !isItemBought(item))
        return false
    return true
  }

  function isAllNotPurchasable()
  {
    foreach (item in statementTablesArray)
      if (item && !isItemBought(item) && canBuyItem(item))
        return false
    return true
  }

  function getCantBuyItemReason(item)
  {
    if (!item)
      return ""
    return item.isMod ? getCantBuyModificationReason(item.unit, item.prevModName) : ::getCantBuyUnitReason(item.unit)
  }

  function getItemPrice(item)
  {
    if (item.isMod)
      return ::wp_get_modification_cost(item.unitName, item.prevModName)
    else
      return ::wp_get_cost(item.unitName)
  }

  function getItemNameLoc(item)
  {
    if (item.isMod)
      return getModificationName(item.unitName, item.prevModName)
    return ::getUnitName(item.unit, true)
  }

  function buyModification(unit, modName, silent = true)
  {
    local mod = ::getModificationByName(unit, modName)
    local price = ::weaponVisual.getItemCost(unit, mod)
    if (!::check_balance_msgBox(price))
      return false

    if (!canBuyModification(unit, modName))
    {
      if (!silent)
      {
        if (isModificationBought(unit, modName))
          msgBox("msg_item_bought", ::loc("msgbox/item_bought"), [["ok", function () {}]], "ok")
        else
          checkPrevModification(unit, modName)
      }
      return false
    }

    if (silent)
      return impl_buyModification(unit, modName)

    local nameLoc = getModificationName(unit.name, modName)
    local buyMsgText = warningIfGold(
      ::loc("onlineShop/needMoneyQuestion",
        {purchase = nameLoc, cost = price.getTextAccordingToBalance()}),
      price)
    msgBox("msgbox_buy_item" , buyMsgText, [["ok", (@(unit, modName) function () {
                                      impl_buyModification(unit, modName)
                                 })(unit, modName)], ["cancel", function () {}]], "ok"
    )
    return true
  }

  function impl_buyModification(unit, modName)
  {
    taskId = ::shop_purchase_modification(unit.name, modName, 1, false)

    if (taskId < 0)
      return false

    ::set_char_cb(this, slotOpCb)
    showTaskProgressBox(::loc("charServer/purchase"))
    afterSlotOp = (@(unit, modName) function() {afterBuyModOp(unit, modName)})(unit, modName)
    return true
  }

  function onEventOnlineShopPurchaseSuccessful(params)
  {
    doWhenActiveOnce("updateBoughtItems")
  }

  function afterBuyModOp(unit, modName)
  {
    ::broadcastEvent("ModBought", {unitName = unit.name, modName = modName})
    if (::checkObj(scene))
    {
      fillGamercard()
      ::updateAirAfterSwitchMod(unit, modName)
      buyNext()
    }
  }

  function onEventUnitBought(params)
  {
    buyNext()
  }

  function isModificationBought(unit, modName)
  {
    return ::shop_is_modification_purchased(unit.name, modName)
  }

  function isPrevModificationBought(unit, modName)
  {
    local mod = ::getModificationByName(unit, modName)
    if (!mod)
      return true

    local prevName = null
    if ("reqModification" in mod && mod.reqModification.len())
      prevName = mod.reqModification[0]
    else if ("prevModification" in mod)
      prevName = mod.prevModification

    return prevName ? isModificationBought(unit, prevName) : true
  }

  function canBuyModification(unit, modName)
  {
    local mod = ::getModificationByName(unit, modName)
    if (!mod)
      return false
    return ::canBuyMod(unit, mod)
  }

  function getCantBuyModificationReason(unit, modName)
  {
    if (isModificationBought(unit, modName))
      return ::loc("msgbox/item_bought")

    if (!isPrevModificationBought(unit, modName))
      return ::loc("mainmenu/buyPreviousModification")

    return ""
  }

  function checkPrevModification(unit, modName)
  {
    local mod = ::getModificationByName(unit, modName)
    if (!mod)
      return true

    if (!isPrevModificationBought(unit, modName))
    {
      local reqMods = ::weaponVisual.getReqModsText(unit, mod)
      local reason = ::format(::loc("weaponry/action_not_allowed"), ::loc("weaponry/unlockModsReq") + "\n" + reqMods)
      msgBox("cant_buy_mod", reason, [["ok", function () {}]], "ok")
      return false
    }
    return true
  }

  function goBack()
  {
    if (statementTablesArray.len())
      endApproving()
    else
      base.goBack()
  }

  function afterModalDestroy()
  {
    needDoneMsgBox = needDoneMsgBox && !::checkNonApprovedResearches(true) && haveAnyAvailableResearches

    if (!needDoneMsgBox)
      return

    local handler = this
    msgBox("ended_approving_items", ::loc("msgbox/approvingModsEnded"),
      [["ok", (@(handler) function() {::checkNotBoughtModsAfterFinishedResearches(handler)})(handler) ]], "ok")
  }
}

::checkNotBoughtModsAfterFinishedResearches <- function checkNotBoughtModsAfterFinishedResearches(handler, afterFunc = null)
{
  local cost = 0
  local unitsWithNBMods = []
  local unitsAndModsTableForDebug = {}
  local stringOfUnits = ""
  foreach(unitName, unit in ::units_with_finished_researches)
  {
    local NBMods = []
    local isUnitHaveNBMods = false
    foreach(mod in unit.modifications)
      if (::canBuyMod(unit, mod)
          && getAmmoMaxAmount(unit, mod.name, AMMO.MODIFICATION) == 1
          && !::wp_get_modification_cost_gold(unitName, mod.name))
      {
        isUnitHaveNBMods = true
        NBMods.append(mod.name)
        cost += ::wp_get_modification_cost(unitName, mod.name)
      }
    if (isUnitHaveNBMods)
    {
      unitsAndModsTableForDebug[unitName] <- NBMods
      unitsWithNBMods.append(unit)
      stringOfUnits += (stringOfUnits==""? "" : ", ") + ::getUnitName(unit, true)
    }
  }

  ::units_with_finished_researches = {}
  if (cost == 0)
    return

  ::dagor.debug("List of not purchased mods for units")
  debugTableData(unitsAndModsTableForDebug)

  local price = ::Cost(cost, 0)
  ::scene_msg_box("buy_all_available_mods", null,
    ::loc("msgbox/buy_all_researched_modifications",
          { unitsList = stringOfUnits, cost = price.getTextAccordingToBalance() }),
    [
      ["yes", function() {
      if (!::check_balance_msgBox(cost))
        return

      local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/purchase"), null, null)
      ::buyModsForUnitAndGoNext(handler, afterFunc, progressBox, unitsWithNBMods)
      }],
      ["no", @() null ]
    ],
    "yes", { cancel_fn = @() null })
}

::buyModsForUnitAndGoNext <- function buyModsForUnitAndGoNext(handler, afterFunc, progressBox, unitsArray)
{
  if (unitsArray.len() == 0)
  {
    ::scene_msg_box("successfully_bought_mods", null, ::loc("msgbox/all_researched_modifications_bought"),
      [["ok", (@(handler, afterFunc, progressBox) function() {
        ::destroyMsgBox(progressBox)
        if (afterFunc)
          afterFunc.call(handler)
      })(handler, afterFunc, progressBox)]], "ok")
    return
  }

  local curUnit = unitsArray.remove(0)
  local taskId = ::buyAllMods(curUnit.name, false)
  ::add_bg_task_cb(taskId, (@(handler, afterFunc, curUnit, progressBox, unitsArray) function() {
      ::updateAirAfterSwitchMod(curUnit, "")
      ::buyModsForUnitAndGoNext(handler, afterFunc, progressBox, unitsArray)
    })(handler, afterFunc, curUnit, progressBox, unitsArray)
  )
}

class ::gui_handlers.researchUnitNotification extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/researchedModifications.blk"

  researchBlock = null
  unit = null

  function initScreen()
  {
    if (!researchBlock)
    {
      goBack()
      return
    }

    local unitName = ::getTblValue(::researchedUnitForCheck, researchBlock)
    unit = ::getAircraftByName(unitName)
    if (!unit)
    {
      goBack()
      return
    }

    updateResearchedUnit()
    updateButtons()
  }

  function updateResearchedUnit()
  {
    local placeObj = getUnitPlaceObj()
    if (!::checkObj(placeObj))
      return

    local unit_blk = ::build_aircraft_item(unit.name, unit)
    guiScene.replaceContentFromText(placeObj, unit_blk, unit_blk.len(), this)
    ::fill_unit_item_timers(placeObj.findObject(unit.name), unit)
  }

  function onEventCrewTakeUnit(params)
  {
    goBack()
  }

  function onEventUnitBought(params)
  {
    if(::getTblValue("unitName", params) != unit.name)
    {
      purchaseUnit()
      return
    }

    updateResearchedUnit()
    updateButtons()
    trainCrew()
  }

  function getUnitPlaceObj()
  {
    if (!::checkObj(scene))
      return null

    return scene.findObject("rankup_aircraft_table")
  }

  function updateButtons()
  {
    ::show_facebook_screenshot_button(scene)

    local isBought = ::isUnitBought(unit)
    local isUsable = ::isUnitUsable(unit)

    showSceneBtn("btn_buy", !isBought)
    showSceneBtn("btn_exit", isBought)
    showSceneBtn("btn_trainCrew", isUsable)
  }

  function purchaseUnit()
  {
    ::buyUnit(unit)
  }

  function trainCrew()
  {
    if (!::isUnitUsable(unit))
      return

    ::gui_start_selecting_crew({
      unit = unit
      unitObj = scene.findObject(unit.name)
      cellClass = "slotbarClone"
      isNewUnit = true
    })
  }
}

class ::gui_handlers.nextResearchChoice extends ::gui_handlers.showAllResearchedItems
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/nextModificationChoice.blk"

  researchBlock = null
  researchConfig = null
  needFlushExp = false
  flushExpNum = 0

  curColIdx = 0
  curRowIdx = 0
  itemsTable = null
  unitName = null

  unitsInTr = 4

  function initScreen()
  {
    if (!scene || !researchBlock)
      return goBack()

    researchConfig = generateResearchConfig(researchBlock)
    if (!researchConfig)
      return goBack()

    local guiScene = ::get_gui_scene()
    local parentObj = guiScene["researchedModifications_main_frame"]
    if (::checkObj(parentObj))
    {
      local parentHeight = parentObj.getSize()[1]
      local curFrame = scene.findObject("nextModificationChoice_wnd")
      if (::checkObj(curFrame))
        curFrame["min-height"] = parentHeight
    }
    unitName = researchConfig.unitName

    updateAll()

    local timerObj = scene.findObject("nextMod_timer")

    local handler = this
    local func = function(nestObj){reInitCurrentUnit(nestObj)}
    if (::getUnitRepairCost(researchConfig.unit) > 0 && ::checkObj(timerObj))
      SecondsUpdater(timerObj, (@(handler, scene, researchConfig, func) function(obj, params) {
        local repairPrice = ::getUnitRepairCost(researchConfig.unit)
        local isBroken = repairPrice > 0
        local repairBtnId = "btn_repair"
        ::showBtn(repairBtnId, isBroken, scene)
        if (isBroken)
          ::placePriceTextToButton(scene, repairBtnId, ::loc("mainmenu/btnRepair"), repairPrice)
        else
          func.call(handler, scene)

        return !isBroken
      })(handler, scene, researchConfig, func))
  }

  function updateAll()
  {
    if (!::checkObj(scene))
      return

    updateResearchedItem()

    itemsTable = []
    if (researchConfig.isMod)
    {
      flushExpNum = ::shop_get_unit_excess_exp(unitName)
      fillAvailableMods(researchConfig.unit)
    }
    else
    {
      flushExpNum = ::shop_get_country_excess_exp(researchConfig.country, ::get_es_unit_type(researchConfig.unit))
      fillAvailableUnits(researchConfig.unit)
    }

    if (itemsTable.len())
      fillRPText()
    else
      scene.findObject("choose_next_research").show(false)

    fillGamercard()
    updateButtons()
  }

  function reInitCurrentUnit(obj)
  {
    if (!::checkObj(obj))
      return

    local unit = researchConfig.unit
    local finishedResObj = obj.findObject("cur_air_place")
    local data = ::build_aircraft_item(unit.name, unit)
    guiScene.replaceContentFromText(finishedResObj, data, data.len(), this)
    ::fill_unit_item_timers(finishedResObj.findObject(unit.name), unit)
    ::showUnitDiscount(finishedResObj.findObject(unit.name + "-discount"), unit)
  }

  function updateResearchedItem()
  {
    reInitCurrentUnit(scene)
    local unit = researchConfig.unit

    local buyBtnId = "btn_buy"
    local showBtnBuy = !isItemBought(researchConfig)
    showSceneBtn(buyBtnId, showBtnBuy)
    if (showBtnBuy)
      ::placePriceTextToButton(scene, buyBtnId, ::loc("mainmenu/btnBuy"), getItemPrice(researchConfig))

    if (!researchConfig.isMod)
      return

    local mod = ::getModificationByName(unit, researchBlock.prevMod)
    if (!mod)
      return goBack()

    local finishedModObj = scene.findObject("finished_modification_place")
    finishedModObj.show(true)

    local id = "mod_" + mod.name
    local modObj = finishedModObj.findObject(id)
    if (!modObj)
      modObj = ::weaponVisual.createItem(id, mod, weaponsItem.modification, finishedModObj, this)
    ::weaponVisual.updateItem(unit, mod, modObj, false, this)
  }

  function onRepair()
  {
    local repairPrice = ::getUnitRepairCost(researchConfig.unit)
    if (::check_balance_msgBox(::Cost(repairPrice, 0), afterSlotOp))
    {
      taskId = shop_repair_aircraft(researchConfig.unitName)
      if (taskId >= 0)
      {
        ::set_char_cb(this, slotOpCb)
        showTaskProgressBox()
      }
    }
  }

  function fillRPText()
  {
    local freeRPObj = scene.findObject("available_free_exp_text")
    needFlushExp = ::checkObj(freeRPObj) && flushExpNum > 0
    if (!needFlushExp)
      return

    freeRPObj.show(true)
    freeRPObj.setValue(::format(::loc("mainmenu/availableFreeExpForNewResearch"), flushExpNum.tostring()))
  }

  function fillAvailableMods(unit)
  {
    local researchesArray = []
    local blankCell = []
    local selIdx = 0
    foreach(idx, block in unit.modifications)
    {
      block["type"] <- weaponsItem.modification
      if (::weaponVisual.canResearchItem(unit, block, false))
      {
        researchesArray.append(block)
        blankCell.append("td{id:t='" + block.name + "';}")
        itemsTable.append(block.name)
        if (block.name == researchConfig.setItem)
          selIdx = itemsTable.len() - 1
      }
    }

    local isGood = fillResearchesTable(blankCell, selIdx, null)
    showNoResearchText(!isGood)
    if (!isGood)
      return

    local tableObj = scene.findObject("new_researches_block")
    tableObj.show(true)
    foreach(idx, mod in researchesArray)
    {
      local obj = tableObj.findObject(mod.name)
      if (!::checkObj(obj))
        continue

      local modObj = ::weaponVisual.createItem("mod_" + mod.name, mod, weaponsItem.modification, obj, this)
      ::weaponVisual.updateItem(unit, mod, modObj, false, this, {
                                  canShowResearch = false,
                                  flushExp = flushExpNum
                                })

      local row = idx/unitsInTr
      local col = idx - row*unitsInTr
      local bodyObj = obj.findObject("centralBlock")
      bodyObj.row = row
      bodyObj.col = col
    }
  }

  function fillAvailableUnits(unit)
  {
    local unitsArray = []
    local unitItems = []
    local unitType = ::get_es_unit_type(unit)
    local selIdx = 0
    foreach(item in ::all_units)
      if (item.shopCountry == unit.shopCountry &&
          ::get_es_unit_type(item) == unitType &&
          unit.isVisibleInShop() &&
          ::canResearchUnit(item) &&
          !::isUnitResearched(item) &&
          !::canBuyUnit(item)
         )
      {
        local params = {
          forceNotInResearch = true,
          flushExp = flushExpNum
        }
        unitsArray.append(::build_aircraft_item(item.name, item, params))
        unitItems.append({ id = item.name, unit = item, params = params })
        itemsTable.append(item.name)
        if (item.name == researchConfig.setItem)
          selIdx = itemsTable.len() - 1
      }

    local isGood = fillResearchesTable(unitsArray, selIdx, unitItems)
    showNoResearchText(!isGood)
    if (!isGood)
      return
  }

  function showNoResearchText(show)
  {
    local arrowObj = scene.findObject("vertical_arrow")
    if (::checkObj(arrowObj))
      arrowObj.show(!show)

    local textObj = scene.findObject("new_research_change_later_text")
    if (::checkObj(textObj))
      textObj.show(!show)

    textObj = scene.findObject("no_researches")
    if (::checkObj(textObj))
    {
      textObj.show(show)
      textObj.setValue(::loc("mainmenu/nextResearch/" + (researchConfig.isMod? "noModifications" : "noUnits")))
    }
  }

  function fillResearchesTable(unitsArray, selIdx, unitItems = null)
  {
    if (unitsArray.len() == 0)
      return false

    local emptyTd = unitsInTr*(1 - (unitsArray.len().tofloat()/unitsInTr - unitsArray.len()/unitsInTr))
    unitsArray.resize(unitsArray.len() + emptyTd, "")

    local data = ""

    for(local j = 0; j < unitsArray.len();  j+=unitsInTr)
    {
      local singleTr = ""
      for(local i = 0; i < unitsInTr; i++)
        singleTr += unitsArray[i+j]
      data += ::format("tr{%s}", singleTr)
    }

    local tableObj = scene.findObject("new_researches_block")
    tableObj.show(true)
    guiScene.replaceContentFromText(tableObj, data, data.len(), this)
    foreach (unitItem in unitItems)
      ::fill_unit_item_timers(tableObj.findObject(unitItem.id), unitItem.unit, unitItem.params)
    local row = ::floor(selIdx/unitsInTr)
    local col = (selIdx % unitsInTr)
    tableObj.cur_row = row.tostring()
    tableObj.cur_col = col.tostring()
    tableObj.select()
    onModItemSelect(tableObj)
    ::gui_bhv.columnNavigator.selectCell(tableObj, row, col, true)

    if (!researchConfig.isMod)
      foreach(idx, unitId in itemsTable)
        ::showAirDiscount(tableObj.findObject(unitId + "-discount"), unitId)

    local textObj = scene.findObject("new_research_change_later_text")
    if (::checkObj(textObj))
      textObj.setValue(::loc("mainmenu/nextResearch/canChangeLater/" + (researchConfig.isMod? "modification" : "unit")))

    return true
  }

  function onModificationTooltipOpen(obj)
  {
    local idx = ::getObjIdByPrefix(obj, "tooltip_mod_")
    if (idx==null)
      idx = ::getObjIdByPrefix(obj, "finished_mod_")

    if (idx==null)
      return

    local unit = ::getAircraftByName(unitName)
    local modItem = ::getModificationByName(unit, idx)
    if (modItem)
      ::weaponVisual.updateWeaponTooltip(obj, unit, modItem, this)
  }

  function onModItemClick(obj)
  {
    if (obj.row.tointeger() >= 0 && obj.col.tointeger() >= 0)
      ::gui_bhv.columnNavigator.selectCell(scene.findObject("new_researches_block"), obj.row.tointeger(), obj.col.tointeger(), true)
  }

  function onModItemSelect(obj)
  {
    curRowIdx = obj.cur_row.tointeger()
    curColIdx = obj.cur_col.tointeger()

    local idx = curRowIdx*unitsInTr + curColIdx
    if (idx >= 0 && idx <= itemsTable.len()-1)
      researchConfig.setItem = itemsTable[idx]

    updateButtons()
  }

  function updateButtons()
  {
    local btnObj = scene.findObject("btn_apply")
    if (!::checkObj(btnObj))
      return

    if (!itemsTable.len())
    {
      ::setDoubleTextToButton(scene, "btn_apply", ::loc("mainmenu/btnOk"))
      return
    }

    local idx = curRowIdx*unitsInTr + curColIdx
    if (itemsTable.len()-1 < idx)
      return

    local reqExp = 0
    local itemName = itemsTable[idx]
    if (researchConfig.isMod)
    {
      local unit = ::getAircraftByName(unitName)
      local modItem = ::getModificationByName(unit, itemName)
      reqExp = modItem.reqExp
    }
    else
    {
      local unit = ::getAircraftByName(itemName)
      reqExp = unit.reqExp
    }

    local coloredText = ""
    local simpleText = ""
    if (flushExpNum > 0)
    {
      local textBlank = "%s (%s %s)"
      local showExp = reqExp <= flushExpNum? reqExp : flushExpNum
      coloredText = ::format(textBlank, ::loc("weaponry/research"), showExp.tostring(), ::loc("currency/researchPoints/sign/colored"))
      simpleText = ::format(textBlank, ::loc("weaponry/research"), showExp.tostring(), ::loc("currency/researchPoints/sign"))
    }
    else
    {
      coloredText = ::loc("mainmenu/startToResearch")
      simpleText = coloredText
    }
    setDoubleTextToButton(scene, "btn_apply", simpleText, coloredText)
  }

  function onAccept()
  {
    local itemName = ""
    local idx = curRowIdx*unitsInTr + curColIdx
    if (idx < itemsTable.len())
      itemName = itemsTable[idx]
    else if (itemsTable.len())
      itemName = itemsTable[0]

    if (::isResearchAbandoned(researchBlock) && (researchConfig.setItem == itemName))
      return base.goBack()

    setItemToResearch(itemName)
  }

  function setItemToResearch(itemName)
  {
    if (researchConfig.isMod)
    {
      researchBlock.mod = itemName
      taskId = ::shop_set_researchable_unit_module(unitName, itemName)
    }
    else
    {
      researchBlock.unit = itemName
      taskId = ::setOrClearNextUnitToResearch(::getAircraftByName(itemName), researchConfig.country, ::get_es_unit_type(researchConfig.unit))
    }

    if (taskId >= 0 && itemName!="")
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      afterSlotOp = (@(needFlushExp, researchConfig, unitName, itemName) function() {
        if (needFlushExp)
          flushItemExp(researchConfig, itemName, base.goBack)
        else
          base.goBack()
      })(needFlushExp, researchConfig, unitName, itemName)
      return
    }
    base.goBack()
  }

  function afterModalDestroy()
  {
    if (researchBlock)
      removeNotUsingArray(researchBlock, false)

    local handler = this
    local afterCheckAction = function(foundNext){
      ::broadcastEvent("ModBought", {unitName = researchConfig.unit.name})
      if (!foundNext && !::isHandlerInScene(::gui_handlers.showAllResearchedItems))
        ::checkNonApprovedResearches(false)
    }

    local foundNext = false
    if (researchConfig)
    {
      if (researchConfig.isMod)
        foundNext = ::checkNewModuleResearchForUnit(researchConfig.unit)
      else
        foundNext = ::checkNewUnitResearchForCountry(researchConfig.country, ::get_es_unit_type(researchConfig.unit))

      if (researchConfig.isMod && !foundNext)
      {
        if (!(researchConfig.unit.name in ::units_with_finished_researches))
          ::units_with_finished_researches[researchConfig.unit.name] <- researchConfig.unit
        ::checkNotBoughtModsAfterFinishedResearches(handler, (@(handler, afterCheckAction) function() {afterCheckAction.call(handler, false)})(handler, afterCheckAction))
        return
      }
    }

    afterCheckAction.call(handler, foundNext)
  }

  function onBuy()
  {
    buyItem(researchConfig)
  }

  function updateBoughtItems()
  {
    updateAll()
  }

  function onModItemDblClick(obj)
  {
    local modId = getObjIdByPrefix(obj, "mod_", "holderId")
    if (researchConfig.isMod && researchConfig.prevModName != modId)
      onAccept()
  }

  function goBack()
  {
    if (!itemsTable)
      return base.goBack()

    onAccept()
  }
}
