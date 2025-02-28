from "%scripts/dagui_natives.nut" import ps4_update_purchases_on_auth
from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")

let DataBlock = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { calcPercent } = require("%sqstd/math.nut")
let psnStore = require("sony.store")
let psnUser = require("sony.user")
let statsd = require("statsd")
let { serviceLabel } = require("%sonyLib/webApi.nut")
let { eventbus_subscribe } = require("eventbus")
let { GUI } = require("%scripts/utils/configs.nut")
let { targetPlatform } = require("%scripts/clientState/platform.nut")
let { getEntitlementId } = require("%scripts/onlineShop/onlineBundles.nut")
let { getEntitlementView } = require("%scripts/onlineShop/entitlementView.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { addTask } = require("%scripts/tasker.nut")
let { defer } = require("dagor.workcycle")

let IMAGE_TYPE = "TAM_JACKET"
let BQ_DEFAULT_ACTION_ERROR = -1

enum PURCHASE_STATUS {
  PURCHASED = "RED_BAG" // - Already purchased and cannot be purchased again
  PURCHASED_MULTI = "BLUE_BAG" // - Already purchased and can be purchased again
  NOT_PURCHASED = "NONE" // - Not yet purchased
}

function handleNewPurchase(itemId) {
  ps4_update_purchases_on_auth()
  let taskParams = { showProgressBox = true, progressBoxText = loc("charServer/checking") }
  addTask(::update_entitlements_limited(true), taskParams)
  broadcastEvent("PS4ItemUpdate", { id = itemId })
}

let getActionText = @(action) action == psnStore.Action.PURCHASED ? "purchased"
  : action == psnStore.Action.CANCELED ? "canceled"
  : action == BQ_DEFAULT_ACTION_ERROR ? "unknown"
  : "none"

function sendBqRecord(metric, itemId, result = null) {
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


function reportRecord(data, _record_name) {
  sendBqRecord([data.ctx.metricPlaceCall, "checkout.close"], data.ctx.itemId, data.result)
  if (data.result.action == psnStore.Action.PURCHASED)
    defer(@() handleNewPurchase(data.ctx.itemId)) //!!!FIX ME: This delayed action was added because of immediate and looped call eventbus in waitBox(used in ps4_update_purchases_on_auth)
}

eventbus_subscribe("storeCheckoutClosed", @(data) reportRecord(data, "checkout.close"))
eventbus_subscribe("storeDescriptionClosed", @(data) reportRecord(data, "description.close"))


local psnV2ShopPurchasableItem = class {
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

  constructor(blk, v_releaseDate) {
    this.id = blk.label
    this.entitlementId = getEntitlementId(this.id)
    this.name = blk.displayName
    this.category = blk?.category ?? ""
    this.description = blk?.description ?? ""
    this.releaseDate = v_releaseDate //PSN not give releaseDate param. but it return data in sorted order by release date

    let imagesArray = blk?.media.images != null ? (blk.media.images % "array") : []
    let imageIndex = imagesArray.findindex(@(t) t.type == IMAGE_TYPE)

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
    let isPlusPrice = this.skuInfo?.isPlusPrice ?? false
    let displayPrice = this.skuInfo?.displayPrice ?? ""
    let skuPrice = this.skuInfo?.price

    this.priceText = (!userHasPlus && isPlusPrice) ? (this.skuInfo?.displayOriginalPrice ?? "")
      : (userHasPlus && !isPlusPrice) ? (this.skuInfo?.displayPlusUpsellPrice ?? displayPrice)
      : displayPrice
    this.listPriceText = this.skuInfo?.displayOriginalPrice ?? this.skuInfo?.displayPrice ?? this.priceText

    this.price = (!userHasPlus && isPlusPrice) ? this.skuInfo?.originalPrice
      : (userHasPlus && !isPlusPrice) ? (this.skuInfo?.plusUpsellPrice ?? skuPrice)
      : skuPrice
    this.listPrice = this.skuInfo?.originalPrice ?? this.skuInfo?.price ?? this.price

    this.needHeader = this.price != null && this.listPrice != null

    this.productId = this.skuInfo?.id
    let purchStatus = this.skuInfo?.annotationName ?? PURCHASE_STATUS.NOT_PURCHASED
    this.isBought = purchStatus == PURCHASE_STATUS.PURCHASED
    this.isPurchasable = purchStatus != PURCHASE_STATUS.PURCHASED
    this.isMultiConsumable = (this.skuInfo?.useLimit ?? 0) > 0
    if (this.isMultiConsumable)
      this.defaultIconStyle = "reward_gold"
  }

  haveDiscount = @() !this.isBought && this.price != null && this.listPrice != null && this.price != this.listPrice
  havePsPlusDiscount = @() psnUser.hasPremium() && ("displayPlusUpsellPrice" in this.skuInfo || this.skuInfo?.isPlusPrice) //use in markup
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
      let splitDesc = [this.description.slice(0, maxSymbolsInLine)]
      let len = this.description.len()
      let totalLines = (len / maxSymbolsInLine).tointeger() + 1
      for (local i = 1; i < totalLines; i++) {
        splitDesc.append("\n")
        splitDesc.append(this.description.slice(i * maxSymbolsInLine, (i + 1) * maxSymbolsInLine))
      }
      return "".join(splitDesc)
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

  getSeenId = @() this.id.tostring()
  canBeUnseen = @() this.isBought
  showDetails = function(metricPlaceCall = "ingame_store.v2") {
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
  showDescription = function(metricPlaceCall = "ingame_store.v2") {
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

return psnV2ShopPurchasableItem
