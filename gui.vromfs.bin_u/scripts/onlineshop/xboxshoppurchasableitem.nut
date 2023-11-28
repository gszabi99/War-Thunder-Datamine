//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/onlineShop/onlineShopConsts.nut" import xboxMediaItemType

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { calcPercent } = require("%sqstd/math.nut")
let statsd = require("statsd")
let { cutPrefix } = require("%sqstd/string.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { getEntitlementId } = require("%scripts/onlineShop/onlineBundles.nut")
let { getEntitlementConfig } = require("%scripts/onlineShop/entitlements.nut")
let { getEntitlementView } = require("%scripts/onlineShop/entitlementView.nut")
let { ProductKind, show_details, get_total_quantity, retrieve_product_info } = require("%xboxLib/impl/store.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")

let XBOX_SHORT_NAME_PREFIX_CUT = "War Thunder - "

let function product_kind_to_media_item_type(product_kind) {
  switch (product_kind) {
    case ProductKind.Consumable: return xboxMediaItemType.GameConsumable
    case ProductKind.Durable: return xboxMediaItemType.GameContent
  }
  return 0;
}

local XboxShopPurchasableItem = class {
  defaultIconStyle = "default_chest_debug"
  imagePath = null

  id = ""
  entitlementId = ""
  categoriesList = null //list of available filters
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

  amount = ""

  isMultiConsumable = false
  needHeader = true

  constructor(data) {
    this.id = data.store_id
    this.entitlementId = getEntitlementId(this.id)

    let xbItemType = product_kind_to_media_item_type(data.product_kind)
    this.isMultiConsumable = xbItemType == xboxMediaItemType.GameConsumable
    if (this.isMultiConsumable)
      this.defaultIconStyle = "reward_gold"

    this.categoriesList = [xbItemType]
    let entConfig = getEntitlementConfig(this.entitlementId)
    if ("aircraftGift" in entConfig)
      this.categoriesList = entConfig.aircraftGift.map(@(unitId) getAircraftByName(unitId)?.unitType.typeName)
    else if (!this.isMultiConsumable)
      log($"[XBOX SHOP ITEM] not found aircraftGift in entitlementConfig, {this.entitlementId}, {this.id}")

    this.name = data.title
    this.shortName = cutPrefix(this.name, XBOX_SHORT_NAME_PREFIX_CUT, "")
    this.description = data.description
    this.releaseDate = 0 // For now we can't retreive ReleaseDate from live. Reported to MS, acknowledged, no ETA :(
    this.currencyCode = data.price.currency_code
    this.price = data.price.price
    this.priceText = this.price == 0.0 ? loc("shop/free") : $"{this.price} {this.currencyCode}"
    this.listPrice = data.price.base_price
    this.listPriceText = $"{this.listPrice} {this.currencyCode}"

    this.isPurchasable = true
    this.isBundle = false
    this.isPartOfAnyBundle = false
    this.isBought = data.is_in_user_collection

    this.consumableQuantity = get_total_quantity(data)
    this.needHeader = this.isPurchasable

    if (this.isPurchasable)
      this.amount = this.getPriceText()

    let xboxShopBlk = GUI.get()?.xbox_ingame_shop
    let ingameShopImages = xboxShopBlk?.items
    if (ingameShopImages?[this.id] && xboxShopBlk?.mainPart && xboxShopBlk?.fileExtension)
      this.imagePath = "!" + xboxShopBlk.mainPart + this.id + xboxShopBlk.fileExtension
  }

  getPriceText = function() {
    if (this.price == null)
      return ""

    return colorize(
      this.haveDiscount() ? "goodTextColor" : "",
      this.price == 0.0 ? loc("shop/free") : $"{this.price} {this.currencyCode}"
    )
  }

  updateIsBoughtStatus = function(callback) {
    if (this.isMultiConsumable) {
      this.isBought = false
      callback?(true)
    } else {
      retrieve_product_info(this.id, Callback(function(success, product) {
        log($"[XBOX SHOP ITEM] get product info succeeded: {success}")
        let quantity = get_total_quantity(product)
        this.isBought = success && (product.is_in_user_collection || quantity > 0)
        callback?(success)
      }, this))
    }
  }

  haveDiscount = @() this.price != null && this.listPrice != null && !this.isBought && this.listPrice > 0.0 && this.price != this.listPrice
  getDiscountPercent = function() {
    if (this.price == null || this.listPrice == null)
      return 0

    return calcPercent(1 - (this.price.tofloat() / this.listPrice))
  }

  getDescription = @() this.description

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

  getItemsView = @() getEntitlementView(this.entitlementId)

  isCanBuy = @() this.isPurchasable && !this.isBought
  isInactive = @() !this.isPurchasable || this.isBought

  getIcon = @(...) this.imagePath ? LayersIcon.getCustomSizeIconData(this.imagePath, "pw, ph")
                             : LayersIcon.getIconData(null, null, 1.0, this.defaultIconStyle)

  getSeenId = @() this.id.tostring()
  canBeUnseen = @() this.isBought
  showDetails = function(metricPlaceCall = "ingame_store") {
    statsd.send_counter($"sq.{metricPlaceCall}.open_product", 1)
    sendBqEvent("CLIENT_POPUP_1", "open_product", { itemId = this.id })
    show_details(this.id, null)
  }
  showDescription = @() null
}

return XboxShopPurchasableItem