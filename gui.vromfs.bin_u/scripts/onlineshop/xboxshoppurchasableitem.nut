local { calcPercent } = require("std/math.nut")
local statsd = require("statsd")

local XboxShopPurchasableItem = class
{
  defaultIconStyle = "default_chest_debug"
  imagePath = null

  id = ""
  mediaItemType = -1
  releaseDate = 0
  price = 0.0         // Price with discount as number
  listPrice = 0.0     // Original price without discount as number
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
  signedOffer = "" //for direct purchase

  amount = ""

  isMultiConsumable = false

  constructor(blk)
  {
    id = blk.getBlockName()
    mediaItemType = blk?.MediaItemType
    isMultiConsumable = mediaItemType == xboxMediaItemType.GameConsumable
    if (isMultiConsumable)
      defaultIconStyle = "reward_gold"

    name = blk?.Name ?? ""
    shortName = blk?.ReducedName ?? ""
    description = blk?.Description ?? ""

    releaseDate = blk?.ReleaseDate ?? 0

    price = blk?.Price
    priceText = blk?.DisplayPrice ?? ""
    listPrice = blk?.ListPrice
    listPriceText = blk?.DisplayListPrice ?? ""
    currencyCode = blk?.CurrencyCode ?? ""

    isPurchasable = blk?.IsPurchasable ?? false
    isBundle = blk?.IsBundle ?? false
    isPartOfAnyBundle = blk?.IsPartOfAnyBundle ?? false
    isBought = !!blk?.isBought

    consumableQuantity = blk?.ConsumableQuantity ?? 0
    signedOffer = blk?.SignedOffer ?? ""

    if (isPurchasable)
      amount = getPriceText()

    local xboxShopBlk = ::configs.GUI.get()?.xbox_ingame_shop
    local ingameShopImages = xboxShopBlk?.items
    if (ingameShopImages?[id] && xboxShopBlk?.mainPart && xboxShopBlk?.fileExtension)
      imagePath = "!" + xboxShopBlk.mainPart + id + xboxShopBlk.fileExtension
  }

  getPriceText = function() {
    if (price == null)
      return ""

    local color = haveDiscount()? "goodTextColor" : ""
    local text = price == 0? ::loc("shop/free") : (price + " " + currencyCode)
    return ::colorize(color, text)
  }

  updateIsBoughtStatus = @() isBought = isMultiConsumable? false : ::xbox_is_item_bought(id)
  haveDiscount = @() price != null && listPrice != null && !isBought && listPrice > 0 && price != listPrice
  getDiscountPercent = function() {
    if (price == null || listPrice == null)
      return 0

    return calcPercent(1 - (price.tofloat() / listPrice))
  }

  getDescription = function() {
    local strPrice = getPriceText()
    if (strPrice == "")
      return description

    if (haveDiscount())
      strPrice = ::loc("ugm/price") + " "
        + ::loc("ugm/withDiscount") + ::loc("ui/colon")
        + ::colorize("oldPrice", listPrice + " " + currencyCode)
        + " " + strPrice
    else
      strPrice = ::loc("ugm/price") + ::loc("ui/colon") + strPrice

    return strPrice + "\n" + description
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
    headerText = shortName
  }.__merge(params)

  isCanBuy = @() isPurchasable && !isBought
  isInactive = @() !isPurchasable || isBought

  getIcon = @(...) imagePath ? ::LayersIcon.getCustomSizeIconData(imagePath, "pw, ph")
                             : ::LayersIcon.getIconData(null, null, 1.0, defaultIconStyle)

  getSeenId = @() id.tostring()
  canBeUnseen = @() isBought
  showDetails = function(metricPlaceCall = "ingame_store") {
    statsd.send_counter($"sq.{metricPlaceCall}.open_product", 1)
    ::add_big_query_record("open_product",
      ::save_to_json({
        itemId = id
      })
    )
    ::xbox_show_details(id)
  }
  showDescription = @() null
}

return XboxShopPurchasableItem