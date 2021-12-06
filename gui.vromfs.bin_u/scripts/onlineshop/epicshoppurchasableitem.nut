local statsd = require("statsd")

local EpicShopPurchasableItem = class {
  defaultIconStyle = "default_chest_debug"
  imagePath = null

  id = ""
  apiVersion = 1
  serverIndex = 1

  mediaItemType = "dlc"
  catalogNamespace = "dlc"
  price = 0         // Price with discount as number
  listPrice = 0     // Original price without discount as number
  priceText = ""      // Price with discount as string
  listPriceText = ""  // Original price without discount as string
  currencyCode = null
  discount = 0
  isPurchasable = false
  isBought = false
  name = ""
  shortName = ""
  description = ""
  longDescription = ""
  isBundle = false
  isPartOfAnyBundle = false
  consumableQuantity = 1

  expirationTimestamp = 0

  amount = ""

  isMultiConsumable = false

  constructor(blk) {
    id = blk.id
    apiVersion = blk?.ApiVersion ?? 1
    serverIndex = blk?.ServerIndex ?? 1
    catalogNamespace = blk?.CatalogNamespace ?? "dlc"
    expirationTimestamp = blk?.ExpirationTimestamp ?? 0

    local purchLimit = blk?.PurchaseLimit ?? 1
    isMultiConsumable = purchLimit == -1

    if (isMultiConsumable) {
      defaultIconStyle = "reward_gold"
      mediaItemType = "gold"
    }

    name = blk?.TitleText ?? ""
    description = blk?.DescriptionText ?? ""
    longDescription = blk?.LongDescriptionText ?? ""

    price = (blk?.CurrentPrice ?? 0) * 0.01 // 100 = kopeyki
    listPrice = (blk?.OriginalPrice ?? 0) * 0.01
    priceText = price.tostring()
    listPriceText = listPrice.tostring()
    currencyCode = blk?.CurrencyCode
    discount = blk?.DiscountPercentage ?? 0
    isPurchasable = blk?.bAvailableForPurchase ?? false

    if (isPurchasable)
      amount = getPriceText()

    local shopBlk = ::configs.GUI.get()?.epic_ingame_shop
    local ingameShopImages = shopBlk?.items
    if (ingameShopImages?[id] && shopBlk?.mainPart && shopBlk?.fileExtension)
      imagePath = $"!{shopBlk.mainPart}{id}{shopBlk.fileExtension}"

    update(blk)
  }

  update = function(blk) {
    isBought = isMultiConsumable? false : ((blk?.PurchasedCount ?? 0) > 0)
  }

  getPriceText = function() {
    if (priceText == "")
      return ""

    local color = haveDiscount() ? "goodTextColor" : ""
    local text = price == 0.0 ? ::loc("shop/free") : " ".join([priceText, currencyCode], true)
    return ::colorize(color, text)
  }

  haveDiscount = @() !isBought && price != listPrice
  getDiscountPercent = @() discount

  getDescription = function() {
    local strPrice = getPriceText()
    if (strPrice == "")
      return description

    if (haveDiscount())
      strPrice = "{0} {1}{2}{3} {4}".subst(
        ::loc("ugm/price"),
        ::loc("ugm/withDiscount"),
        ::loc("ui/colon"),
        ::colorize("oldPrice", " ".join([listPrice, currencyCode])),
        strPrice
      )
    else
      strPrice = "".join([::loc("ugm/price"), ::loc("ui/colon"), strPrice])

    return "\n".join([strPrice, description])
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
    ::epic_buy_item(id)
  }
  showDescription = @() null
}


return EpicShopPurchasableItem
