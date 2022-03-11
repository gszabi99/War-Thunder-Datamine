let { getEntitlementConfig, getEntitlementName } = require("scripts/onlineShop/entitlements.nut")

::items_classes.Discount <- class extends ::BaseItem
{
  static iType = itemType.DISCOUNT
  static defaultLocId = "personalDiscount"
  static defaultIconStyle = "default_personal_discount"
  static typeIcon = "#ui/gameuiskin#item_type_discounts"

  purchasesCount = 0
  purchasesMaxCount = 0
  canBuy = false
  allowBigPicture = false
  discountDescriptionDataItems = null

  showAmountInsteadPercent = false //work only for units atm.
  isSpecialOffer = false
  specialOfferImage = null
  specialOfferImageRatio = null
  needHideTextOnIcon = false
  //params which must be equal to stack items
  static stackBases =    ["category", "type", "aircraftName"]
  //params which can can be different in stack but still need for stack description
  static stackVariables = [ "countryName", "rank", "entitlementName"]

  constructor(blk, invBlk = null, slotData = null)
  {
    canBuy = ::has_feature("CanBuyDiscountItems")
    base.constructor(blk, invBlk, slotData)
    _initPersonalDiscountParams(blk?.personalDiscountsParams)
    purchasesCount = invBlk?.purchasesCount ?? 0

    showAmountInsteadPercent = blk?.showAmountInsteadPercent ?? false
    isSpecialOffer = blk?.isSpecialOffer ?? false
    shouldAutoConsume = shouldAutoConsume || isSpecialOffer
    specialOfferImage = blk?.specialOfferImage
    specialOfferImageRatio = blk?.specialOfferImageRatio
    needHideTextOnIcon = blk?.needHideTextOnIcon ?? false
  }

  function _initPersonalDiscountParams(blk)
  {
    if (blk == null)
      return
    purchasesMaxCount = ::getTblValue("purchasesMaxCount", blk, 0)
    discountDescriptionDataItems = ::parse_discount_description(blk?.discountsDesc)
    let sortData = ::create_discount_description_sort_data(blk?.discountsDesc)
    ::sort_discount_description_items(discountDescriptionDataItems, sortData)
  }

  /* override */ function doMainAction(cb, handler, params = null)
  {
    let baseResult = base.doMainAction(cb, handler, params)
    if (!baseResult)
      return activateDiscount(cb, handler)
    return true
  }

  function activateDiscount(cb, handler)
  {
    if (isActive() || !isInventoryItem)
      return false

    if (uids == null || uids.len() == 0)
      return false

    let blk = ::DataBlock()
    blk.setStr("name", uids[0])

    let taskId = ::char_send_blk("cln_set_current_personal_discount", blk)
    let taskCallback = ::Callback((@(cb) function() {
      ::g_discount.updateDiscountData()
      cb({ success = true })
    })(cb), handler)

    ::g_tasker.addTask(taskId, { showProgressBox = true }, taskCallback)
    return true
  }

  function getName(colored = true)
  {
    if (discountDescriptionDataItems.len() == 0)
      return base.getName(colored)
    local item = discountDescriptionDataItems[0]
    if (item.type == "aircraft")
    {
      let hasMultipleVehicles = (discountDescriptionDataItems.len() > 1 &&
        discountDescriptionDataItems[1].type == "aircraft" &&
        discountDescriptionDataItems[1].category == discountDescriptionDataItems[0].category)
      if (hasMultipleVehicles)
      {
        item = {
          category = item.category
          type ="aircraft/multiple"
          discountValue = getMaxDiscountByCategoryAndType(item.category, "aircraft")
        }
      }
    }
    return getDataItemDescription(item)
  }

  function getDescriptionTitle()
  {
    return base.getName()
  }

  function getMainActionData(isShort = false, params = {})
  {
    let res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (isInventoryItem && amount && !isActive())
      return {
        btnName = ::loc("item/activate")
      }

    return res
  }

  function isActive(...)
  {
    if (!isInventoryItem || uids == null)
      return false
    for (local i = ::get_current_personal_discount_count() - 1; i >= 0; --i)
    {
      let currentDiscountUid = ::get_current_personal_discount_uid(i)
      if (::isInArray(currentDiscountUid, uids))
        return true
    }
    return false
  }

  function getDescription()
  {
    local result = ""
    if (isActive() && purchasesMaxCount != 0)
    {
      let locParams = {
        purchasesCount = purchasesCount
        purchasesMaxCount = purchasesMaxCount
      }
      result += ::loc("items/discount/purchasesCounter", locParams) + "\n"
    }

    let expireText = getCurExpireTimeText()
    if (expireText != "")
      result += expireText + "\n"

    foreach (item in discountDescriptionDataItems)
    {
      if (result != "")
        result += "\n"
      result += getDataItemDescription(item)
    }
    return result
  }

  function _getDataItemDiscountText(dataItem, toTextFunc = function(val) { return val + "%" })
  {
    let value = ::getTblValue("discountValue", dataItem, 0)
    if (value)
      return toTextFunc(value)

    let minValue = ::getTblValue("discountMin", dataItem, 0)
    let maxValue = ::getTblValue("discountMax", dataItem, 0)
    local res = toTextFunc(minValue)
    if (minValue != maxValue)
      res += " - " + toTextFunc(maxValue)
    return res
  }

  function getDataItemDescription(dataItem)
  {
    let nameId = isSpecialOffer ? "specialOffer" : "discount"
    local locId = $"item/{nameId}/description/{dataItem.category}"
    if ("type" in dataItem)
      locId += "/" + dataItem.type
    let locParams = getLocParamsDescription(dataItem)
    return ::loc(locId, locParams)
  }

  function getLocParamsDescription(dataItem) {
    let locParams = {
      discount = _getDataItemDiscountText(dataItem)
      discountValue = dataItem?.discountValue ?? 0
      discountMax = dataItem?.discountMax ?? 0
      discountMin = dataItem?.discountMin ?? 0
    }

    let countryName = dataItem?.countryName
    if (countryName != null)
      locParams.countryNameOptional <- $" ({::loc(countryName)})"
    else
      locParams.countryNameOptional <- ""

    let aircraftName = dataItem?.aircraftName
    if (aircraftName != null) {
      let unit = ::getAircraftByName(aircraftName)
      if (unit != null) {
        locParams.aircraftName <- ::getUnitName(unit, true)
        locParams.unit <- unit
        if (showAmountInsteadPercent)
          locParams.discount = _getDataItemDiscountText(dataItem,
            @(val) ::getUnitRealCost(unit).multiply(0.01 * val).tostring())
      }
    }

    let rank = dataItem?.rank
    if (rank != null)
      locParams.rank <- ::get_roman_numeral(rank)

    let entitlementName = dataItem?.entitlementName
    if (entitlementName != null) {
      let entitlementConfig = getEntitlementConfig(entitlementName)
      locParams.entitlementName <- getEntitlementName(entitlementConfig)
    }
    locParams.discount = ::colorize("activeTextColor", locParams.discount)
    return locParams
  }

  function getMaxDiscountByCategoryAndType(category, dType)
  {
    if (discountDescriptionDataItems == null)
      return 0
    local result = 0
    foreach (dataItem in discountDescriptionDataItems)
    {
      if (dataItem.category == category && dataItem.type == dType)
        result = ::max(result, dataItem.discountValue)
    }
    return result
  }

  function isFixedType()
  {
    return discountDescriptionDataItems.len() == 1
  }

  function canStack(item)
  {
    let fixedType = isFixedType()
    if (item.isFixedType() != fixedType)
      return false
    if (!fixedType)
      return true

    let data1 = discountDescriptionDataItems[0]
    let data2 = item.discountDescriptionDataItems[0]
    foreach(p in stackBases)
      if (::getTblValue(p, data1) != ::getTblValue(p, data2))
        return false
    return true
  }

  function updateStackParams(stackParams)
  {
    if (!isFixedType())
      return

    let data = discountDescriptionDataItems[0]
    if (!stackParams.len()) //stack not inited
      foreach(p in stackBases)
        stackParams[p] <- ::getTblValue(p, data)

    foreach(p in stackVariables)
    {
      let pValue = ::getTblValue(p, data)
      let stackValue = ::getTblValue(p, stackParams, pValue)
      stackParams[p] <- (pValue == stackValue) ? pValue : null
    }

    let value = data.discountValue
    let minValue = ::getTblValue("discountMin", stackParams)
    stackParams.discountMin <- minValue ? ::min(minValue, value) : value
    let maxValue = ::getTblValue("discountMax", stackParams)
    stackParams.discountMax <- maxValue ? ::max(maxValue, value) : value
  }

  function getLayerText(colored = true)
  {
    if (discountDescriptionDataItems == null)
      return getName(colored)

    let itemData = discountDescriptionDataItems[0]
    local discountType = $"item/discount/{itemData?.type ?? ""}"
    if (itemData?.aircraftName != null)
      discountType = $"{itemData.aircraftName}_shop"
    else if (itemData?.countryName != null)
      discountType = itemData.countryName

    let discountValue = _getDataItemDiscountText(itemData)

    return $"{::loc(discountType, "")}{::loc("ui/colon")}{discountValue}"
  }

  function getStackName(stackParams)
  {
    if (!stackParams.len())  //!fixedType
      return base.getName()
    return getDataItemDescription(stackParams)
  }

  function getIcon(addItemName = true)
  {
    local layers = base.getIcon()
    if (addItemName && !needHideTextOnIcon)
      layers += _getTextLayer()
    return layers
  }

  function _getTextLayer()
  {
    let layerCfg = ::LayersIcon.findLayerCfg("item_multiaward_text")
    if (!layerCfg)
      return ""

    layerCfg.text <- getLayerText()
    return ::LayersIcon.getTextDataFromLayer(layerCfg)
  }

  consume = @(cb, params) activateDiscount(cb, null)

  getSpecialOfferLocParams = @() discountDescriptionDataItems.len() > 0
    ? getLocParamsDescription(discountDescriptionDataItems[0])
    : null
}
