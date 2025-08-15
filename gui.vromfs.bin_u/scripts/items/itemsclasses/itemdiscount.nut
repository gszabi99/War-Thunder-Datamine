from "%scripts/dagui_natives.nut" import char_send_blk, get_current_personal_discount_count, get_current_personal_discount_uid
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let DataBlock  = require("DataBlock")
let { parseDiscountDescription, createDiscountDescriptionSortData,
  sortDiscountDescriptionItems } = require("%scripts/items/discountItemSortMethod.nut")
let { getUnitName, getUnitRealCost, getUnitCost } = require("%scripts/unit/unitInfo.nut")
let { canBuyUnit } = require("%scripts/unit/unitShopInfo.nut")
let { addTask } = require("%scripts/tasker.nut")
let { BaseItem } = require("%scripts/items/itemsClasses/itemsBase.nut")
let { removeTextareaTags } = require("%sqDagui/daguiUtil.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { buyUnit } = require("%scripts/unit/unitActions.nut")
let { registerItemClass } = require("%scripts/items/itemsTypeClasses.nut")
let { updateDiscountData } = require("%scripts/discounts/discounts.nut")

let Discount = class (BaseItem) {
  static iType = itemType.DISCOUNT
  static name = "Discount"
  static defaultLocId = "personalDiscount"
  static defaultIconStyle = "default_personal_discount"
  static typeIcon = "#ui/gameuiskin#item_type_discounts.svg"

  discountDescBlk = null
  purchasesCount = 0
  purchasesMaxCount = 0
  canBuy = false
  allowBigPicture = false
  discountDescriptionDataItems = null

  canMultipleConsume = false

  showAmountInsteadPercent = false 
  isSpecialOffer = false
  specialOfferImage = null
  specialOfferImageRatio = null
  needHideTextOnIcon = false
  
  static stackBases =    ["category", "type", "aircraftName"]
  
  static stackVariables = [ "countryName", "rank", "entitlementName"]

  constructor(blk, invBlk = null, slotData = null) {
    this.canBuy = hasFeature("CanBuyDiscountItems")
    base.constructor(blk, invBlk, slotData)
    this.purchasesCount = invBlk?.purchasesCount ?? 0

    this.showAmountInsteadPercent = blk?.showAmountInsteadPercent ?? false
    this.isSpecialOffer = blk?.isSpecialOffer ?? false
    this.shouldAutoConsume = this.shouldAutoConsume || this.isSpecialOffer
    this.specialOfferImage = blk?.specialOfferImage
    this.specialOfferImageRatio = blk?.specialOfferImageRatio
    this.needHideTextOnIcon = blk?.needHideTextOnIcon ?? false
    this.purchasesMaxCount = blk?.purchasesMaxCount ?? 0
    let discountsDesc = blk?.personalDiscountsParams.discountsDesc
    if (discountsDesc != null) {
      this.discountDescBlk = DataBlock()
      this.discountDescBlk.setFrom(discountsDesc)
    }
    this.discountDescriptionDataItems = []
  }

  function _initPersonalDiscountParams() {
    if (this.discountDescBlk == null)
      return

    this.discountDescriptionDataItems = parseDiscountDescription(this.discountDescBlk)
    let sortData = createDiscountDescriptionSortData(this.discountDescBlk)
    sortDiscountDescriptionItems(this.discountDescriptionDataItems, sortData)
    this.discountDescBlk = null
  }

   function doMainAction(cb, handler, params = null) {
    let unit = this.getUnit()
    let canBuy = this.isInventoryItem && this.amount && this.isActive()
      && unit != null && canBuyUnit(unit)
    if (canBuy) {
      buyUnit(unit)
      return
    }
    let baseResult = base.doMainAction(cb, handler, params)
    if (!baseResult)
      return this.activateDiscount(cb, handler)
    return true
  }

  function activateDiscount(cb, handler) {
    if (this.isActive() || !this.isInventoryItem)
      return false

    if (this.uids == null || this.uids.len() == 0)
      return false

    let blk = DataBlock()
    blk.setStr("name", this.uids[0])

    let taskId = char_send_blk("cln_set_current_personal_discount", blk)
    let taskCallback = Callback( function() {
      updateDiscountData()
      cb({ success = true })
    }, handler)

    addTask(taskId, { showProgressBox = true }, taskCallback)
    return true
  }

  function getName(colored = true) {
    let discountDescriptionData = this.getDiscountDescriptionDataItems()
    if (discountDescriptionData.len() == 0)
      return base.getName(colored)
    local item = discountDescriptionData[0]
    if (item.type == "aircraft") {
      let hasMultipleVehicles = (discountDescriptionData.len() > 1 &&
        discountDescriptionData[1].type == "aircraft" &&
        discountDescriptionData[1].category == discountDescriptionData[0].category)
      if (hasMultipleVehicles) {
        item = {
          category = item.category
          type = "aircraft/multiple"
          discountValue = this.getMaxDiscountByCategoryAndType(item.category, "aircraft")
        }
      }
    }
    return this.getDataItemDescription(item)
  }

  function getDescriptionTitle() {
    return base.getName()
  }

  function getMainActionData(isShort = false, params = {}) {
    let unit = this.getUnit()
    if (this.isInventoryItem && this.amount && this.isActive() && unit != null) {
      let purchaseText = loc("msgbox/btn_purchase")
      if (isShort)
        return {
          btnName = purchaseText
        }
      let priceWithDiscount = getUnitCost(unit).getTextAccordingToBalance()
      let priceWithDiscountNoTags = removeTextareaTags(priceWithDiscount)
      let realCost = getUnitRealCost(unit).getTextAccordingToBalance()
      let realCostNoTags = removeTextareaTags(realCost)
      let realCostNoTagsLength = getStringWidthPx(realCostNoTags, "fontNormal")
      let purchaseLength = getStringWidthPx($"{loc("mainmenu/btnBuy")} ", "fontNormal")
      return {
        needCrossedOldPrice = true
        redLinePos = $"{purchaseLength}, ph/2-h/2"
        realCostNoTagsLength
        btnStyle = "purchase"
        btnName = $"{purchaseText} {realCostNoTags} {priceWithDiscountNoTags}"
        btnColoredName = $"{purchaseText} {realCost} {priceWithDiscount}"
      }
    }

    let res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (this.isInventoryItem && this.amount && !this.isActive())
      return {
        btnName = loc("item/activate")
      }

    return res
  }

  function isActive(...) {
    if (!this.isInventoryItem || this.uids == null)
      return false
    for (local i = get_current_personal_discount_count() - 1; i >= 0; --i) {
      let currentDiscountUid = get_current_personal_discount_uid(i)
      if (isInArray(currentDiscountUid, this.uids))
        return true
    }
    return false
  }

  function getDescription() {
    local result = ""
    if (this.isActive() && this.purchasesMaxCount != 0) {
      let locParams = {
        purchasesCount = this.purchasesCount
        purchasesMaxCount = this.purchasesMaxCount
      }
      result = "".concat(result, loc("items/discount/purchasesCounter", locParams), "\n")
    }

    let expireText = this.getCurExpireTimeText()
    if (expireText != "")
      result = "".concat(result, expireText, "\n")

    foreach (item in this.getDiscountDescriptionDataItems()) {
      if (result != "")
        result = "".concat(result, "\n")
      result = "".concat(result, this.getDataItemDescription(item))
    }
    return result
  }

  function _getDataItemDiscountText(dataItem, toTextFunc = function(val) { return $"{val}%" }) {
    let value = getTblValue("discountValue", dataItem, 0)
    if (value)
      return toTextFunc(value)

    let minValue = getTblValue("discountMin", dataItem, 0)
    let maxValue = getTblValue("discountMax", dataItem, 0)
    local res = toTextFunc(minValue)
    if (minValue != maxValue)
      res = " - ".concat(res, toTextFunc(maxValue))
    return res
  }

  function getDataItemDescription(dataItem) {
    let nameId = this.isSpecialOffer ? "specialOffer" : "discount"
    local locId = $"item/{nameId}/description/{dataItem.category}"
    if ("type" in dataItem)
      locId =$"{locId}/{dataItem.type}"
    let locParams = this.getLocParamsDescription(dataItem)
    return loc(locId, locParams)
  }

  function getLocParamsDescription(dataItem) {
    let locParams = {
      discount = this._getDataItemDiscountText(dataItem)
      discountValue = dataItem?.discountValue ?? 0
      discountMax = dataItem?.discountMax ?? 0
      discountMin = dataItem?.discountMin ?? 0
    }

    let countryName = dataItem?.countryName
    if (countryName != null)
      locParams.countryNameOptional <- $" ({loc(countryName)})"
    else
      locParams.countryNameOptional <- ""

    let aircraftName = dataItem?.aircraftName
    if (aircraftName != null) {
      let unit = getAircraftByName(aircraftName)
      if (unit != null) {
        locParams.aircraftName <- getUnitName(unit, true)
        locParams.unit <- unit
        if (this.showAmountInsteadPercent)
          locParams.discount = this._getDataItemDiscountText(dataItem,
            @(val) getUnitRealCost(unit).multiply(0.01 * val).tostring())
      }
    }

    let rank = dataItem?.rank
    if (rank != null)
      locParams.rank <- get_roman_numeral(rank)

    let entitlementName = dataItem?.entitlementName
    if (entitlementName != null) {
      let entitlementConfig = getEntitlementConfig(entitlementName)
      locParams.entitlementName <- getEntitlementName(entitlementConfig)
    }
    locParams.discount = colorize("activeTextColor", locParams.discount)
    return locParams
  }

  function getMaxDiscountByCategoryAndType(category, dType) {
    local result = 0
    foreach (dataItem in this.getDiscountDescriptionDataItems()) {
      if (dataItem.category == category && dataItem.type == dType)
        result = max(result, dataItem.discountValue)
    }
    return result
  }

  function isFixedType() {
    return this.getDiscountDescriptionDataItems().len() == 1
  }

  function canStack(item) {
    let fixedType = this.isFixedType()
    if (item.isFixedType() != fixedType)
      return false
    if (!fixedType)
      return true

    let discountDescriptionData = this.getDiscountDescriptionDataItems()
    let data1 = discountDescriptionData[0]
    let data2 = item.getDiscountDescriptionDataItems()[0]
    foreach (p in this.stackBases)
      if (getTblValue(p, data1) != getTblValue(p, data2))
        return false
    return true
  }

  function updateStackParams(stackParams) {
    if (!this.isFixedType())
      return

    let data = this.getDiscountDescriptionDataItems()[0]
    if (!stackParams.len()) 
      foreach (p in this.stackBases)
        stackParams[p] <- getTblValue(p, data)

    foreach (p in this.stackVariables) {
      let pValue = getTblValue(p, data)
      let stackValue = getTblValue(p, stackParams, pValue)
      stackParams[p] <- (pValue == stackValue) ? pValue : null
    }

    let value = data.discountValue
    let minValue = getTblValue("discountMin", stackParams)
    stackParams.discountMin <- minValue ? min(minValue, value) : value
    let maxValue = getTblValue("discountMax", stackParams)
    stackParams.discountMax <- maxValue ? max(maxValue, value) : value
  }

  function getLayerText(colored = true) {
    let discountDescriptionData = this.getDiscountDescriptionDataItems()
    if (discountDescriptionData.len() == 0)
      return this.getName(colored)

    let itemData = discountDescriptionData[0]
    local discountType = $"item/discount/{itemData?.type ?? ""}"
    if (itemData?.aircraftName != null)
      discountType = $"{itemData.aircraftName}_shop"
    else if (itemData?.countryName != null)
      discountType = itemData.countryName

    let discountValue = this._getDataItemDiscountText(itemData)

    return $"{loc(discountType, "")}{loc("ui/colon")}{discountValue}"
  }

  function getStackName(stackParams) {
    if (!stackParams.len())  
      return base.getName()
    return this.getDataItemDescription(stackParams)
  }

  function getIcon(addItemName = true) {
    local layers = base.getIcon()
    if (addItemName && !this.needHideTextOnIcon)
      layers = $"{layers}{this._getTextLayer()}"
    return layers
  }

  function _getTextLayer() {
    let layerCfg = LayersIcon.findLayerCfg("item_multiaward_text")
    if (!layerCfg)
      return ""

    layerCfg.text <- this.getLayerText()
    return LayersIcon.getTextDataFromLayer(layerCfg)
  }

  consume = @(cb, _params) this.activateDiscount(cb, null)

  function getSpecialOfferLocParams() {
    let discountDescriptionData = this.getDiscountDescriptionDataItems()
    return discountDescriptionData.len() > 0
      ? this.getLocParamsDescription(discountDescriptionData[0])
      : null
  }

  function getDiscountDescriptionDataItems() {
    this._initPersonalDiscountParams()
    return this.discountDescriptionDataItems
  }

  function getUnit() {
    return this.getSpecialOfferLocParams()?.unit
  }

  function canPreview() {
    return this.getSpecialOfferLocParams()?.unit.canPreview() ?? false
  }

  function doPreview() {
    this.getSpecialOfferLocParams().unit.doPreview()
  }
}

registerItemClass(Discount)
