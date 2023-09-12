//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { ceil } = require("math")
let { format } = require("string")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { research } = require("%scripts/unit/unitActions.nut")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { isCountryHaveUnitType } = require("%scripts/shop/shopUnitsInfo.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")

enum windowState {
  research,
  canBuy,
  noUnit
}

::gui_modal_convertExp <- function gui_modal_convertExp(unit = null) {
  if (!hasFeature("SpendGold"))
    return
  if (unit && !::can_spend_gold_on_unit_with_popup(unit))
    return

  ::gui_start_modal_wnd(gui_handlers.ConvertExpHandler, { unit = unit })
}

gui_handlers.ConvertExpHandler <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType         = handlerType.MODAL
  sceneBlkName    = "%gui/convertExp/convertExp.blk"

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

  function initScreen() {
    if (!this.scene)
      return this.goBack()

    this.unitList = []
    this.unitTypesList = []

    this.initUnitTypes()
    this.initCountriesList()
    this.updateData()

    if (this.availableExp < this.expPerGold) {
      this.goBack()
      this.showNoRPmsgbox()
      return
    }

    if (!this.unit)
      this.unit = this.getAvailableUnitForConversion()

    this.listType = ::get_es_unit_type(this.unit)
    this.updateWindow()
  }

  function updateData() {
    this.updateUserCurrency()
    this.expPerGold = ::wp_get_exp_convert_exp_for_gold_rate(this.country) || 1

    if (this.currentState != windowState.noUnit) {
      this.unitExpGranted = ::getUnitExp(this.unit)
      this.unitReqExp = ::getUnitReqExp(this.unit)
    }
    else {
      this.unitExpGranted = 0
      this.unitReqExp = 0
    }
  }

  function updateUserCurrency() {
    this.availableExp = ::shop_get_free_exp()
    this.playersGold = max(::get_balance().gold, 0)
  }

  function loadUnitList(unitType) {
    this.unitList = []
    foreach (unitForList in getAllUnits())
      if (unitForList.shopCountry == this.country
          && ::canResearchUnit(unitForList)
          && !unitForList.isSquadronVehicle()
          && ::get_es_unit_type(unitForList) == unitType)
        this.unitList.append(unitForList)
    let ediff = ::get_current_ediff()
    this.unitList.sort(@(a, b) a.getBattleRating(ediff) <=> b.getBattleRating(ediff))
  }

  function getCurExpValue() {
    local expToBuy = (this.curGoldValue - this.minGoldValue) * this.expPerGold
    if ((expToBuy + this.unitExpGranted) > this.unitReqExp && (this.unitReqExp - this.unitExpGranted <= this.availableExp))
      expToBuy = this.unitReqExp - this.unitExpGranted
    return expToBuy
  }

  function getCountryResearchUnit(countryName, unitType) {
    let unitName = ::shop_get_researchable_unit_name(countryName, unitType)
    return getAircraftByName(unitName)
  }

  //----VIEW----//
  function initCountriesList() {
    local curValue = 0
    this.country = profileCountrySq.value

    let view = { items = [] }
    foreach (idx, countryItem in shopCountriesList) {
      view.items.append({
        id = countryItem
        disabled = !::isCountryAvailable(countryItem)
        image = getCountryIcon(countryItem)
        tooltip = "#" + countryItem
        discountNotification = true
      })

      if (this.country == countryItem)
        curValue = idx
    }

    let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    let countriesObj = this.scene.findObject("countries_list")
    this.guiScene.replaceContentFromText(countriesObj, data, data.len(), this)
    countriesObj.setValue(curValue)

    foreach (c in shopCountriesList)
      ::showDiscount(countriesObj.findObject(c + "_discount"), "exp_to_gold_rate", c)
  }

  function fillUnitList() {
    let isShow = this.unitList.len() > 1
    let nestObj = this.scene.findObject("choose_unit_list")
    nestObj.show(isShow)
    local unitListBlk = []
    foreach (unitForResearch in this.unitList)
      unitListBlk.append(::build_aircraft_item(unitForResearch.name, unitForResearch))
    unitListBlk = "".join(unitListBlk)
    this.guiScene.replaceContentFromText(nestObj, unitListBlk, unitListBlk.len(), this)
    nestObj.setValue(this.unitList.indexof(this.unit) ?? -1)
    foreach (unitForResearch in this.unitList)
      ::fill_unit_item_timers(nestObj.findObject(unitForResearch.name), unitForResearch)
  }

  function updateWindow() {
    let oldState = this.currentState
    if (!this.unit)
      this.currentState = windowState.noUnit
    else if (::canBuyUnit(this.unit) || ::isUnitResearched(this.unit))
      this.currentState = windowState.canBuy
    else
      this.currentState = windowState.research

    if (this.isRefreshingAfterConvert && oldState != this.currentState  && this.currentState == windowState.canBuy)
      sendBqEvent("CLIENT_GAMEPLAY_1", "completed_new_research_unit", {
        unit = this.unit.name
        howResearched = "convert_exp"
      })

    this.updateData()
    this.fillContent()
    this.updateButtons()
    this.fillUnitList()
    this.updateUnitTypesList()
  }

  function showConversionUnit() {
    if (!this.unit)
      return this.goBack()

    let unitBlk = ::build_aircraft_item(this.unit.name, this.unit)
    let unitNest = this.scene.findObject("unit_nest")
    this.guiScene.replaceContentFromText(unitNest, unitBlk, unitBlk.len(), this)
    ::fill_unit_item_timers(unitNest.findObject(this.unit.name), this.unit)
  }

  function fillFreeExp() {
    this.scene.findObject("available_exp").setValue(decimalFormat(this.availableExp))
  }

  function initUnitTypes() {
    let listObj = this.scene.findObject("unit_types_list")
    if (!checkObj(listObj))
      return

    this.unitTypesList = unitTypes.types
      .filter(@(t) t.isVisibleInShop())
      .sort(@(a, b) a.visualSortOrder <=> b.visualSortOrder)

    let view = { items = [] }
    foreach (_idx, unitType in this.unitTypesList)
      view.items.append({
        id = unitType.armyId
        text = unitType.fontIcon + " " + unitType.getArmyLocName()
        tooltip = unitType.canSpendGold() ? null : loc("msgbox/unitTypeRestrictFromSpendGold")
      })

    let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
  }

  function updateUnitTypesList() {
    let listObj = this.scene.findObject("unit_types_list")
    if (!checkObj(listObj))
      return

    local curIdx = 0
    foreach (idx, unitType in this.unitTypesList) {
      let isShow = unitType.haveAnyUnitInCountry(this.country)
      let selected = isShow && this.listType == unitType.esUnitType
      if (selected)
        curIdx = idx

      let btnObj = showObjById(unitType.armyId, isShow, listObj)
      if (btnObj) {
        btnObj.inactive = this.getCountryResearchUnit(this.country, unitType.esUnitType) ? "no" : "yes"
        btnObj.enable(unitType.canSpendGold())
      }
    }

    listObj.setValue(curIdx)
  }

  function fillSlider() {
    let sliderDivObj = this.scene.findObject("exp_slider_nest")
    if (!checkObj(sliderDivObj))
      return

    let is_enough_availExp = this.availableExp > 0
    let is_need_to_convert = (this.unitReqExp - this.unitExpGranted) > 0

    let showExpSlider = is_enough_availExp && is_need_to_convert
    sliderDivObj.show(showExpSlider)

    if (showExpSlider) {
      let sliderObj     = sliderDivObj.findObject("convert_slider")
      let oldProgressOb = sliderDivObj.findObject("old_exp_progress")
      let newProgressOb = sliderDivObj.findObject("new_exp_progress")

      let diffExp = this.unitReqExp - this.unitExpGranted
      let maxGoldDiff = ceil(diffExp.tofloat() / this.expPerGold).tointeger()
      this.minGoldValue  = (this.unitExpGranted.tofloat() / this.expPerGold).tointeger()
      this.maxGoldForAir = this.minGoldValue + maxGoldDiff

      let goldLimitByExp  = (this.availableExp >= diffExp) ? maxGoldDiff : (this.availableExp.tofloat() / this.expPerGold).tointeger()
      this.maxGoldValue = this.minGoldValue + min(goldLimitByExp, this.playersGold)
      this.curGoldValue = this.maxGoldValue

      sliderObj.max     = this.maxGoldForAir
      oldProgressOb.max = this.maxGoldForAir
      newProgressOb.max = this.maxGoldForAir

      oldProgressOb.setValue(this.minGoldValue)
      this.updateSlider()
    }
  }

  function fillUnitResearchedContent() {
    let noExpObj = this.scene.findObject("buy_unit_cost")
    if (!checkObj(noExpObj))
      return

    let unitCost = ::wp_get_cost(this.unit.name)
    noExpObj.setValue(::getPriceAccordingToPlayersCurrency(unitCost, 0, true))
  }

  function updateSlider() {
    let sliderObj = this.scene.findObject("convert_slider")
    let newProgressOb = this.scene.findObject("new_exp_progress")
    newProgressOb.setValue(this.curGoldValue)
    sliderObj.setValue(this.curGoldValue)

    this.updateSliderText()
    this.updateExpTextPosition()
  }

  function fillContent() {
    this.scene.findObject("exp_slider_nest").show(this.currentState == windowState.research)
    this.scene.findObject("available_exp_nest").show(this.currentState == windowState.research)
    this.scene.findObject("cost_holder").show(this.currentState == windowState.research)
    this.scene.findObject("unit_researched_nest").show(this.currentState == windowState.canBuy)
    this.scene.findObject("unit_nest").show(this.currentState != windowState.noUnit)

    let noUnitMsgObj = this.scene.findObject("no_unit_nest")
    let needNoUnitText = this.currentState == windowState.noUnit
    noUnitMsgObj.show(needNoUnitText)
    if (needNoUnitText)
      noUnitMsgObj.setValue(loc(this.getAvailableUnitForConversion() != null ? loc("pr_conversion/no_unit") : loc("pr_conversion/all_units_researched")))

    if (this.currentState == windowState.research) {
      if (this.availableExp > this.expPerGold) {
        this.fillSlider()
        this.fillFreeExp()
        this.fillCostGold()
        this.showConversionUnit()
      }
      else {
        this.goBack()
        if (!this.isRefreshingAfterConvert)
          this.showNoRPmsgbox()
      }
    }
    else if (this.currentState == windowState.canBuy) {
      this.fillUnitResearchedContent()
      this.showConversionUnit()
    }
  }

  function showNoRPmsgbox() {
    if (!checkObj(this.guiScene["no_rp_msgbox"]))
      this.msgBox("no_rp_msgbox", loc("msgbox/no_rp"), [["ok", function () {}]], "ok", { cancel_fn = function() {} })
  }

  function updateSliderText() {
    let sliderTextObj = this.scene.findObject("convert_slider_text")
    let strGrantedExp = Cost().setRp(this.unitExpGranted).tostring()
    let expToBuy = this.getCurExpValue()
    let strWantToBuyExp = format("<color=@activeTextColor> +%s</color>", Cost().setFrp(expToBuy).toStringWithParams({ isFrpAlwaysShown = true }))
    let strRequiredExp = Cost().setRp(::getUnitReqExp(this.unit)).tostring()
    let sliderText = format("<color=@commonTextColor>%s%s%s%s</color>", strGrantedExp, strWantToBuyExp, loc("ui/slash"), strRequiredExp)
    sliderTextObj.setValue(sliderText)
  }

  function fillCostGold() {
    let costGoldObj = this.scene.findObject("convertion_cost")
    costGoldObj.setValue(decimalFormat(this.curGoldValue - this.minGoldValue))
  }

  function updateButtons() {
    let isMinSet = this.curGoldValue == this.minGoldValue
    let isMaxSet = this.curGoldValue == this.maxGoldValue

    this.showSceneBtn("btn_apply", this.currentState == windowState.research)
    this.showSceneBtn("btn_buy_unit", this.currentState == windowState.canBuy)
    this.scene.findObject("btn_apply").inactiveColor = this.curGoldValue != this.minGoldValue ? "no" : "yes"

    this.scene.findObject("buttonDec").enable(!isMinSet)
    this.scene.findObject("buttonInc").enable(!isMaxSet)
    this.scene.findObject("btn_max").enable(!isMaxSet)
  }

  function updateExpTextPosition() {
    this.guiScene.setUpdatesEnabled(true, true)
    let textObj     = this.scene.findObject("convert_slider_text")
    let boxObj      = this.scene.findObject("exp_slider_nest")
    let textNestObj = this.scene.findObject("slider_button")

    let boxPosX      = boxObj.getPos()[0]
    let boxSizeX     = boxObj.getSize()[0]

    let textSizeX     = textObj.getSize()[0]

    let textNestPosX  = textNestObj.getPos()[0]
    let textNestSizeX = textNestObj.getSize()[0]

    let overdraft = (textNestPosX + (textSizeX + textNestSizeX) / 2) - (boxPosX + boxSizeX)

    let leftEdge = textNestPosX - 0.5 * textSizeX

    local newLeft = textObj.base_left
    if (leftEdge < boxPosX)
      newLeft = textObj.base_left + " + " + (boxPosX - leftEdge).tostring()
    else if (overdraft > 0)
      newLeft = textObj.base_left + " - " + (overdraft).tostring()

    textObj.left = newLeft
  }

  function updateObjects() {
    this.updateSlider()
    this.fillCostGold()
    this.updateButtons()
  }
  //----END_VIEW----//

  //----CONTROLLER----//
  function onCountrySelect() {
    let c = this.scene.findObject("countries_list").getValue()
    if (!(c in shopCountriesList))
      return

    this.country = shopCountriesList[c]

    this.unit = this.getAvailableUnitForConversion()

    this.listType = ::get_es_unit_type(this.unit)
    this.updateWindow()

    //TODO: do this in updateWindow
    this.loadUnitList(::get_es_unit_type(this.unit))
    this.fillUnitList()

    ::showDiscount(this.scene.findObject("convert-discount"), "exp_to_gold_rate", this.country, null, true)
  }

  function onSwitchUnitType(obj) {
    local value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      value = 0

    let selObj = obj.getChild(value)

    let unitType = unitTypes.getByArmyId(selObj?.id)
    this.updateUnitList(unitType.esUnitType)
  }

  function updateUnitList(unitType) {
    this.listType = unitType
    this.unit = this.getCountryResearchUnit(this.country, unitType)
    this.loadUnitList(unitType)
    this.fillUnitList()
    this.updateWindow()
  }

  function onUnitSelect(obj) {
    let newUnit = this.unitList[obj.getValue()]
    let isNewUnitInResearch = ::isUnitInResearch(newUnit)
    let isNewUnitResearched = ::isUnitResearched(newUnit)
    let hasChangedUnit = !isEqual(newUnit, this.unit)
    if (!hasChangedUnit && (isNewUnitInResearch || isNewUnitResearched))
      return

    if (hasChangedUnit && !::checkForResearch(newUnit)) {
      obj.setValue(this.unitList.indexof(this.unit))
      return
    }

    let cb = function() {
      this.unit = newUnit
      this.updateWindow()
    }
    if (isNewUnitInResearch || isNewUnitResearched) {
      cb()
      return
    }

    research(newUnit, true, Callback(cb, this))
  }

  function getAvailableUnitForConversion() {
    local newUnit = null
    //try to get unit of same type as previous unit is
    if (isCountryHaveUnitType(this.country, ::get_es_unit_type(this.unit)))
      newUnit = this.getCountryResearchUnit(this.country, ::get_es_unit_type(this.unit))
    if (!newUnit) {
      foreach (unitType in this.unitTypesList) {
        if (!unitType.canSpendGold())
          continue

        if (unitType.haveAnyUnitInCountry(this.country))
          newUnit = this.getCountryResearchUnit(this.country, unitType.esUnitType)

        if (newUnit)
          break
      }
    }
    return newUnit
  }

  function onConvertChanged(obj) {
    let value = obj.getValue()
    if (this.curGoldValue == value)
      return
    this.curGoldValue = min(max(this.minGoldValue, value), this.maxGoldValue)
    this.updateObjects()
  }

  function onButtonDec() {
    let value = this.curGoldValue - 1
    this.curGoldValue = min(max(this.minGoldValue, value), this.maxGoldValue)
    this.updateObjects()
  }

  function onButtonInc() {
    let value = this.curGoldValue + 1
    this.curGoldValue = min(max(this.minGoldValue, value), this.maxGoldValue)
    this.updateObjects()
  }

  function onMax() {
    this.curGoldValue = this.maxGoldValue
    this.updateObjects()
  }

  function onApply() {
    if (::get_gui_balance().gold <= 0)
      return ::check_balance_msgBox(Cost(0, this.curGoldValue), Callback(this.updateWindow, this)) //In fact, for displaying propper message box, with 'buy' func

    let curGold = this.curGoldValue - this.minGoldValue
    if (curGold == 0)
      return showInfoMsgBox(loc("exp/convert/noGold"), "no_exp_msgbox")

    if (this.availableExp < this.expPerGold)
      return showInfoMsgBox(loc("msgbox/no_rp"), "no_rp_msgbox")

    let curExp = this.getCurExpValue()
    let cost = Cost(0, curGold)
    let msgText = ::warningIfGold(loc("exp/convert/needMoneyQuestion",
        { exp = Cost().setFrp(curExp).tostring(), cost = cost.getTextAccordingToBalance() }),
      cost)
    this.msgBox("need_money", msgText,
      [
        ["yes", function() {
            if (::check_balance_msgBox(cost))
              this.buyExp(curExp)
          }],
        ["no", function() {} ]
      ], "yes", { cancel_fn = function() {} })
  }

  function buyExp(amount) {
    this.taskId = ::shop_convert_free_exp_for_unit(this.unit.name, amount)
    if (this.taskId >= 0) {
      ::set_char_cb(this, this.slotOpCb)
      this.showTaskProgressBox()
      this.afterSlotOp = function() {
        ::update_gamercards()
        broadcastEvent("ExpConvert", { unit = this.unit })
      }
    }
  }

  function onBuyUnit() {
    ::buyUnit(this.unit)
  }

  function onEventExpConvert(_params) {
    this.isRefreshingAfterConvert = true
    this.updateWindow()
    this.isRefreshingAfterConvert = false
  }

  function onEventUnitResearch(p) {
    let newUnit = getAircraftByName(p?.unitName)
    if (newUnit == this.unit)
      return
    if (!newUnit || newUnit.shopCountry != this.country || ::get_es_unit_type(newUnit) != this.listType)
      return

    this.unit = newUnit
    this.updateWindow()
  }

  function onEventUnitBought(params) {
    let unitName = getTblValue("unitName", params)
    if (!unitName || this.unit?.name != unitName)
      return

    let handler = this
    let config = {
      unit = this.unit
      unitObj = this.scene.findObject("unit_nest").findObject(unitName)
      cellClass = "slotbarClone"
      isNewUnit = true
      afterCloseFunc = (@(unit) function() { //-ident-hides-ident
          if (handlersManager.isHandlerValid(handler))
            handler.updateUnitList(::get_es_unit_type(handler.getAvailableUnitForConversion() || unit))
        })(this.unit)
    }

    ::gui_start_selecting_crew(config)
  }

  function onEventOnlineShopPurchaseSuccessful(_params) {
    this.doWhenActiveOnce("fillContent")
  }
  //----END_CONTROLLER----//
}
