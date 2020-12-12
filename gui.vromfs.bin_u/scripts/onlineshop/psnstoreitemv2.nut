local { calcPercent } = require("std/math.nut")

local psnStore = require("sony.store")
local psnUser = require("sony.user")
local statsd = require("statsd")
local { serviceLabel } = require("sonyLib/webApi.nut")

local IMAGE_TYPE = "TAM_JACKET"
local BQ_DEFAULT_ACTION_ERROR = -1

enum PURCHASE_STATUS {
  PURCHASED = "RED_BAG" // - Already purchased and cannot be purchased again
  PURCHASED_MULTI = "BLUE_BAG" // - Already purchased and can be purchased again
  NOT_PURCHASED = "NONE" // - Not yet purchased
}

local function handleNewPurchase(itemId) {
  ::ps4_update_purchases_on_auth()
  local taskParams = { showProgressBox = true, progressBoxText = ::loc("charServer/checking") }
  ::g_tasker.addTask(::update_entitlements_limited(true), taskParams)
  ::broadcastEvent("PS4ItemUpdate", {id = itemId})
}

local getActionText = @(action) action == psnStore.Action.PURCHASED ? "purchased"
  : action == psnStore.Action.CANCELED ? "canceled"
  : action == BQ_DEFAULT_ACTION_ERROR ? "unknown"
  : "none"

local function sendBqRecord(metric, itemId, result = null) {
  local sendStat = {}

  if (result != null) {
    sendStat["isPlusAuthorized"] <- result?.isPlusAuthorized ?? null
    sendStat["action"] <- result?.action ?? BQ_DEFAULT_ACTION_ERROR
  }

  if ("action" in sendStat) {
    sendStat.__update({action = getActionText(sendStat.action)})
    metric.append(sendStat.action)
  }

  local path = ".".join(metric)
  statsd.send_counter($"sq.{path}", 1)
  ::add_big_query_record(path,
    ::save_to_json(sendStat.__merge({
      itemId = itemId
    }))
  )
}

