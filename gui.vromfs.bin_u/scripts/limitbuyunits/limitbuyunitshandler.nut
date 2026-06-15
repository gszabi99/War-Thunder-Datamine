from "%scripts/dagui_natives.nut" import is_online_available
from "%scripts/dagui_library.nut" import *
from "app" import isAppActive
let { steam_is_overlay_active } = require("steam")
let { is_builtin_browser_active } = require("%scripts/onlineShop/browserWndHelpers.nut")
let { get_charserver_time_sec } = require("chard")
let { doesLocTextExist } = require("dagor.localize")
let { hoursToString } = require("%appGlobals/timeLoc.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { floor } = require("math")
let { format } = require("string")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCountryFlagForUnitTooltip } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitName, getUnitCountry, getUnitCost, getUnitRealCost } = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { getUnitTooltipImage } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRoleIcon, getFullUnitRoleText, getUnitClassColor } = require("%scripts/unit/unitInfoRoles.nut")
let { buildDateTimeStr, TIME_DAY_IN_SECONDS, TIME_HOUR_IN_SECONDS } = require("%scripts/time.nut")
let { openPopupFilter } = require("%scripts/popups/popupFilterWidget.nut")
let { isUnitLocNameMatchSearchStr } = require("%scripts/shop/shopSearchCore.nut")
let { getFiltersView, applyFilterChange, getSelectedFilters } = require("%scripts/limitBuyUnits/limitBuyUnitsFilter.nut")
let { showUnitGoods } = require("%scripts/onlineShop/onlineShopModel.nut")
let { buyUnit } = require("%scripts/unit/unitActions.nut")
let { canBuyUnit } = require("%scripts/unit/unitShopInfo.nut")
let { canBuyNotResearched } = require("%scripts/unit/unitStatus.nut")
let { canBuyUnitOnline } = require("%scripts/unit/availabilityBuyOnline.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { promoteUnits } = require("%scripts/unit/remainingTimeUnit.nut")
let { haveAnyUnitDiscount, getUnitsDiscounts, getUnitDiscount } = require("%scripts/discounts/discountsState.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { loadNameFilterHandler } = require("%scripts/wndLib/nameFilterHandler.nut")
let { discountUnitsBundles } = require("%scripts/onlineShop/discountBundles.nut")
let { Cost } = require("%scripts/money.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { updateEntitlementsLimited } = require("%scripts/onlineShop/entitlementsUpdate.nut")
let { addTask } = require("%scripts/tasker.nut")
let { canStartPreviewScene } = require("%scripts/customization/contentPreview.nut")
let { destroyModalInfo } = require("%scripts/modalInfo/modalInfo.nut")

const MAX_SHOW_UNITS = 50

function getPromoteUnits() {
  let units = promoteUnits.get().values().filter(@(v) v.isActive)
  return units.map(function(unitData) {
    let { unit, timeEnd } = unitData
    return {
      unit
      timeEnd
      discount = getUnitDiscount(unit)
    }
  })
}

function getDiscountedUnits() {
  let units = getUnitsDiscounts()
  return units.map(function(unitData) {
    let { unit, discount } = unitData
    return {
      unit
      timeEnd = null
      discount
    }
  })
}

let markerTypeToPageTypes = {
  remainingTimeMarker = "promoteUnit"
  discountNotificationMarker = "discount"
}

let tabItems = [
  {
    id = "promoteUnit"
    loc = "mainmenu/promoteUnit/title"
    listDataFn = getPromoteUnits
    hasUnitsFn = @() promoteUnits.get().len() > 0
  },
  {
    id = "discount"
    loc = "mainmenu/discount/title"
    listDataFn = getDiscountedUnits
    hasUnitsFn = haveAnyUnitDiscount
  }
]

function filterUnitsListFunc(unit, nameFilter) {
  
  if(nameFilter != "" && !isUnitLocNameMatchSearchStr(unit, nameFilter))
    return false

  let selectedFilters = getSelectedFilters()

  
  let countries = selectedFilters.country
  if(countries.len() > 0 && !countries.contains(getUnitCountry(unit)))
    return false

  
  let unitTypes = selectedFilters.unitType
  if(unitTypes.len() > 0 && !unitTypes.contains(getEsUnitType(unit)))
    return false

  
  let ranks = selectedFilters.rank
  if(ranks.len() > 0 && !ranks.contains(unit.rank))
    return false

  return true
}

function isLeftLessThanDay(time) {
  return time - get_charserver_time_sec() <= TIME_DAY_IN_SECONDS
}

function isLeftLessThanHour(time) {
  return time - get_charserver_time_sec() <= TIME_HOUR_IN_SECONDS
}

function leftSeconds(time) {
  time = time.tointeger()
  return time - get_charserver_time_sec()
}

function getDiscountedPriceText(unit) {
  local price = ""
  local signText = ""

  let bundle = discountUnitsBundles.get()?[unit.name].bundle
  if (bundle == null) {
    let cost = getUnitRealCost(unit)
    price = cost.gold > 0 ? cost.gold : cost.wp
    signText = cost.gold > 0 ? $"<color=@discountedCurrencyGoldColor>{loc("gold/short")}</color>"
      : $"<color=@discountedTextColor>{loc("warpoints/short")}</color>"
  }
  else {
    let { shop_price_curr, shop_price_full } = bundle
    let locId = $"priceText/{shop_price_curr}"
    price = doesLocTextExist(locId) ? loc(locId, { price = shop_price_full }) : $"{shop_price_full} {utf8ToUpper(shop_price_curr)}"
  }

  let priceText = $"<color=@discountedTextColor>{price}</color>"
  return "".concat(priceText, signText)
}

function getNewPriceText(unit) {
  local price = ""
  local signText = ""

  let bundle = discountUnitsBundles.get()?[unit.name].bundle
  if (bundle == null) {
    let cost = getUnitCost(unit)
    price = cost.gold > 0 ? cost.gold : cost.wp
    signText = cost.gold > 0 ? $"<color=@currencyGoldColor>{loc("gold/short")}</color>"
      : $"<color=@currencyWpColor>{loc("warpoints/short")}</color>"
  }
  else {
    let { shop_price_curr, shop_price } = bundle
    let locId = $"priceText/{shop_price_curr}"
    price = doesLocTextExist(locId) ? loc(locId, { price = shop_price }) : $"{shop_price} {utf8ToUpper(shop_price_curr)}"
  }

  let priceText = $"<color=@activeTextColor>{price}</color>"
  return "".concat(priceText, signText)
}

function createLeftTimeText(timeEnd) {
  if (timeEnd == null)
    return null
  timeEnd = timeEnd.tointeger()
  return (timeEnd != null && isLeftLessThanDay(timeEnd)) ? hoursToString(leftSeconds(timeEnd) / 3600.0, true, isLeftLessThanHour(timeEnd)) : null
}

function createUnitViewData(unitData) {
  let { unit, timeEnd = null, discount = 0 } = unitData
  let fontIcon = getUnitRoleIcon(unit)
  let typeText = getFullUnitRoleText(unit)
  let ediff = getCurrentGameModeEdiff()

  let timeFinal = (timeEnd != null && !isLeftLessThanDay(timeEnd)) ?
    loc("mainmenu/dataRemaningTimeShort", { time = buildDateTimeStr(timeEnd, false, false) }): null
  let hasShopButton = canBuyUnitOnline(unit)
  let hasBuyButton = !hasShopButton && (canBuyUnit(unit) || canBuyNotResearched(unit))
  let unitCost = getUnitCost(unit)

  return {
    unitName = unit.name
    unitFullName = getUnitName(unit.name, true)
    unitType = (typeText != "") ? colorize(getUnitClassColor(unit), $"{fontIcon} {typeText}") : ""
    unitAgeHeader = $"{loc("shop/age")}{loc("ui/colon")}"
    unitAge = get_roman_numeral(unit.rank)
    unitRatingHeader = $"{loc("shop/battle_rating")}{loc("ui/colon")}"
    unitRating = format("%.1f", unit.getBattleRating(ediff))
    countryImage = getCountryFlagForUnitTooltip(unit.getOperatorCountry())
    unitImage = getUnitTooltipImage(unit)
    timeFinal
    timeLeft = createLeftTimeText(timeEnd)
    timeEnd
    priceText = unitCost.toStringWithParams({ needCheckBalance = true })
    hasDiscount = discount > 0
    discountText = $"-{discount}%"
    hasBuyButton
    hasShopButton
    hasActionButton = hasShopButton || hasBuyButton
    oldPrice = getDiscountedPriceText(unit)
    newPrice = getNewPriceText(unit)
    tooltipId = getTooltipType("UNIT").getTooltipId(unit.name, { canOpenOtherWindows = false })
    isTooltipByHold = showConsoleButtons.get()
    unitCostGold = unitCost.gold
    unitCostWp = unitCost.wp
  }
}

let objectsToAjustWidth = ["unit_types", "units_list_div"]

let class LimitBuyUnitsHandler (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/limitBuyUnits/limitBuyUnits.blk"
  shouldBlurSceneBgFn = needUseHangarDof
  itemsList = null
  unitsListObj = null
  unitNameFilter = ""
  filteredUnits = null
  startPage = null
  currentTab = null
  listEmptyTextObj = null
  nameFilterHandler = null
  needFullUpdate = false

  function initScreen() {
    this.unitsListObj = this.scene.findObject("units_list")
    this.listEmptyTextObj = this.scene.findObject("list_empty_text")

    openPopupFilter({
      scene = this.scene.findObject("filter_nest")
      onChangeFn = this.onFilterChange.bindenv(this)
      filterTypesFn = @() getFiltersView()
      popupAlign = "bottom-right"
    })

    this.fillNameFilter()

    this.fillTabs()
    this.scene.findObject("timer").setUserData(this)
  }

  function fillNameFilter() {
    this.unitNameFilter = ""
    let nameFilterHandler = loadNameFilterHandler({
      scene = this.scene.findObject("filter_edit_box_nest")
      applyFilterCb = Callback(@(txt) this.applyNameFilter(txt), this)
    })
    this.registerSubHandler(nameFilterHandler)
    this.nameFilterHandler = nameFilterHandler.weakref()
  }

  function getPageIndexToOpen() {
    let pageName = markerTypeToPageTypes?[this.startPage] ?? markerTypeToPageTypes.remainingTimeMarker
    return tabItems.findindex(@(p) p.id == pageName)
  }

  function updateWidths(unitsCount) {
    let availableWidth = min(screen_width() * 0.8, to_pixels("1920@sf/@pf"))
    let itemWidth = to_pixels("1@limitBuyUnitWidth")
    let columns = floor(availableWidth / itemWidth)
    let width = itemWidth * columns + to_pixels("1@scrollBarVisibleSize + 1@blockInterval")

    for (local i = 0; i < objectsToAjustWidth.len(); i++) {
      let obj = this.scene.findObject(objectsToAjustWidth[i])
      obj["width"] = $"{width}"
    }

    let rows = floor((unitsCount - 1) / columns) + 1
    this.scene.findObject("gradient").show(rows > 2)
  }

  function fillTabs() {
    let tabs = tabItems.map(@(v, idx) {
      id = v.id
      tabName = loc(v.loc)
      navImagesText = getNavigationImagesText(idx, tabItems.len())
    })

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", { tabs })
    let listObj = this.scene.findObject("unit_types")
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    listObj.setValue(this.getPageIndexToOpen())
  }

  function onSwitchTab(obj) {
    let index = obj.getValue()
    if (index < 0 || index > tabItems.len() - 1)
      return

    this.currentTab = tabItems[index]
    this.updateItemsList()
  }

  function updateItemsList() {
    this.itemsList = this.currentTab.listDataFn()
    this.fillItemsList()
  }

  function fillItemsList() {
    this.listEmptyTextObj.show(this.itemsList.len() == 0)
    this.scene.findObject("gradient").show(this.itemsList.len() > 0)

    if (this.itemsList.len() == 0) {
      this.guiScene.replaceContentFromText(this.unitsListObj, "", 0, this)
      this.listEmptyTextObj.setValue(loc($"mainmenu/{this.currentTab.id}/empty"))
      return
    }

    let nameFilter = this.unitNameFilter
    this.filteredUnits = this.itemsList
      .filter(@(unitData) filterUnitsListFunc(unitData.unit, nameFilter))

    this.listEmptyTextObj.show(this.filteredUnits.len() == 0)
    this.scene.findObject("gradient").show(this.filteredUnits.len() > 0)

    if (this.filteredUnits.len() == 0) {
      this.guiScene.replaceContentFromText(this.unitsListObj, "", 0, this)
      this.listEmptyTextObj.setValue(loc("wishlist/filter/filterStrong"))
      return
    }

    showObjById("to_many_vehicles_text", this.filteredUnits.len() > MAX_SHOW_UNITS, this.scene)
    if (this.filteredUnits.len() > MAX_SHOW_UNITS)
      this.filteredUnits.resize(MAX_SHOW_UNITS)

    let units = this.filteredUnits.map(@(unitData) createUnitViewData(unitData))
    let data = handyman.renderCached("%gui/limitBuyUnits/limitBuyUnit.tpl", { units })
    this.guiScene.replaceContentFromText(this.unitsListObj, data, data.len(), this)

    this.updateWidths(units.len())
  }

  function getCurItemObj() {
    let value = getObjValidIndex(this.unitsListObj)
    if (value < 0)
      return null

    return this.unitsListObj.getChild(value)
  }

  function onFilterChange(objId, tName, value) {
    applyFilterChange(objId, tName, value)
    this.fillItemsList()
  }

  function applyNameFilter(filterText) {
    this.unitNameFilter = filterText
    this.fillItemsList()
  }

  function getSelectedUnit(obj) {
    let unitName = obj?.unit ?? this.getCurItemObj()?.id
    return unitName != null ? getAircraftByName(unitName) : null
  }

  function onShopBuy(obj) {
    let unit = this.getSelectedUnit(obj)
    if(unit == null)
      return

    showUnitGoods(unit.name, "limit_buy")
  }

  function onBuy(obj) {
    let unitCostGold = obj.unitCostGold.tointeger()
    let unitCostWp = obj.unitCostWp.tointeger()

    let unit = this.getSelectedUnit(obj)
    if(unit == null)
      return

    let desiredCost = Cost(unitCostWp, unitCostGold)
    let errorCb = Callback(@() this.onBuyErrorCallback(unit, desiredCost), this)
    buyUnit(unit, false, { desiredCost, errorCb })
  }

  function onPreviewUnit(obj) {
    let unit = getAircraftByName(obj.unitName)
    if (unit.canPreview() && canStartPreviewScene(true, true))
      obj.getScene().performDelayed(this, @() unit.doPreview())
  }

  function onHoverPreviewBtn(_obj) {
    destroyModalInfo()
  }

  function onBuyErrorCallback(unit, cost) {
    let unitName = colorize("userlogColoredText", getUnitName(unit, true))
    let msgText = warningIfGold(loc("mainmenu/limitBuyWnd/unitBuyError", { unitName, cost }), cost)
    this.msgBox("limitBuyUnit", msgText, [["ok"]], "ok")
  }

  function getHandlerRestoreData() {
    let listObj = this.scene.findObject("unit_types")
    listObj.getValue()

    let data = {
      openData = {}
      stateData = {
        openedTab = listObj.getValue()
      }
    }
    return data
  }

  function restoreHandler(stateData) {
    let openedTab = stateData?.openedTab ?? 0
    let listObj = this.scene.findObject("unit_types")
    listObj.setValue(openedTab)
  }

  function onTimer(_obj, _dt) {
    this.updateLeftTime()
    this.checkUpdateDiscounts()
  }

  function updateLeftTime() {
    let count = this.unitsListObj.childrenCount()
    for (local i = 0; i < count; i++) {
      let unitObj = this.unitsListObj.getChild(i)
      let timeEnd = unitObj.timeEnd
      if (timeEnd == null || timeEnd == "")
        continue
      if (leftSeconds(timeEnd) <= 0) {
        this.updateItemsList()
        return
      }

      let timeLeftObj = unitObj.findObject("timeLeft")
      if (timeLeftObj?.isValid())
        timeLeftObj.setValue(createLeftTimeText(timeEnd))
    }
  }

  function checkUpdateDiscounts() {
    if (!isAppActive() || steam_is_overlay_active() || is_builtin_browser_active())
      this.needFullUpdate = true
    else if (this.needFullUpdate && is_online_available()) {
      this.needFullUpdate = false
      let taskId = updateEntitlementsLimited()
      if (taskId == -1)
        return
      addTask(taskId, { showProgressBox = true })
    }
  }

  onEventBeforeStartShowroom = @(_p) handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  onEventProfileUpdated = @(_) this.updateItemsList()
  onEventInventoryUpdate = @(_) this.updateItemsList()
  onEventUnitBought = @(_) this.updateItemsList()
  onEventDiscountsDataUpdated = @(_) this.updateItemsList()
  onEventPromoteUnitsChanged = @(_) this.updateItemsList()
}

gui_handlers.LimitBuyUnitsHandler <- LimitBuyUnitsHandler
