//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")

let statsd = require("statsd")
let { GUI } = require("%scripts/utils/configs.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")

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
    this.id = blk.id
    this.apiVersion = blk?.ApiVersion ?? 1
    this.serverIndex = blk?.ServerIndex ?? 1
    this.catalogNamespace = blk?.CatalogNamespace ?? "dlc"
    this.expirationTimestamp = blk?.ExpirationTimestamp ?? 0

    let purchLimit = blk?.PurchaseLimit ?? 1
    this.isMultiConsumable = purchLimit == -1

    if (this.isMultiConsumable) {
      this.defaultIconStyle = "reward_gold"
      this.mediaItemType = "gold"
    }

    this.name = blk?.TitleText ?? ""
    this.description = blk?.DescriptionText ?? ""
    this.longDescription = blk?.LongDescriptionText ?? ""

    this.price = (blk?.CurrentPrice ?? 0) * 0.01 // 100 = kopeyki
    this.listPrice = (blk?.OriginalPrice ?? 0) * 0.01
    this.priceText = this.price.tostring()
    this.listPriceText = this.listPrice.tostring()
    this.currencyCode = blk?.CurrencyCode
    this.discount = blk?.DiscountPercentage ?? 0
    this.isPurchasable = blk?.bAvailableForPurchase ?? false

    if (this.isPurchasable)
      this.amount = this.getPriceText()

    let shopBlk = GUI.get()?.epic_ingame_shop
    let ingameShopImages = shopBlk?.items
    if (ingameShopImages?[this.id] && shopBlk?.mainPart && shopBlk?.fileExtension)
      this.imagePath = $"!{shopBlk.mainPart}{this.id}{shopBlk.fileExtension}"

    this.update(blk)
  }

  update = function(blk) {
    this.isBought = this.isMultiConsumable ? false : ((blk?.PurchasedCount ?? 0) > 0)
  }

  getPriceText = function() {
    if (this.priceText == "")
      return ""

    let color = this.haveDiscount() ? "goodTextColor" : ""
    let text = this.price == 0.0 ? loc("shop/free") : " ".join([this.priceText, this.currencyCode], true)
    return colorize(color, text)
  }

  haveDiscount = @() !this.isBought && this.price != this.listPrice
  getDiscountPercent = @() this.discount

  getDescription = function() {
    local strPrice = this.getPriceText()
    if (strPrice == "")
      return this.description

    if (this.haveDiscount())
      strPrice = "{0} {1}{2}{3} {4}".subst(
        loc("ugm/price"),
        loc("ugm/withDiscount"),
        loc("ui/colon"),
        colorize("oldPrice", " ".join([this.listPrice, this.currencyCode])),
        strPrice
      )
    else
      strPrice = "".join([loc("ugm/price"), loc("ui/colon"), strPrice])

    return "\n".join([strPrice, this.description])
  }

  getViewData = @(params = {}) {
    isAllBought = this.isBought
    price = this.getPriceText()
    layered_image = this.getIcon()
    enableBackground = true
    isInactive = this.isInactive()
    isItemLocked = !this.isPurchasable
    itemHighlight = this.isBought
    needAllBoughtIcon = true
    headerText = this.shortName
  }.__merge(params)

  isCanBuy = @() this.isPurchasable && !this.isBought
  isInactive = @() !this.isPurchasable || this.isBought

  getIcon = @(...) this.imagePath ? LayersIcon.getCustomSizeIconData(this.imagePath, "pw, ph")
                             : LayersIcon.getIconData(null, null, 1.0, this.defaultIconStyle)

  getSeenId = @() this.id.tostring()
  canBeUnseen = @() this.isBought

  showDetails = function(metricPlaceCall = "ingame_store") {
    statsd.send_counter($"sq.{metricPlaceCall}.open_product", 1)
    sendBqEvent("CLIENT_POPUP_1", "open_product", { itemId = this.id })
    ::epic_buy_item(this.id)
  }
  showDescription = @() null
}


return EpicShopPurchasableItem
