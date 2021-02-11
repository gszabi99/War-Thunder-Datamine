local { calcPercent } = require("std/math.nut")

local psnStore = require("sony.store")
local psnUser = require("sony.user")
local statsd = require("statsd")
local { serviceLabel } = require("sonyLib/webApi.nut")

local IMAGE_TYPE_INDEX = 1 //240x240
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

  if (result != null)
  {
    sendStat["isPlusAuthorized"] <- result?.isPlusAuthorized ?? null
    sendStat["action"] <- result?.action ?? BQ_DEFAULT_ACTION_ERROR
  }

  if ("action" in sendStat)
  {
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

local Ps4ShopPurchasableItem = class
{
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

  constructor(blk, _releaseDate)
  {
    id = blk.label
    name = blk.name
    category = blk?.category ?? ""
    description = blk?.long_desc ?? ""
    releaseDate = _releaseDate //PSN not give releaseDate param. but it return data in sorted order by release date

    local imagesArray = blk?.images != null ? (blk.images % "array") : []
    local imageIndex = imagesArray.findindex(@(t) t.type == IMAGE_TYPE_INDEX)
    if (imageIndex != null && imagesArray[imageIndex]?.url)
      imagePath = $"{imagesArray[imageIndex].url}?P1"
    else {
      local psnShopBlk = ::configs.GUI.get()?.ps4_ingame_shop
      local ingameShopImages = psnShopBlk?.items
      if (ingameShopImages?[id] != null && psnShopBlk?.mainPart != null && psnShopBlk?.fileExtension != null)
        imagePath = $"!{psnShopBlk.mainPart}{id}{psnShopBlk.fileExtension}"
    }

    updateSkuInfo(blk)
  }

  function updateSkuInfo(blk)
  {
    skuInfo = (blk?.skus.blockCount() ?? 0) > 0? blk.skus.getBlock(0) : ::DataBlock()
    local userHasPlus = psnUser.hasPremium()
    local isPlusPrice = skuInfo?.is_plus_price ?? false
    local displayPrice = skuInfo?.display_price ?? ""
    local skuPrice = skuInfo?.price

    priceText = (!userHasPlus && isPlusPrice) ? (skuInfo?.display_original_price ?? "")
      : (userHasPlus && !isPlusPrice) ? (skuInfo?.display_plus_upsell_price ?? displayPrice)
      : displayPrice
    listPriceText = skuInfo?.display_original_price ?? skuInfo?.display_price ?? priceText

    price = (!userHasPlus && isPlusPrice) ? skuInfo?.original_price
      : (userHasPlus && !isPlusPrice) ? (skuInfo?.plus_upsell_price ?? skuPrice)
      : skuPrice
    listPrice = skuInfo?.original_price ?? skuInfo?.price ?? price

    needHeader = price != null && listPrice != null

    productId = skuInfo?.product_id
    local purchStatus = skuInfo?.annotation_name ?? PURCHASE_STATUS.NOT_PURCHASED
    isBought = purchStatus == PURCHASE_STATUS.PURCHASED
    isPurchasable = purchStatus != PURCHASE_STATUS.PURCHASED && (skuInfo?.is_purchaseable ?? false)
    isMultiConsumable = (skuInfo?.use_count ?? 0) > 0
    if (isMultiConsumable)
      defaultIconStyle = "reward_gold"
  }

  haveDiscount = @() !isBought && price != null && listPrice != null && price != listPrice
  havePsPlusDiscount = @() psnUser.hasPremium() && ("display_plus_upsell_price" in skuInfo || skuInfo?.is_plus_price) //use in markup
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
      local splitDesc = description.slice(0, maxSymbolsInLine)
      local len = description.len()
      local totalLines = (len / maxSymbolsInLine).tointeger() + 1
      for (local i = 1; i < totalLines; i++) {
        splitDesc += "\n"
        splitDesc += description.slice(i * maxSymbolsInLine, (i+1) * maxSymbolsInLine)
      }
      return splitDesc
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

  getBigIcon = function() {
    local ps4ShopBlk = ::configs.GUI.get()?.ps4_ingame_shop
    local ingameShopImages = ps4ShopBlk?.items
    if (ingameShopImages?[id] && ps4ShopBlk?.mainPart && ps4ShopBlk?.fileExtension)
      return ::LayersIcon.getCustomSizeIconData("!" + ps4ShopBlk.mainPart + id + ps4ShopBlk.fileExtension, "pw, ph")

    return null
  }

  getSeenId = @() id.tostring()
  canBeUnseen = @() isBought
  showDetails = function(metricPlaceCall = "ingame_store") {
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

  showDescription = function(metricPlaceCall = "ingame_store") {
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

return Ps4ShopPurchasableItem
