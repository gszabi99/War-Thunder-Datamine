from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let { parseDiscountDescription, createDiscountDescriptionSortData,
  sortDiscountDescriptionItems } = require("%scripts/items/discountItemSortMethod.nut")

::items_classes.Discount <- class extends ::BaseItem
{
  static iType = itemType.DISCOUNT
  static defaultLocId = "personalDiscount"
  static defaultIconStyle = "default_personal_discount"
  static typeIcon = "#ui/gameuiskin#item_type_discounts.svg"

  discountDescBlk = null
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
    canBuy = hasFeature("CanBuyDiscountItems")
    base.constructor(blk, invBlk, slotData)
    purchasesCount = invBlk?.purchasesCount ?? 0

    showAmountInsteadPercent = blk?.showAmountInsteadPercent ?? false
    isSpecialOffer = blk?.isSpecialOffer ?? false
    shouldAutoConsume = shouldAutoConsume || isSpecialOffer
    specialOfferImage = blk?.specialOfferImage
    specialOfferImageRatio = blk?.specialOfferImageRatio
    needHideTextOnIcon = blk?.needHideTextOnIcon ?? false
    purchasesMaxCount = blk?.purchasesMaxCount ?? 0
    discountDescBlk = blk?.personalDiscountsParams.discountsDesc
    discountDescriptionDataItems = []
  }

  function _initPersonalDiscountParams()
  {
    if (discountDescBlk == null)
      return

    discountDescriptionDataItems = parseDiscountDescription(discountDescBlk)
    let sortData = createDiscountDescriptionSortData(discountDescBlk)
    sortDiscountDescriptionItems(discountDescriptionDataItems, sortData)
    discountDescBlk = null
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
    let taskCallback = Callback((@(cb) function() {
      ::g_discount.updateDiscountData()
      cb({ success = true })
    })(cb), handler)

    ::g_tasker.addTask(taskId, { showProgressBox = true }, taskCallback)
    return true
  }

  function getName(colored = true)
  {
    let discountDescriptionData = getDiscountDescriptionDataItems()
    if (discountDescriptionData.len() == 0)
      return base.getName(colored)
    local item = discountDescriptionData[0]
    if (item.type == "aircraft")
    {
      let hasMultipleVehicles = (discountDescriptionData.len() > 1 &&
        discountDescriptionData[1].type == "aircraft" &&
        discountDescriptionData[1].category == discountDescriptionData[0].category)
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
        btnName = loc("item/activate")
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
      if (isInArray(currentDiscountUid, uids))
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
      result += loc("items/discount/purchasesCounter", locParams) + "\n"
    }

    let expireText = getCurExpireTimeText()
    if (expireText != "")
      result += expireText + "\n"

    foreach (item in getDiscountDescriptionDataItems())
    {
      if (result != "")
        result += "\n"
      result += getDataItemDescription(item)
    }
    return result
  }

  function _getDataItemDiscountText(dataItem, toTextFunc = function(val) { return val + "%" })
  {
    let value = getTblValue("discountValue", dataItem, 0)
    if (value)
      return toTextFunc(value)

    let minValue = getTblValue("discountMin", dataItem, 0)
    let maxValue = getTblValue("discountMax", dataItem, 0)
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
    return loc(locId, locParams)
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
      locParams.countryNameOptional <- $" ({loc(countryName)})"
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
    locParams.discount = colorize("activeTextColor", locParams.discount)
    return locParams
  }

  function getMaxDiscountByCategoryAndType(category, dType)
  {
    local result = 0
    foreach (dataItem in getDiscountDescriptionDataItems())
    {
      if (dataItem.category == category && dataItem.type == dType)
        result = max(result, dataItem.discountValue)
    }
    return result
  }

  function isFixedType()
  {
    return getDiscountDescriptionDataItems().len() == 1
  }

  function canStack(item)
  {
    let fixedType = isFixedType()
    if (item.isFixedType() != fixedType)
      return false
    if (!fixedType)
      return true

    let discountDescriptionData = getDiscountDescriptionDataItems()
    let data1 = discountDescriptionData[0]
    let data2 = item.getDiscountDescriptionDataItems()[0]
    foreach(p in stackBases)
      if (getTblValue(p, data1) != getTblValue(p, data2))
        return false
    return true
  }

  function updateStackParams(stackParams)
  {
    if (!isFixedType())
      return

    let data = getDiscountDescriptionDataItems()[0]
    if (!stackParams.len()) //stack not inited
      foreach(p in stackBases)
        stackParams[p] <- getTblValue(p, data)

    foreach(p in stackVariables)
    {
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

  function getLayerText(colored = true)
  {
    let discountDescriptionData = getDiscountDescriptionDataItems()
    if (discountDescriptionData.len() == 0)
      return getName(colored)

    let itemData = discountDescriptionData[0]
    local discountType = $"item/discount/{itemData?.type ?? ""}"
    if (itemData?.aircraftName != null)
      discountType = $"{itemData.aircraftName}_shop"
    else if (itemData?.countryName != null)
      discountType = itemData.countryName

    let discountValue = _getDataItemDiscountText(itemData)

    return $"{loc(discountType, "")}{loc("ui/colon")}{discountValue}"
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

  function getSpecialOfferLocParams() {
    let discountDescriptionData = getDiscountDescriptionDataItems()
    return discountDescriptionData.len() > 0
      ? getLocParamsDescription(discountDescriptionData[0])
      : null
  }

  function getDiscountDescriptionDataItems() {
    _initPersonalDiscountParams()
    return discountDescriptionDataItems
  }
}
