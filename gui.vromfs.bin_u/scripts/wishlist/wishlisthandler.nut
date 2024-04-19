from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let { getWishList = @() { units = [] }, getMaxWishListSize = @() 100 } = require("chard")
let { requestRemoveFromWishlist } = require("%scripts/wishlist/wishlistManager.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCountryFlagForUnitTooltip } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitName, getUnitCountry, getEsUnitType, canBuyUnit } = require("%scripts/unit/unitInfo.nut")
let { getUnitTooltipImage, getUnitRoleIcon, getFullUnitRoleText, getUnitClassColor } = require("%scripts/unit/unitInfoTexts.nut")
let { buildDateTimeStr } = require("%scripts/time.nut")
let { openPopupFilter } = require("%scripts/popups/popupFilter.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { utf8ToLower } = require("%sqstd/string.nut")
let { getFiltersView, applyFilterChange, getSelectedFilters } = require("%scripts/wishlist/wishlistFilter.nut")
let { showAirInfo } = require("%scripts/airInfo.nut")
let unitStatus = require("%scripts/unit/unitStatus.nut")
let { getUnitBuyTypes, isIntersects, isFullyIncluded, getUnitAvailabilityForBuyType } = require("%scripts/wishlist/filterUtils.nut")
let { canStartPreviewScene } = require("%scripts/customization/contentPreview.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { showUnitGoods } = require("%scripts/onlineShop/onlineShopModel.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { searchEntitlementsByUnit } = require("%scripts/onlineShop/onlineShopState.nut")
let { getBundleId } = require("%scripts/onlineShop/onlineBundles.nut")
let { get_url_for_purchase } = require("url")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { is_console, isXBoxPlayerName, isPS4PlayerName } = require("%scripts/clientState/platform.nut")
let openCrossPromoWnd = require("%scripts/openCrossPromoWnd.nut")
let takeUnitInSlotbar = require("%scripts/unit/takeUnitInSlotbar.nut")
let { switchProfileCountry } = require("%scripts/user/playerCountry.nut")

let unitButtonTypes = {
  hasMarketPlaceButton = false
  hasShopButton = false
  hasBuyButton = false
  hasGiftButton = false
  hasConditionsButton = false
  hasGoToVechicleButton = true
  unitPrice = Cost()
}

function getUnitButtonType(unit, friendUid) {
  let isFriendWishList = friendUid != null
  let buyTypes = getUnitBuyTypes(unit, isFriendWishList)

  if(!unit.isVisibleInShop())
    return unitButtonTypes.__merge({
      hasGoToVechicleButton = false
    })

  let hasConditionsButton = unit.isCrossPromo && !isFriendWishList
  if(hasConditionsButton)
    return unitButtonTypes.__merge({
      hasConditionsButton
    })

  if(isFriendWishList) {
    let contact = ::getContact(friendUid.tostring())
    let isHideGiftButton = contact == null || isXBoxPlayerName(contact.name) || isPS4PlayerName(contact.name)

    let isShopVehicle = isIntersects(buyTypes, ["shop"])
    //let isPremiumVehicle = isIntersects(buyTypes, ["premium"]) && !isShopVehicle
    //let isSquadVehicle = isIntersects(buyTypes, ["squad"])

    let hasGiftButton = isShopVehicle && !isHideGiftButton && !is_console

    return unitButtonTypes.__merge({
      hasGiftButton
    })
  }

  let canBuyNotResearchedUnit = unitStatus.canBuyNotResearched(unit)
  let unitPrice = canBuyNotResearchedUnit ? unit.getOpenCost() : ::getUnitCost(unit)

  let hasMarketPlaceButton = buyTypes.contains("marketPlace")
  let hasShopButton = buyTypes.contains("shop")
  let hasBuyButton = isEqual(buyTypes, ["squadron"]) || isEqual(buyTypes, ["premium"]) ||
    (isIntersects(buyTypes, ["researchable", "conditionToReceive"]) && (canBuyNotResearchedUnit || canBuyUnit(unit)))
  return unitButtonTypes.__merge({
    hasMarketPlaceButton
    hasShopButton
    hasBuyButton
    unitPrice
  })
}

function isShowFriendWishlistUnit(unitName, friendUid) {
  let buyTypes = getUnitBuyTypes(getAircraftByName(unitName), true)
  let contact = ::getContact(friendUid.tostring())
  let isHideGiftButton = contact == null || isXBoxPlayerName(contact.name) || isPS4PlayerName(contact.name)
  let isShopVehicle = isIntersects(buyTypes, ["shop"])
  return isShopVehicle && !isHideGiftButton && !is_console
}

function filterUnitsListFunc(item, nameFilter, fuid) {
  let unit = getAircraftByName(item.unit)
  let isFriendWishlist = fuid != null

  //name
  let unitLocName = getUnitName(unit, false)
  if(nameFilter != "" && ([unitLocName, item.unit].findindex(@(v) utf8ToLower(v).indexof(nameFilter) != null) == null))
    return false

  let selectedFilters = getSelectedFilters()

  //countries
  let countries = selectedFilters.country
  if(countries.len() > 0 && !countries.contains(getUnitCountry(unit)))
    return false

  //unitType
  let unitTypes = selectedFilters.unitType
  if(unitTypes.len() > 0 && !unitTypes.contains(getEsUnitType(unit)))
    return false

  //rank
  let ranks = selectedFilters.rank
  if(ranks.len() > 0 && !ranks.contains(unit.rank))
    return false

  if(isFriendWishlist)
    return true

  //buyType
  let buyTypes = selectedFilters?.buyType ?? []
  if(buyTypes.len() > 0 && !isIntersects(buyTypes, getUnitBuyTypes(unit, isFriendWishlist)))
    return false

  //availability
  let availability = selectedFilters?.availability ?? []
  let unitAvailabilityType = getUnitAvailabilityForBuyType(unit, isFriendWishlist)
  if(availability.len() > 0 && !isFullyIncluded(unitAvailabilityType, availability))
    return false

  return true
}

function createUnitViewData(unitData, idx, friendUid) {
  let { unit, time, comment = "" } = unitData
  let air = getAircraftByName(unit)
  let fonticon = getUnitRoleIcon(air)
  let typeText = getFullUnitRoleText(air)
  let ediff = getCurrentGameModeEdiff()
  let { hasMarketPlaceButton, hasShopButton, hasBuyButton, unitPrice, hasGiftButton,
    hasConditionsButton } = getUnitButtonType(air, friendUid)

  return {
    unitName = unit
    unitFullName = getUnitName(unit, false)
    unitType = (typeText != "") ? colorize(getUnitClassColor(air), $"{fonticon} {typeText}") : ""
    unitAgeHeader = $"{loc("shop/age")}{loc("ui/colon")}"
    unitAge = get_roman_numeral(air.rank)
    unitRatingHeader = $"{loc("shop/battle_rating")}{loc("ui/colon")}"
    unitRating = format("%.1f", air.getBattleRating(ediff))
    countryImage = getCountryFlagForUnitTooltip(air.getOperatorCountry())
    unitImage = getUnitTooltipImage(air)
    comment
    hasComment = comment.len() > 0
    time = $"{loc("clan/bannedDate")}{loc("ui/colon")} {buildDateTimeStr(time, true)}"
    priceText = $"{loc("mainmenu/btnOrder")} ({unitPrice.toStringWithParams({ needCheckBalance = true })})"
    hasMarketPlaceButton
    hasShopButton
    hasBuyButton
    hasGiftButton
    hasConditionsButton
    hasTrashBin = friendUid == null
    isFirst = idx == 0
  }
}

let class WishListWnd (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/wishlist/wishlist.blk"
  shouldBlurSceneBgFn = needUseHangarDof
  unitName = null
  friendUid = null
  friendUnits = null
  itemsList = null
  isEmptyList = false
  itemsListObj = null
  unitInfoObj = null

  applyFilterTimer = null
  unitNameFilter = ""
  filteredUnits = null

  function initScreen() {
    this.backSceneParams = { eventbusName = "gui_start_mainmenu" }
    this.itemsListObj = this.scene.findObject("items_list")
    this.unitInfoObj = this.scene.findObject("item_info_nest")

    openPopupFilter({
      scene = this.scene.findObject("filter_nest")
      onChangeFn = this.onFilterChange.bindenv(this)
      filterTypes = getFiltersView(this.friendUid != null)
      popupAlign = "bottom-center"
    })

    let maxItemsCountObj = this.scene.findObject("max_items_count")
    maxItemsCountObj.setValue($"/{getMaxWishListSize()}")

    let wishlistTitle = this.scene.findObject("wishlist_title")
    if(this.friendUid == null)
      wishlistTitle.setValue(loc("mainmenu/wishlist"))
    else {
      let name = ::getContact(this.friendUid.tostring())?.getName() ?? ""
      wishlistTitle.setValue(loc("mainmenu/friendWishlist", { name }))
    }

    this.updateItemsList()
  }

  function showRightPanelAndNavBar(show) {
    this.scene.findObject("item_info_nest").show(show)
    this.scene.findObject("item_actions_bar").show(show)
    this.scene.findObject("item_info_separator").show(show)
    this.scene.findObject("vehicle_filter").show(!this.isEmptyList)

    let wishlistEmptyText = showObjById("wishlist_empty_text", !show, this.scene)

    if(!show)
      wishlistEmptyText.setValue(!this.isEmptyList ? loc("wishlist/filter/filterStrong")
      : this.friendUid == null ? loc("wishlist/filter/emptyList")
      : loc("wishlist/filter/noGifts"))
   }

  function updateItemsList() {
    let fuid = this.friendUid
    this.itemsList = this.friendUid == null ? getWishList().units
      : (this.friendUnits ?? []).filter(@(v) isShowFriendWishlistUnit(v.unit, fuid))

    this.isEmptyList = this.itemsList.len() == 0

    let itemsCountNest= showObjById("items_count_nest", this.friendUid == null, this.scene)
    if(this.friendUid == null)
      itemsCountNest.findObject("items_count").setValue($"{loc("mainmenu/itemsList")}{loc("ui/colon")} {this.itemsList.len()}")

    if(this.isEmptyList) {
      this.showRightPanelAndNavBar(false)
      this.guiScene.replaceContentFromText(this.itemsListObj, "", 0, this)
      return
    }

    this.fillItemsList()

    this.jumpToUnit()
  }

  function fillItemsList() {
    let nameFilter = this.unitNameFilter
    let fuid = this.friendUid
    this.filteredUnits = this.itemsList
      .filter(@(unitData) filterUnitsListFunc(unitData, nameFilter, fuid))

    let units = this.filteredUnits
      .map(@(unitData, idx) createUnitViewData(unitData, idx, fuid))

    let data = handyman.renderCached("%gui/wishlist/wishedUnit.tpl", { units })
    this.guiScene.replaceContentFromText(this.itemsListObj, data, data.len(), this)

    this.showRightPanelAndNavBar(units.len() > 0)
  }

  unitIdxInList = @(unitName) this.filteredUnits.findindex(@(v) v.unit == unitName)
  isUnitInList = @(unitName) this.unitIdxInList(unitName) != null

  function jumpToUnit() {
    local index = 0
    if(this.unitName != null && this.isUnitInList(this.unitName))
      index = this.unitIdxInList(this.unitName)

    this.itemsListObj.setValue(index)
  }

  function getCurItemObj() {
    let value = getObjValidIndex(this.itemsListObj)
    if (value < 0)
      return null

    return this.itemsListObj.getChild(value)
  }

  function updateButtons() {
    let itemObj = this.getCurItemObj()
    if(itemObj == null)
      return
    let unit = getAircraftByName(itemObj.id)
    let { hasMarketPlaceButton, hasShopButton, hasBuyButton, unitPrice, hasGiftButton,
      hasConditionsButton, hasGoToVechicleButton } = getUnitButtonType(unit, this.friendUid)

    showObjById("btnBuy", hasBuyButton, this.scene)
    showObjById("btnShop", hasShopButton, this.scene)
    showObjById("btnMarketplace", hasMarketPlaceButton, this.scene)
    showObjById("btnGift", hasGiftButton, this.scene)
    showObjById("btnConditions", hasConditionsButton, this.scene)
    showObjById("btnTrashBin", this.friendUid == null, this.scene)
    showObjById("btnGoToVechicle", hasGoToVechicleButton, this.scene)


    if(hasBuyButton) {
      placePriceTextToButton(this.scene, "btnBuy", loc("mainmenu/btnOrder"), unitPrice)
      if(unit.isSquadronVehicle() && !::isUnitResearched(unit)) {
        this.scene.findObject("buy_discount").show(false)
        return
      }
      ::showUnitDiscount(this.scene.findObject("buy_discount"), unit)
    }
  }

  function updateUnitInfo() {
    let itemObj = this.getCurItemObj()
    if(itemObj == null)
      return
    let unit = getAircraftByName(itemObj.id)
    this.restoreUnitInfoSize()
    showAirInfo(unit, true, this.unitInfoObj, this, { parentWidth = true, needShopInfo = true, needShowExpiredMessage = true })
    this.updateUnitInfoSize()

    this.updateButtons()
  }

  function restoreUnitInfoSize() {
    let unitImgObj = this.unitInfoObj.findObject("aircraft-image-nest")
    unitImgObj.height = "40%sh"
    unitImgObj.width = "540/294h"
    unitImgObj.show(true)

    this.unitInfoObj.findObject("aircraft-type").show(true)
    this.unitInfoObj.findObject("aircraft-country_and_level-tr").show(true)
  }

  function updateUnitInfoSize() {
    this.guiScene.applyPendingChanges(false)
    let contentObj = this.unitInfoObj.findObject("air_info_tooltip")
    let unitImgObj = this.unitInfoObj.findObject("aircraft-image-nest")

    let contentObjHeight = contentObj.getSize()[1]
    let unitInfoObjHeight = this.unitInfoObj.getSize()[1]
    if(contentObjHeight <= unitInfoObjHeight)
      return

    let unitImageHeightBeforeFit = unitImgObj.getSize()[1]
    let deltaHeight = contentObjHeight - unitInfoObjHeight

    let isVisibleUnitImg = unitImageHeightBeforeFit - deltaHeight >= 0.5 * unitImageHeightBeforeFit
    if (isVisibleUnitImg)
      unitImgObj.height = unitImageHeightBeforeFit - deltaHeight

    unitImgObj.show(isVisibleUnitImg)

    if(isVisibleUnitImg)
      return

    if(contentObjHeight - unitImageHeightBeforeFit > unitInfoObjHeight) {
      this.unitInfoObj.findObject("aircraft-type").show(false)
      this.unitInfoObj.findObject("aircraft-country_and_level-tr").show(false)
    }
  }

  function onEventProfileUpdated(_p) {
    this.updateItemsList()
  }

  function onFilterChange(objId, tName, value) {
    applyFilterChange(objId, tName, value)
    this.fillItemsList()
    this.itemsListObj.setValue(0)
  }

  function applyNameFilter(obj) {
    clearTimer(this.applyFilterTimer)
    this.unitNameFilter = utf8ToLower(obj.getValue())
    if(this.unitNameFilter == "") {
      this.fillItemsList()
      return
    }

    let applyCallback = Callback(@() this.fillItemsList(), this)
    this.applyFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else
      this.guiScene.performDelayed(this, this.goBack)
  }

  function getSelectedUnit(obj) {
    let unitName = obj?.unit ?? this.getCurItemObj()?.id
    return unitName != null ? getAircraftByName(unitName) : null
  }

  function onMarketplaceFindUnit(obj) {
    let unit = this.getSelectedUnit(obj)
    if(unit == null)
      return
    let item = findItemById(unit.marketplaceItemdefId)
    if (!(item?.hasLink() ?? false))
      return
    item.openLink()
  }

  function onShopBuy(obj) {
    let unit = this.getSelectedUnit(obj)
    if(unit == null)
      return
    showUnitGoods(unit.name, "wish_list")
  }

  function onBuy(obj) {
    let unit = this.getSelectedUnit(obj)
    if(unit == null)
      return
    ::buyUnit(unit)
  }

  function onGiftBuy(obj) {
    let unitName = obj?.unit ?? this.getCurItemObj()?.id
    if(unitName == null || this.friendUid == null)
      return

    let searchResult = searchEntitlementsByUnit(unitName)
    foreach (goodsName in searchResult) {
      let bundleId = getBundleId(goodsName)
      if (bundleId != "") {
        let url = $"auto_local auto_login {get_url_for_purchase(bundleId)}&for={this.friendUid}&popupId=buy-gift-popup"
        openUrl(url, false, false, "wish_list_window")
        break
      }
    }
  }

  function onItemRemove(obj) {
    let unitName = obj?.unit ?? this.getCurItemObj()?.id
    if(unitName == null)
      return

    scene_msg_box("wishlist_item_remove", null, loc("mainmenu/remove_from_wishlist"),
    [
      ["ok", @() requestRemoveFromWishlist(unitName)],
      ["cancel", @() null]
    ], null)
  }

  function onItemPreview(_p) {
    if (!this.isValid())
      return
    let unit = this.getSelectedUnit(null)
    if(unit == null)
      return
    if (canStartPreviewScene(true, true))
      unit.doPreview()
  }

  function onEventUnitBought(params) {
    if (!this.isValid())
      return

    let { unitName = null, needSelectCrew = false } = params
    if (!needSelectCrew)
      return

    let unit = unitName ? getAircraftByName(unitName) : null
    if (!unit)
      return

    takeUnitInSlotbar(unit, {
      isNewUnit = true
    })
  }

  function onShowUnit(_p) {
    if (!this.isValid())
      return
    let unit = this.getSelectedUnit(null)
    if(unit == null)
      return

    switchProfileCountry(getUnitCountry(unit))
    gui_handlers.ShopViewWnd.open({
      curAirName = unit.name
      forceUnitType = unit.unitType
      needHighlight = true
    })
  }

  function onShowConditions(_p) {
    let unit = this.getSelectedUnit(null)
    if(unit == null)
      return

    openCrossPromoWnd(unit.crossPromoBanner)
  }

  function getHandlerRestoreData() {
    let data = {
      openData = {
        friendUid = this.friendUid
        friendUnits = this.friendUnits
      }
      stateData = {
        unitName = this.getCurItemObj()?.id
      }
    }
    return data
  }

  function restoreHandler(stateData) {
    this.unitName = stateData.unitName
    this.jumpToUnit()
  }

  function onEventBeforeStartShowroom(_p) {
    handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  }
}

gui_handlers.WishListWnd <- WishListWnd

return {
  openWishlist = @(params = {}) handlersManager.loadHandler(WishListWnd, params)
}
