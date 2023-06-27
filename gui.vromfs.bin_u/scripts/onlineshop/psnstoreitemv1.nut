//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")

let DataBlock = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { calcPercent } = require("%sqstd/math.nut")
let psnStore = require("sony.store")
let psnUser = require("sony.user")
let statsd = require("statsd")
let { serviceLabel } = require("%sonyLib/webApi.nut")
let { subscribe } = require("eventbus")
let { GUI } = require("%scripts/utils/configs.nut")
let { targetPlatform } = require("%scripts/clientState/platform.nut")
let { getEntitlementId } = require("%scripts/onlineShop/onlineBundles.nut")
let { getEntitlementView } = require("%scripts/onlineShop/entitlementView.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")

let IMAGE_TYPE_INDEX = 1 //240x240
let BQ_DEFAULT_ACTION_ERROR = -1

enum PURCHASE_STATUS {
  PURCHASED = "RED_BAG" // - Already purchased and cannot be purchased again
  PURCHASED_MULTI = "BLUE_BAG" // - Already purchased and can be purchased again
  NOT_PURCHASED = "NONE" // - Not yet purchased
}

let function handleNewPurchase(itemId) {
  ::ps4_update_purchases_on_auth()
  let taskParams = { showProgressBox = true, progressBoxText = loc("charServer/checking") }
  ::g_tasker.addTask(::update_entitlements_limited(true), taskParams)
  broadcastEvent("PS4ItemUpdate", { id = itemId })
}

let getActionText = @(action) action == psnStore.Action.PURCHASED ? "purchased"
  : action == psnStore.Action.CANCELED ? "canceled"
  : action == BQ_DEFAULT_ACTION_ERROR ? "unknown"
  : "none"

let function sendBqRecord(metric, itemId, result = null) {
  let sendStat = {}

  if (result != null) {
    sendStat["isPlusAuthorized"] <- result?.isPlusAuthorized
    sendStat["action"] <- result?.action ?? BQ_DEFAULT_ACTION_ERROR
  }

  if ("action" in sendStat) {
    sendStat.__update({ action = getActionText(sendStat.action) })
    metric.append(sendStat.action)
  }

  let path = ".".join(metric)
  statsd.send_counter($"sq.{path}", 1)
  sendBqEvent("CLIENT_POPUP_1", path, sendStat.__merge({
    itemId = itemId
  }))
}

let function reportRecord(data, _record_name) {
  sendBqRecord([data.ctx.metricPlaceCall, "checkout.close"], data.ctx.itemId, data.result)
  if (data.result.action == psnStore.Action.PURCHASED)
    handleNewPurchase(data.ctx.itemId)
}

subscribe("storeCheckoutClosed", @(data) reportRecord(data, "checkout.close"))
subscribe("storeDescriptionClosed", @(data) reportRecord(data, "description.close"))

