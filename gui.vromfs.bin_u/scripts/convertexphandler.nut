local unitTypes = require("scripts/unit/unitTypesList.nut")
local { research } = require("scripts/unit/unitActions.nut")
local { isEqual } = require("sqStdLibs/helpers/u.nut")
local { shopCountriesList } = require("scripts/shop/shopCountriesList.nut")

enum windowState
{
  research,
  canBuy,
  noUnit
}

::gui_modal_convertExp <- function gui_modal_convertExp(unit = null)
{
  if (!::has_feature("SpendGold") || !::has_feature("SpendFreeRP"))
    return
  if (unit && !::can_spend_gold_on_unit_with_popup(unit))
    return

  ::gui_start_modal_wnd(::gui_handlers.ConvertExpHandler, {unit = unit})
}

class ::gui_handlers.ConvertExpHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType         = handlerType.MODAL
  sceneBlkName    = "gui/convertExp/convertExp.blk"

  expPerGold      = 1
  maxGoldForAir   = 0
  curGoldValue    = 0
  minGoldValue    = 0
  maxGoldValue    = 0

  availableExp    = 0
  playersGold     = 0

  unit            = null
  unitExpGranted  = 0
  unitReqExp      = 0

  country         = ""
  countries       = null

  unitList        = null
  listType        = 0
  unitTypesList   = null
  currentState    = windowState.noUnit

  isRefreshingAfterConvert = false

  function initScreen()
  {
    if (!scene)
      return goBack()

    unitList = []
    unitTypesList = []

    initUnitTypes()
    initCountriesList()
    updateData()

    if (availableExp < expPerGold)
    {
      goBack()
      showNoRPmsgbox()
      return
    }

    if (!unit)
      unit = getAvailableUnitForConversion()

    listType = ::get_es_unit_type(unit)
    updateWindow()
  }

  function updateData()
  {
    updateUserCurrency()
    expPerGold = ::wp_get_exp_convert_exp_for_gold_rate(country) || 1

    if (currentState != windowState.noUnit)
    {
      unitExpGranted = ::getUnitExp(unit)
      unitReqExp = ::getUnitReqExp(unit)
    }
    else
    {
      unitExpGranted = 0
      unitReqExp = 0
    }
  }

  function updateUserCurrency()
  {
    availableExp = ::shop_get_free_exp()
    playersGold = max(::get_balance().gold, 0)
  }

  function loadUnitList(unitType)
  {
    unitList = []
    foreach (unitForList in ::all_units)
      if (unitForList.shopCountry == country
          && ::canResearchUnit(unitForList)
          && !unitForList.isSquadronVehicle()
          && ::get_es_unit_type(unitForList) == unitType)
        unitList.append(unitForList)
    local ediff = ::get_current_ediff()
    unitList.sort(@(a, b) a.getBattleRating(ediff) <=> b.getBattleRating(ediff))
  }

  function getCurExpValue()
  {
    local expToBuy = (curGoldValue - minGoldValue) * expPerGold
    if ((expToBuy + unitExpGranted) > unitReqExp && (unitReqExp - unitExpGranted <= availableExp))
      expToBuy = unitReqExp - unitExpGranted
    return expToBuy
  }

  function getCountryResearchUnit(countryName, unitType)
  {
    local unitName = ::shop_get_researchable_unit_name(countryName, unitType)
    return ::getAircraftByName(unitName)
  }

  //----VIEW----//
  function initCountriesList()
  {
    local curValue = 0
    country = ::get_profile_country_sq()

    local view = { items = [] }
    foreach(idx, countryItem in shopCountriesList)
    {
      view.items.append({
        id = countryItem
        disabled = !::isCountryAvailable(countryItem)
        image = ::get_country_icon(countryItem)
        tooltip = "#" + countryItem
        discountNotification = true
      })

      if (country == countryItem)
        curValue = idx
    }

    local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
    local countriesObj = scene.findObject("countries_list")
    guiScene.replaceContentFromText(countriesObj, data, data.len(), this)
    countriesObj.setValue(curValue)

    foreach(c in shopCountriesList)
      ::showDiscount(countriesObj.findObject(c + "_discount"), "exp_to_gold_rate", c)
  }

  function fillUnitList()
  {
    local isShow = unitList.len() > 1
    local nestObj = scene.findObject("choose_unit_list")
    nestObj.show(isShow)
    local unitListBlk = []
    foreach(unitForResearch in unitList)
      unitListBlk.append(::build_aircraft_item(unitForResearch.name, unitForResearch))
    unitListBlk = "".join(unitListBlk)
    guiScene.replaceContentFromText(nestObj, unitListBlk, unitListBlk.len(), this)
    nestObj.setValue(unitList.indexof(unit) ?? -1)
    foreach(unitForResearch in unitList)
      ::fill_unit_item_timers(nestObj.findObject(unitForResearch.name), unitForResearch)
  }

  function updateWindow()
  {
    local oldState = currentState
    if (!unit)
      currentState = windowState.noUnit
    else if (::canBuyUnit(unit) || ::isUnitResearched(unit))
      currentState = windowState.canBuy
    else
      currentState = windowState.research

    if (isRefreshingAfterConvert && oldState != currentState  && currentState == windowState.canBuy)
      ::add_big_query_record("completed_new_research_unit",
        ::save_to_json({ unit = unit.name
          howResearched = "convert_exp" }))

    updateData()
    fillContent()
    updateButtons()
    fillUnitList()
    updateUnitTypesList()
  }

  function showConversionUnit()
  {
    if (!unit)
      return goBack()

    local unitBlk = ::build_aircraft_item(unit.name, unit)
    local unitNest = scene.findObject("unit_nest")
    guiScene.replaceContentFromText(unitNest, unitBlk, unitBlk.len(), this)
    ::fill_unit_item_timers(unitNest.findObject(unit.name), unit)
  }

  function fillFreeExp()
  {
    scene.findObject("available_exp").setValue(::g_language.decimalFormat(availableExp))
  }

  function initUnitTypes()
  {
    local listObj = scene.findObject("unit_types_list")
    if (!::check_obj(listObj))
      return

    unitTypesList = ::u.filter(unitTypes.types, @(unitType) unitType.isVisibleInShop())
    local view = { items = [] }
    foreach (idx, unitType in unitTypesList)
      view.items.append({
        id = unitType.armyId
        text = unitType.fontIcon + " " + unitType.getArmyLocName()
        tooltip = unitType.canSpendGold() ? null : ::loc("msgbox/unitTypeRestrictFromSpendGold")
      })

    local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
    guiScene.replaceContentFromText(listObj, data, data.len(), this)
  }

  function updateUnitTypesList()
  {
    local listObj = scene.findObject("unit_types_list")
    if (!::check_obj(listObj))
      return

    local curIdx = 0
    foreach (idx, unitType in unitTypesList)
    {
      local isShow = unitType.haveAnyUnitInCountry(country)
      local selected = isShow && listType == unitType.esUnitType
      if (selected)
        curIdx = idx

      local btnObj = ::showBtn(unitType.armyId, isShow, listObj)
      if (btnObj)
      {
        btnObj.inactive = getCountryResearchUnit(country, unitType.esUnitType)? "no" : "yes"
        btnObj.enable(unitType.canSpendGold())
      }
    }

    listObj.setValue(curIdx)
  }

  function fillSlider()
  {
    local sliderDivObj = scene.findObject("exp_slider_nest")
    if (!::checkObj(sliderDivObj))
      return

    local is_enough_availExp = availableExp > 0
    local is_need_to_convert = (unitReqExp - unitExpGranted) > 0

    local showExpSlider = is_enough_availExp && is_need_to_convert
    sliderDivObj.show(showExpSlider)

    if (showExpSlider)
    {
      local sliderObj     = sliderDivObj.findObject("convert_slider")
      local oldProgressOb = sliderDivObj.findObject("old_exp_progress")
      local newProgressOb = sliderDivObj.findObject("new_exp_progress")

      local diffExp = unitReqExp - unitExpGranted
      local maxGoldDiff = ::ceil(diffExp.tofloat() / expPerGold).tointeger()
      minGoldValue  = (unitExpGranted.tofloat() / expPerGold).tointeger()
      maxGoldForAir = minGoldValue + maxGoldDiff

      local goldLimitByExp  = (availableExp >= diffExp) ? maxGoldDiff : (availableExp.tofloat() / expPerGold).tointeger()
      maxGoldValue = minGoldValue + min(goldLimitByExp, playersGold)
      curGoldValue = maxGoldValue

      sliderObj.max     = maxGoldForAir
      oldProgressOb.max = maxGoldForAir
      newProgressOb.max = maxGoldForAir

      oldProgressOb.setValue(minGoldValue)
      updateSlider()
    }
  }

  function fillUnitResearchedContent()
  {
    local noExpObj = scene.findObject("buy_unit_cost")
    if (!::checkObj(noExpObj))
      return

    local unitCost = ::wp_get_cost(unit.name)
    noExpObj.setValue(::getPriceAccordingToPlayersCurrency(unitCost, 0, true))
  }

  function updateSlider()
  {
    local sliderObj = scene.findObject("convert_slider")
    local newProgressOb = scene.findObject("new_exp_progress")
    newProgressOb.setValue(curGoldValue)
    sliderObj.setValue(curGoldValue)

    updateSliderText()
    updateExpTextPosition()
  }

  function fillContent()
  {
    scene.findObject("exp_slider_nest").show(currentState == windowState.research)
    scene.findObject("available_exp_nest").show(currentState == windowState.research)
    scene.findObject("cost_holder").show(currentState == windowState.research)
    scene.findObject("unit_researched_nest").show(currentState == windowState.canBuy)
    scene.findObject("unit_nest").show(currentState != windowState.noUnit)

    local noUnitMsgObj = scene.findObject("no_unit_nest")
    local needNoUnitText = currentState == windowState.noUnit
    noUnitMsgObj.show(needNoUnitText)
    if (needNoUnitText)
      noUnitMsgObj.setValue(::loc(getAvailableUnitForConversion() != null ? ::loc("pr_conversion/no_unit") : ::loc("pr_conversion/all_units_researched")))

    if (currentState == windowState.research)
    {
      if (availableExp > expPerGold)
      {
        fillSlider()
        fillFreeExp()
        fillCostGold()
        showConversionUnit()
      }
      else
      {
        goBack()
        if (!isRefreshingAfterConvert)
          showNoRPmsgbox()
      }
    }
    else if (currentState == windowState.canBuy)
    {
      fillUnitResearchedContent()
      showConversionUnit()
    }
  }

  function showNoRPmsgbox()
  {
    if (!::checkObj(guiScene["no_rp_msgbox"]))
      msgBox("no_rp_msgbox", ::loc("msgbox/no_rp"), [["ok", function () {}]], "ok", { cancel_fn = function() {}})
  }

  function updateSliderText()
  {
    local sliderTextObj = scene.findObject("convert_slider_text")
    local strGrantedExp = ::Cost().setRp(unitExpGranted).tostring()
    local expToBuy = getCurExpValue()
    local strWantToBuyExp = expToBuy > 0
                            ? format("<color=@activeTextColor> +%s</color>", ::Cost().setFrp(expToBuy).tostring())
                            : ""
    local strRequiredExp = ::g_language.decimalFormat(::getUnitReqExp(unit))
    local sliderText = ::format("<color=@commonTextColor>%s%s%s%s</color>", strGrantedExp, strWantToBuyExp, ::loc("ui/slash"), strRequiredExp)
    sliderTextObj.setValue(sliderText)
  }

  function fillCostGold()
  {
    local costGoldObj = scene.findObject("convertion_cost")
    costGoldObj.setValue(::g_language.decimalFormat(curGoldValue-minGoldValue))
  }

  function updateButtons()
  {
    local isMinSet = curGoldValue == minGoldValue
    local isMaxSet = curGoldValue == maxGoldValue

    showSceneBtn("btn_apply", currentState == windowState.research)
    showSceneBtn("btn_buy_unit", currentState == windowState.canBuy)
    scene.findObject("btn_apply").inactiveColor = curGoldValue != minGoldValue ? "no" : "yes"

    scene.findObject("buttonDec").enable(!isMinSet)
    scene.findObject("buttonInc").enable(!isMaxSet)
    scene.findObject("btn_max").enable(!isMaxSet)
  }

  function updateExpTextPosition()
  {
    guiScene.setUpdatesEnabled(true, true)
    local textObj     = scene.findObject("convert_slider_text")
    local boxObj      = scene.findObject("exp_slider_nest")
    local textNestObj = scene.findObject("slider_button")

    local boxPosX      = boxObj.getPos()[0]
    local boxSizeX     = boxObj.getSize()[0]

    local textSizeX     = textObj.getSize()[0]

    local textNestPosX  = textNestObj.getPos()[0]
    local textNestSizeX = textNestObj.getSize()[0]

    local overdraft = (textNestPosX + (textSizeX + textNestSizeX) / 2) - (boxPosX + boxSizeX)

    local leftEdge = textNestPosX - 0.5*textSizeX

    local newLeft = textObj.base_left
    if (leftEdge < boxPosX)
      newLeft = textObj.base_left + " + " + (boxPosX - leftEdge).tostring()
    else if (overdraft > 0)
      newLeft = textObj.base_left + " - " + (overdraft).tostring()

    textObj.left = newLeft
  }

  function updateObjects()
  {
    updateSlider()
    fillCostGold()
    updateButtons()
  }
  //----END_VIEW----//

  //----CONTROLLER----//
  function onCountrySelect()
  {
    local c = scene.findObject("countries_list").getValue()
    if (!(c in shopCountriesList))
      return

    country = shopCountriesList[c]

    unit = getAvailableUnitForConversion()

    listType = ::get_es_unit_type(unit)
    updateWindow()

    //TODO: do this in updateWindow
    loadUnitList(::get_es_unit_type(unit))
    fillUnitList()

    ::showDiscount(scene.findObject("convert-discount"), "exp_to_gold_rate", country, null, true)
  }

  function onSwitchUnitType(obj)
  {
    local value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      value = 0

    local selObj = obj.getChild(value)

    local unitType = unitTypes.getByArmyId(selObj?.id)
    updateUnitList(unitType.esUnitType)
  }

  function updateUnitList(unitType)
  {
    listType = unitType
    unit = getCountryResearchUnit(country, unitType)
    loadUnitList(unitType)
    fillUnitList()
    updateWindow()
  }

  function onUnitSelect(obj)
  {
    local newUnit = unitList[obj.getValue()]
    local isNewUnitInResearch = ::isUnitInResearch(newUnit)
    local isNewUnitResearched = ::isUnitResearched(newUnit)
    local hasChangedUnit = !isEqual(newUnit, unit)
    if (!hasChangedUnit && (isNewUnitInResearch || isNewUnitResearched))
      return

    if (hasChangedUnit && !::checkForResearch(newUnit))
    {
      obj.setValue(unitList.indexof(unit))
      return
    }

    local cb = function() {
      unit = newUnit
      updateWindow()
    }
    if (isNewUnitInResearch || isNewUnitResearched) {
      cb()
      return
    }

    research(newUnit, true, ::Callback(cb, this))
  }

  function getAvailableUnitForConversion()
  {
    local newUnit = null
    //try to get unit of same type as previous unit is
    if (::isCountryHaveUnitType(country, ::get_es_unit_type(unit)))
      newUnit = getCountryResearchUnit(country, ::get_es_unit_type(unit))
    if (!newUnit)
    {
      foreach (unitType in unitTypes.types)
      {
        if (!unitType.canSpendGold())
          continue

        if (unitType.haveAnyUnitInCountry(country))
          newUnit = getCountryResearchUnit(country, unitType.esUnitType)

        if (newUnit)
          break
      }
    }
    return newUnit
  }

  function onConvertChanged(obj)
  {
    local value = obj.getValue()
    if (curGoldValue == value)
      return
    curGoldValue = min(max(minGoldValue, value), maxGoldValue)
    updateObjects()
  }

  function onButtonDec()
  {
    local value = curGoldValue - 1
    curGoldValue = min(max(minGoldValue, value), maxGoldValue)
    updateObjects()
  }

  function onButtonInc()
  {
    local value = curGoldValue + 1
    curGoldValue = min(max(minGoldValue, value), maxGoldValue)
    updateObjects()
  }

  function onMax()
  {
    curGoldValue = maxGoldValue
    updateObjects()
  }

  function onApply()
  {
    if (::get_gui_balance().gold <= 0)
      return ::check_balance_msgBox(::Cost(0, curGoldValue), ::Callback(updateWindow, this)) //In fact, for displaying propper message box, with 'buy' func

    local curGold = curGoldValue - minGoldValue
    if (curGold == 0)
      return ::showInfoMsgBox(::loc("exp/convert/noGold"), "no_exp_msgbox")

    if (availableExp < expPerGold)
      return ::showInfoMsgBox(::loc("msgbox/no_rp"), "no_rp_msgbox")

    local curExp = getCurExpValue()
    local cost = ::Cost(0, curGold)
    local msgText = warningIfGold(::loc("exp/convert/needMoneyQuestion",
        {exp = ::Cost().setFrp(curExp).tostring(), cost = cost.getTextAccordingToBalance()}),
      cost)
    msgBox("need_money", msgText,
      [
        ["yes", (@(cost, curExp) function() {
            if (::check_balance_msgBox(cost))
              buyExp(curExp)
          })(cost, curExp) ],
        ["no", function() {} ]
      ], "yes", { cancel_fn = function() {}})
  }

  function buyExp(amount)
  {
    taskId = ::shop_convert_free_exp_for_unit(unit.name, amount)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      afterSlotOp = function()
      {
        ::update_gamercards()
        ::broadcastEvent("ExpConvert", {unit = unit})
      }
    }
  }

  function onBuyUnit()
  {
    ::buyUnit(unit)
  }

  function onEventExpConvert(params)
  {
    isRefreshingAfterConvert = true
    updateWindow()
    isRefreshingAfterConvert = false
  }

  function onEventUnitResearch(p)
  {
    local newUnit = ::getAircraftByName(p?.unitName)
    if (newUnit == unit)
      return
    if (!newUnit || newUnit.shopCountry != country || ::get_es_unit_type(newUnit) != listType)
      return

    unit = newUnit
    updateWindow()
  }

  function onEventUnitBought(params)
  {
    local unitName = ::getTblValue("unitName", params)
    if (!unitName || unit?.name != unitName)
      return

    local handler = this
    local config = {
      unit = unit
      unitObj = scene.findObject("unit_nest").findObject(unitName)
      cellClass = "slotbarClone"
      isNewUnit = true
      afterCloseFunc = (@(handler, unit) function() {
          if (::handlersManager.isHandlerValid(handler))
            handler.updateUnitList(::get_es_unit_type(handler.getAvailableUnitForConversion() || unit))
        })(handler, unit)
    }

    ::gui_start_selecting_crew(config)
  }

  function onEventOnlineShopPurchaseSuccessful(params)
  {
    doWhenActiveOnce("fillContent")
  }
  //----END_CONTROLLER----//
}