local psnV2ShopPurchasableItem = class {
  defaultIconStyle = "default_chest_debug"
  imagePath = null

  id = ""
  category = ""
  releaseDate = 0
  price = 0           // Price with discount as number
  listPrice = 0       // Original price without discount as number
  priceText = ""      // Price with discount as string
  listPriceText = ""  // Original price without discount as string
  currencyCode = ""
  isPurchasable = false
  isBought = false
  name = ""
  shortName = ""
  description = ""
  isBundle = false
  isPartOfAnyBundle = false
  consumableQuantity = 0
  productId = ""

  amount = ""

  isMultiConsumable = false
  needHeader = true

  skuInfo = null

  constructor(blk, _releaseDate) {
    id = blk.label
    name = blk.displayName
    category = blk?.category ?? ""
    description = blk?.description ?? ""
    releaseDate = _releaseDate //PSN not give releaseDate param. but it return data in sorted order by release date

    local imagesArray = blk?.media.images != null ? (blk.media.images % "array") : []
    local imageIndex = imagesArray.findindex(@(t) t.type == IMAGE_TYPE)
    if (imageIndex != null && imagesArray[imageIndex]?.url)
      imagePath = $"{imagesArray[imageIndex].url}?P1"

    updateSkuInfo(blk)
  }

  function updateSkuInfo(blk) {
    skuInfo = (blk?.skus.blockCount() ?? 0) > 0? blk.skus.getBlock(0) : ::DataBlock()
    local userHasPlus = psnUser.hasPremium()
    local isPlusPrice = skuInfo?.isPlusPrice ?? false
    local displayPrice = skuInfo?.displayPrice ?? ""
    local skuPrice = skuInfo?.price

    priceText = (!userHasPlus && isPlusPrice) ? (skuInfo?.displayOriginalPrice ?? "")
      : (userHasPlus && !isPlusPrice) ? (skuInfo?.displayPlusUpsellPrice ?? displayPrice)
      : displayPrice
    listPriceText = skuInfo?.displayOriginalPrice ?? skuInfo?.displayPrice ?? priceText

    price = (!userHasPlus && isPlusPrice) ? skuInfo?.originalPrice
      : (userHasPlus && !isPlusPrice) ? (skuInfo?.plusUpsellPrice ?? skuPrice)
      : skuPrice
    listPrice = skuInfo?.originalPrice ?? skuInfo?.price ?? price

    needHeader = price != null && listPrice != null

    productId = skuInfo?.id
    local purchStatus = skuInfo?.annotationName ?? PURCHASE_STATUS.NOT_PURCHASED
    isBought = purchStatus == PURCHASE_STATUS.PURCHASED
    isPurchasable = purchStatus != PURCHASE_STATUS.PURCHASED
    isMultiConsumable = (skuInfo?.useLimit ?? 0) > 0
    if (isMultiConsumable)
      defaultIconStyle = "reward_gold"
  }

  haveDiscount = @() !isBought && price != null && listPrice != null && price != listPrice
  havePsPlusDiscount = @() psnUser.hasPremium() && ("displayPlusUpsellPrice" in skuInfo || skuInfo?.isPlusPrice) //use in markup
  getDiscountPercent = @() (price == null && listPrice == null)? 0 : calcPercent(1 - (price.tofloat() / listPrice))

  getPriceText = function() {
    if (priceText == "")
      return ""

    local color = !haveDiscount() ? ""
      : havePsPlusDiscount() ? "psplusTextColor"
      : "goodTextColor"

    return ::colorize(color, priceText)
  }

  getDescription = function() {
    //TEMP HACK!!! for PS4 TRC R4052A, to show all symbols of a single 2000-letter word
    local maxSymbolsInLine = 50 // Empirically fits with the biggest font we have
    if (description.len() > maxSymbolsInLine && description.indexof(" ") == null) {
      local splitDesc = [description.slice(0, maxSymbolsInLine)]
      local len = description.len()
      local totalLines = (len / maxSymbolsInLine).tointeger() + 1
      for (local i = 1; i < totalLines; i++) {
        splitDesc.append("\n")
        splitDesc.append(description.slice(i * maxSymbolsInLine, (i+1) * maxSymbolsInLine))
      }
      return "".join(splitDesc)
    }

    return description
  }

  getViewData = @(params = {}) {
    isAllBought = isBought
    price = getPriceText()
    layered_image = getIcon()
    enableBackground = true
    isInactive = isInactive()
    isItemLocked = !isPurchasable
    itemHighlight = isBought
    needAllBoughtIcon = true
    needPriceFadeBG = true
    headerText = shortName
    havePsPlusDiscount = havePsPlusDiscount()
  }.__merge(params)

  isCanBuy = @() isPurchasable && !isBought
  isInactive = @() !isPurchasable || isBought

  getIcon = @(...) imagePath ? ::LayersIcon.getCustomSizeIconData(imagePath, "pw, ph")
                             : ::LayersIcon.getIconData(null, null, 1.0, defaultIconStyle)

  getSeenId = @() id.tostring()
  canBeUnseen = @() isBought
  showDetails = function(metricPlaceCall = "ingame_store.v2") {
    local itemId = id
    sendBqRecord([metricPlaceCall, "checkout.open"], itemId)
    psnStore.open_checkout(
      [itemId],
      serviceLabel,
      function(result) {
        sendBqRecord([metricPlaceCall, "checkout.close"], itemId, result)
        if (result.action == psnStore.Action.PURCHASED)
          handleNewPurchase(itemId)
      }
    )
  }

  showDescription = function(metricPlaceCall = "ingame_store.v2") {
    local itemId = id
    sendBqRecord([metricPlaceCall, "description.open"], itemId)
    psnStore.open_product(
      itemId,
      serviceLabel,
      function(result) {
        sendBqRecord([metricPlaceCall, "description.close"], itemId, result)
        if (result.action == psnStore.Action.PURCHASED)
          handleNewPurchase(itemId)
      }
    )
  }
}

return psnV2ShopPurchasableItem