local Ps4ShopPurchasableItem = class {
  defaultIconStyle = "default_chest_debug"
  imagePath = null

  id = ""
  entitlementId = ""
  category = ""
  srvLabel = serviceLabel
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

  constructor(blk, release_date) {
    this.id = blk.label
    this.entitlementId = getEntitlementId(this.id)
    this.name = blk.name
    this.category = blk?.category ?? ""
    this.description = blk?.long_desc ?? ""
    this.releaseDate = release_date //PSN not give releaseDate param. but it return data in sorted order by release date

    let imagesArray = blk?.images != null ? (blk.images % "array") : []
    let imageIndex = imagesArray.findindex(@(t) t.type == IMAGE_TYPE_INDEX)

    let psnShopBlk = GUI.get()?.ps4_ingame_shop
    if (imageIndex != null && imagesArray[imageIndex]?.url)
      this.imagePath = $"{imagesArray[imageIndex].url}?P1"
    else if (psnShopBlk?.mainPart != null && psnShopBlk?.fileExtension != null)
      this.imagePath = $"!{psnShopBlk.mainPart}{this.id}{psnShopBlk.fileExtension}"

    let customServiceLabelBlk = psnShopBlk?.customServiceLabel[targetPlatform]
    if (customServiceLabelBlk)
      this.srvLabel = customServiceLabelBlk?[this.id] ?? serviceLabel

    this.updateSkuInfo(blk)
  }

  function updateSkuInfo(blk) {
    this.skuInfo = (blk?.skus.blockCount() ?? 0) > 0 ? blk.skus.getBlock(0) : DataBlock()
    let userHasPlus = psnUser.hasPremium()
    let isPlusPrice = this.skuInfo?.is_plus_price ?? false
    let displayPrice = this.skuInfo?.display_price ?? ""
    let skuPrice = this.skuInfo?.price

    this.priceText = (!userHasPlus && isPlusPrice) ? (this.skuInfo?.display_original_price ?? "")
      : (userHasPlus && !isPlusPrice) ? (this.skuInfo?.display_plus_upsell_price ?? displayPrice)
      : displayPrice
    this.listPriceText = this.skuInfo?.display_original_price ?? this.skuInfo?.display_price ?? this.priceText

    this.price = (!userHasPlus && isPlusPrice) ? this.skuInfo?.original_price
      : (userHasPlus && !isPlusPrice) ? (this.skuInfo?.plus_upsell_price ?? skuPrice)
      : skuPrice
    this.listPrice = this.skuInfo?.original_price ?? this.skuInfo?.price ?? this.price

    this.needHeader = this.price != null && this.listPrice != null

    this.productId = this.skuInfo?.product_id
    let purchStatus = this.skuInfo?.annotation_name ?? PURCHASE_STATUS.NOT_PURCHASED
    this.isBought = purchStatus == PURCHASE_STATUS.PURCHASED
    this.isPurchasable = purchStatus != PURCHASE_STATUS.PURCHASED && (this.skuInfo?.is_purchaseable ?? false)
    this.isMultiConsumable = (this.skuInfo?.use_count ?? 0) > 0
    if (this.isMultiConsumable)
      this.defaultIconStyle = "reward_gold"
  }

  haveDiscount = @() !this.isBought && this.price != null && this.listPrice != null && this.price != this.listPrice
  havePsPlusDiscount = @() psnUser.hasPremium() && ("display_plus_upsell_price" in this.skuInfo || this.skuInfo?.is_plus_price) //use in markup
  getDiscountPercent = @() (this.price == null && this.listPrice == null) ? 0 : calcPercent(1 - (this.price.tofloat() / this.listPrice))

  getPriceText = function() {
    if (this.priceText == "")
      return ""

    let color = !this.haveDiscount() ? ""
      : this.havePsPlusDiscount() ? "psplusTextColor"
      : "goodTextColor"

    return colorize(color, this.priceText)
  }

  getDescription = function() {
    //TEMP HACK!!! for PS4 TRC R4052A, to show all symbols of a single 2000-letter word
    let maxSymbolsInLine = 50 // Empirically fits with the biggest font we have
    if (this.description.len() > maxSymbolsInLine && this.description.indexof(" ") == null) {
      local splitDesc = this.description.slice(0, maxSymbolsInLine)
      let len = this.description.len()
      let totalLines = (len / maxSymbolsInLine).tointeger() + 1
      for (local i = 1; i < totalLines; i++) {
        splitDesc += "\n"
        splitDesc += this.description.slice(i * maxSymbolsInLine, (i + 1) * maxSymbolsInLine)
      }
      return splitDesc
    }

    return this.description
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
    needPriceFadeBG = true
    headerText = this.shortName
    havePsPlusDiscount = this.havePsPlusDiscount()
  }.__merge(params)

  getItemsView = @() getEntitlementView(this.entitlementId)

  isCanBuy = @() this.isPurchasable && !this.isBought
  isInactive = @() !this.isPurchasable || this.isBought

  getIcon = @(...) this.imagePath ? LayersIcon.getCustomSizeIconData(this.imagePath, "pw, ph")
                             : LayersIcon.getIconData(null, null, 1.0, this.defaultIconStyle)

  getBigIcon = function() {
    let ps4ShopBlk = GUI.get()?.ps4_ingame_shop
    let ingameShopImages = ps4ShopBlk?.items
    if (ingameShopImages?[this.id] && ps4ShopBlk?.mainPart && ps4ShopBlk?.fileExtension)
      return LayersIcon.getCustomSizeIconData("!" + ps4ShopBlk.mainPart + this.id + ps4ShopBlk.fileExtension, "pw, ph")

    return null
  }

  getSeenId = @() this.id.tostring()
  canBeUnseen = @() this.isBought
  showDetails = function(metricPlaceCall = "ingame_store") {
    let itemId = this.id
    let eventData = { itemId = itemId, metricPlaceCall = metricPlaceCall }
    sendBqRecord([metricPlaceCall, "checkout.open"], itemId)
    psnStore.open_checkout(
      [itemId],
      this.srvLabel,
      "storeCheckoutClosed",
      eventData
    )
  }

  showDescription = function(metricPlaceCall = "ingame_store") {
    let itemId = this.id
    let eventData = { itemId = itemId, metricPlaceCall = metricPlaceCall }
    sendBqRecord([metricPlaceCall, "description.open"], itemId)
    psnStore.open_product(
      itemId,
      this.srvLabel,
      "storeDescriptionClosed",
      eventData
    )
  }
}

return Ps4ShopPurchasableItem
