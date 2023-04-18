//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { calcPercent } = require("%sqstd/math.nut")
let statsd = require("statsd")
let { cutPrefix } = require("%sqstd/string.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { getEntitlementId } = require("%scripts/onlineShop/onlineBundles.nut")
let { getEntitlementConfig } = require("%scripts/onlineShop/entitlements.nut")
let { getEntitlementView } = require("%scripts/onlineShop/entitlementView.nut")

let XBOX_SHORT_NAME_PREFIX_CUT = "War Thunder - "

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
  signedOffer = "" //for direct purchase

  amount = ""

  isMultiConsumable = false
  needHeader = true

  constructor(blk) {
    this.id = blk.getBlockName()
    this.entitlementId = getEntitlementId(this.id)

    let xbItemType = blk?.MediaItemType
    this.isMultiConsumable = xbItemType == xboxMediaItemType.GameConsumable
    if (this.isMultiConsumable)
      this.defaultIconStyle = "reward_gold"

    this.categoriesList = [xbItemType]
    let entConfig = getEntitlementConfig(this.entitlementId)
    if ("aircraftGift" in entConfig)
      this.categoriesList = entConfig.aircraftGift.map(@(unitId) ::getAircraftByName(unitId)?.unitType.typeName)
    else if (!this.isMultiConsumable)
      log($"[XBOX SHOP ITEM] not found aircraftGift in entitlementConfig, {this.entitlementId}, {this.id}")

    this.name = blk?.Name ?? ""
    //HACK: On GDK no param ReducedName, c++ code copy to this key original name
    //Because of difficulties in searching packs by game title on xbox store
    //We don't want to change packs names
    //So have to try cut prefix if ReducedName is equal as Name
    //On XDK they are different and correct
    this.shortName = blk?.ReducedName == this.name ? cutPrefix(this.name, XBOX_SHORT_NAME_PREFIX_CUT, "") : (blk?.ReducedName ?? "")
    this.description = blk?.Description ?? ""

    this.releaseDate = blk?.ReleaseDate ?? 0

    this.price = blk?.Price ?? 0.0
    this.priceText = this.price == 0.0 ? loc("shop/free") : (blk?.DisplayPrice ?? "")
    this.listPrice = blk?.ListPrice ?? 0.0
    this.listPriceText = blk?.DisplayListPrice ?? ""
    this.currencyCode = blk?.CurrencyCode ?? ""

    this.isPurchasable = blk?.IsPurchasable ?? false
    this.isBundle = blk?.IsBundle ?? false
    this.isPartOfAnyBundle = blk?.IsPartOfAnyBundle ?? false
    this.isBought = !!blk?.isBought

    this.consumableQuantity = blk?.ConsumableQuantity ?? 0
    this.signedOffer = blk?.SignedOffer ?? ""

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

  updateIsBoughtStatus = @() this.isBought = this.isMultiConsumable ? false : ::xbox_is_item_bought(this.id)
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

  getIcon = @(...) this.imagePath ? ::LayersIcon.getCustomSizeIconData(this.imagePath, "pw, ph")
                             : ::LayersIcon.getIconData(null, null, 1.0, this.defaultIconStyle)

  getSeenId = @() this.id.tostring()
  canBeUnseen = @() this.isBought
  showDetails = function(metricPlaceCall = "ingame_store") {
    statsd.send_counter($"sq.{metricPlaceCall}.open_product", 1)
    ::add_big_query_record("open_product",
      ::save_to_json({
        itemId = this.id
      })
    )
    ::xbox_show_details(this.id)
  }
  showDescription = @() null
}

return XboxShopPurchasableItem