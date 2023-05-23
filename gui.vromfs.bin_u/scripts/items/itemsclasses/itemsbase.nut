//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")

let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

let { format } = require("string")
let { get_time_msec } = require("dagor.time")
let DataBlock  = require("DataBlock")
/* Item API:
  getCost                    - return item cost
  buy(cb, handler)            - buy item, call cb when buy success
  getViewData()               - generate item view data for item.tpl
  getContentIconData()        - return table to fill contentIconData in visual item
                                { contentIcon, [contentType] }
  getAmount()

  getName()
  getNameMarkup()             - type icon and title as markup, with full tooltip
  getIcon()                   - main functions for item image
  getSmallIconName()          - small icon for using insede the text
  getBigIcon()
  getOpenedIcon()             - made for trophies-like items
  getOpenedBigIcon()
  getDescription()
  getShortDescription()        - assume that it will be name and short decription info
                               better up to 30 letters approximatly
  getPrizeDescription(count)   - special prize description. when return null, will be used getShortDescription
  getLongDescription()         - unlimited length description as text.
  getLongDescriptionMarkup(params)   - unlimited length description as markup.
  getDescriptionTitle()
  getItemTypeDescription(loc_params)     - show description of item type in tooltip of "?" image
  getShortItemTypeDescription() - show short description of item type above item image

  getDescriptionAboveTable()  - return description part right above table.
  getDescriptionUnderTable()   - Returns description part which is placed under the table.
                                 Both table and this description part are optional.

  getStopConditions()          - added for boosters, but perhaps, it have in some other items

  getMainActionData(isShort = false, params = {})
                                    - get main action data (short will be on item button)
  doMainAction(cb, handler)         - do main action. (buy, activate, etc)

  canStack(item)                    - (bool) compare with item same type can it be stacked in one
  updateStackParams(stackParams)     - update stack params to correct show stack name //completely depend on itemtype
  getStackName(stackParams)         - get stack name by stack params
  isForEvent(checkEconomicName)     - check is checking event id is for current item (used in tickets for now)
*/


let { hoursToString, secondsToHours, getTimestampFromStringUtc } = require("%scripts/time.nut")
let { validateLink, openUrl } = require("%scripts/onlineShop/url.nut")
let lottie = require("%scripts/utils/lottie.nut")
let { checkLegalRestrictions } = require("%scripts/items/itemRestrictions.nut")
let { showGuestEmailRegistration, needShowGuestEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")


const ITEM_SOON_EXPIRE_SEC = 14400
const ITEM_VERY_SOON_EXPIRE_SEC = 3600

local expireTypes = {
  SOON = { id = "soon", color = "@itemSoonExpireColor" }
  VERY_SOON = { id = "very_soon", color = "@red" }
}
::items_classes <- {}

::BaseItem <- class {
  id = ""
  static iType = itemType.UNKNOWN
  static defaultLocId = "unknown"
  static defaultIcon = "#ui/gameuiskin#items_silver_bg"
  static defaultIconStyle = null
  static typeIcon = "#ui/gameuiskin#item_type_placeholder.svg"
  static linkActionLocId = "mainmenu/btnBrowser"
  static linkActionIcon = ""
  static isPreferMarkupDescInTooltip = false
  static isDescTextBeforeDescDiv = true
  static itemExpiredLocId = "items/expired"
  static everyDayAwardPrefix = "every_day_award_"
  static includeInRecentItems = true
  static hasRecentItemConfirmMessageBox = true

  blkType = ""
  canBuy = false
  isInventoryItem = false
  allowBigPicture = true
  iconStyle = ""
  shopFilterMask = null

  uids = null //only for inventory items
  expiredTimeSec = 0 //to comapre with 0.001 * get_time_msec()
  expiredTimeAfterActivationH = 0
  isActivateBeforeExpired = false //Auto activate when time expired soon
  spentInSessionTimeMin = 0
  lastChangeTimestamp = 0
  tradeableTimestamp = 0

  amount = 1
  transferAmount = 0 //amount of items in transfer
  sellCountStep = 1

  // Empty string means no purchase feature.
  purchaseFeature = ""
  isDevItem = false
  isDisguised = false //used to override name, icon and some description for item.
  isHideInShop = false

  locId = null
  showBoosterInSeparateList = false

  link = ""
  static linkBigQueryKey = "item_shop"
  forceExternalBrowser = false

  // Zero means no limit.
  limitGlobal = 0
  limitPersonalTotal = 0
  limitPersonalAtTime = 0

  isToStringForDebug = true

  shouldAutoConsume = false //if true, should to have "consume" function
  forceShowRewardReceiving = false //in case, like autoConsume, when we need to notify player
  craftedFrom = ""

  maxAmount = -1 // -1 means no max item amount
  lottieAnimation = null

  restrictedInCountries = null

  constructor(blk, invBlk = null, slotData = null) {
    this.id = blk.getBlockName() || invBlk?.id || ""
    this.locId = blk?.locId
    this.blkType = blk?.type
    this.isInventoryItem = invBlk != null
    this.purchaseFeature = blk?.purchase_feature ?? ""
    this.isDevItem = !this.isInventoryItem && this.purchaseFeature == "devItemShop"
    this.canBuy = this.canBuy && !this.isInventoryItem && this.getCost(true) > ::zero_money
    this.isHideInShop = blk?.hideInShop ?? false
    this.iconStyle = blk?.iconStyle ?? this.id
    this.lottieAnimation = blk?.lottieAnimation
    this.link = blk?.link ?? ""
    this.forceExternalBrowser = blk?.forceExternalBrowser ?? false
    this.shouldAutoConsume = blk?.shouldAutoConsume ?? false
    this.restrictedInCountries = blk?.restrictedInCountries

    this.shopFilterMask = this.iType
    let types = blk % "additionalShopItemType"
    foreach (t in types)
      this.shopFilterMask = this.shopFilterMask | ::ItemsManager.getInventoryItemType(t)

    this.expiredTimeAfterActivationH = blk?.expiredTimeHAfterActivation ?? 0

    let expiredAt = blk?.expiredAt
      ? getTimestampFromStringUtc(blk.expiredAt) - ::get_charserver_time_sec() : null
    let invExpiredTime = invBlk?.expiredTime
    let expiredTime = (expiredAt != null && invExpiredTime != null)
      ? min(invExpiredTime, expiredAt) : expiredAt != null
        ? expiredAt : invExpiredTime

    this.expiredTimeSec = expiredTime != null ? expiredTime + 0.001 * get_time_msec() : 0

    if (this.isInventoryItem) {
      this.uids = slotData?.uids ?? []
      this.amount = slotData?.count ?? 1
    }
    else {
      this.sellCountStep = blk?.sell_count_step || 1
      this.limitGlobal = blk?.limitGlobal ?? 0
      this.limitPersonalTotal = blk?.limitPersonalTotal ?? 0
      this.limitPersonalAtTime = blk?.limitPersonalAtTime ?? 0
    }
  }

  getSeenId = @() this.id.tostring()

  function makeEmptyInventoryItem() {
    let res = clone this
    res.isInventoryItem = true
    res.uids = []
    res.amount = 0
    return res
  }

  function isEqual(item) {
    if (item.isInventoryItem != this.isInventoryItem || item.id != this.id)
      return false
    if (!this.isInventoryItem)
      return true

    foreach (uid in item.uids)
      if (this.uids.indexof(uid) != null)
        return true
    return false
  }

  function getLimitData() {
    return ::g_item_limits.getLimitDataByItemName(this.id)
  }

  function checkPurchaseFeature() {
    return this.purchaseFeature == "" || hasFeature(this.purchaseFeature)
  }

  function getDebugName() {
    let myClass = this.getclass()
    foreach (name, iClass in ::items_classes)
      if (myClass == iClass)
        return name
    return "BaseItem"
  }

  function _tostring() {
    return format("Item %s (id = %s)", this.getDebugName(), this.id.tostring())
  }

  function isCanBuy() {
    return this.canBuy && this.checkPurchaseFeature() && !this.isExpired()
  }

  function getCost(ignoreCanBuy = false) {
    if (this.isCanBuy() || ignoreCanBuy)
      return Cost(::wp_get_item_cost(this.id), ::wp_get_item_cost_gold(this.id)).multiply(this.getSellAmount())
    return Cost()
  }

  function getIcon(_addItemName = true) {
    if (this.lottieAnimation != null)
      return LayersIcon.getIconData(null, this.getLottieImage())
    return LayersIcon.getIconData(this.iconStyle + "_shop", this.defaultIcon, 1.0, this.defaultIconStyle)
  }

  function getSmallIconName() {
    return this.typeIcon
  }

  function getBigIcon() {
    return this.getIcon()
  }

  function getOpenedIcon() {
    return this.getIcon()
  }

  function getOpenedBigIcon() {
    return this.getBigIcon()
  }

  function setIcon(obj, params = {}) {
    if (!checkObj(obj))
      return

    let bigPicture = getTblValue("bigPicture", params, false)

    let addItemName = getTblValue("addItemName", params, true)
    let imageData = bigPicture ? this.getBigIcon() : this.getIcon(addItemName)
    if (!imageData)
      return

    let guiScene = obj.getScene()
    obj.doubleSize = bigPicture ? "yes" : "no"
    obj.wideSize = params?.wideSize ? "yes" : "no"
    guiScene.replaceContentFromText(obj, imageData, imageData.len(), null)
  }

  function getName(_colored = true) {
    local name = loc("item/" + this.id, loc("item/" + this.defaultLocId))
    if (this.locId != null)
      name = loc(this.locId, name)
    return name
  }

  function getNameWithCount(colored = true, count = 0) {
    local counttext = ""
    if (count > 1)
      counttext = colorize("activeTextColor", " x") + colorize("userlogColoredText", count)

    return this.getName(colored) + counttext
  }

  function getTypeName() {
    return loc("item/" + this.defaultLocId)
  }

  function getNameMarkup(count = 0, showTitle = true, hasPadding = false) {
    return handyman.renderCached("%gui/items/itemString.tpl", {
      title = showTitle ? colorize("activeTextColor", this.getName()) : null
      icon = this.getSmallIconName()
      tooltipId = ::g_tooltip.getIdItem(this.id, { isDisguised = this.isDisguised })
      count = count > 1 ? (colorize("activeTextColor", " x") + colorize("userlogColoredText", count)) : null
      hasPadding = hasPadding
    })
  }

  function getDescriptionTitle() {
    return this.getName()
  }

  function getDescriptionUnderTitle() {
    return ""
  }

  function getAmount() {
    return this.amount
  }

  function getSellAmount() {
    return this.sellCountStep
  }

  function getShortItemTypeDescription() {
    return loc("item/" + this.id + "/shortTypeDesc", loc("item/" + this.blkType + "/shortTypeDesc", ""))
  }

  function getItemTypeDescription(loc_params = {}) {
    local idText = ""
    if (this.locId != null) {
      idText = loc(this.locId, this.locId + "/typeDesc", loc_params)
      if (idText != "")
        return idText
    }

    idText = loc("item/" + this.id + "/typeDesc", "", loc_params)
    if (idText != "")
      return idText

    idText = loc("item/" + this.blkType + "/typeDesc", "", loc_params)
    if (idText != "")
      return idText

    return ""
  }

  function getDescription() {
    return loc("item/" + this.id + "/desc", "")
  }

  function getDescriptionUnderTable() { return "" }
  function getDescriptionAboveTable() { return "" }
  function getLongDescriptionMarkup(_params = null) { return "" }
  function getStopConditions() { return "" }

  function getLongDescription() { return this.getDescription() }

  function getShortDescription(colored = true) { return this.getName(colored) }
  getPrizeDescription = @(_count, _colored = true) null

  function isActive(...) { return false }

  shouldShowAmount = @(count) count > 1 || count == 0 || this.transferAmount > 0

  function getViewData(params = {}) {
    let openedPicture = getTblValue("openedPicture", params, false)
    let bigPicture = getTblValue("bigPicture", params, false)
    let addItemName = getTblValue("addItemName", params, true)
    let res = {
      layered_image = params?.overrideLayeredImage
        ?? (openedPicture ? (bigPicture ? this.getOpenedBigIcon() : this.getOpenedIcon()) : bigPicture ? this.getBigIcon() : this.getIcon(addItemName))
      enableBackground = getTblValue("enableBackground", params, true)
    }

    if (getTblValue("showTooltip", params, true))
      res.tooltipId <- this.isInventoryItem && this.uids && this.uids.len()
                       ? ::g_tooltip.getIdInventoryItem(this.uids[0])
                       : ::g_tooltip.getIdItem(this.id, { isDisguised = this.isDisguised })

    if (getTblValue("showPrice", params, true))
      res.price <- this.getCost().getTextAccordingToBalance()

    foreach (paramName, value in params)
      res[paramName] <- value

    let craftTimerText = params?.craftTimerText
    if ((this.hasCraftTimer() && (params?.hasCraftTimer ?? true)) || craftTimerText)
      res.craftTime <- craftTimerText ?? this.getCraftTimeTextShort()

    if (this.hasTimer() && getTblValue("hasTimer", params, true))
      res.expireTime <- this.getTimeLeftText()

    if (this.isRare() && (params?.showRarity ?? true))
      res.rarityColor <- this.getRarityColor()

    let expireType = this.getExpireType()
    if (expireType) {
      res.rarityColor <- expireType.color
      res.alarmIcon <- true
    }

    if (this.isActive())
      res.active <- true

    res.hasButton <- getTblValue("hasButton", params, true)
    res.onClick <- getTblValue("onClick", params, null)
    res.hasFocusBorder <- params?.hasFocusBorder ?? true

    if (getTblValue("contentIcon", params, true))
      res.contentIconData <- this.getContentIconData()

    return this.getSubstitutionViewData(res, params)
  }

  // Parameters that can be overridden by item substitution
  // have been took out in separate function getSubstitutionViewData
  function getSubstitutionViewData(res, params) {
    if (getTblValue("showAction", params, true)) {
      let mainActionData = params?.overrideMainActionData ?? this.getMainActionData(true, params)
      res.isInactive <- (params?.showButtonInactiveIfNeed ?? false)
        && (mainActionData?.isInactive ?? false)
      if (mainActionData && this.getLimitsCheckData().result) {
        res.modActionName <- mainActionData?.btnColoredName ?? mainActionData.btnName
        res.needShowActionButtonAlways <- mainActionData?.needShowActionButtonAlways ?? this.needShowActionButtonAlways(params)
        res.onItemAction <- mainActionData?.onItemAction
      }
    }

    let isSelfAmount = params?.count == null
    let amountVal = params?.count || this.getAmount()
    let additionalTextInAmmount = params?.shouldHideAdditionalAmmount ? ""
      : this.getAdditionalTextInAmmount()
    if ((!this.shouldAutoConsume || this.canOpenForGold())
      && (!u.isInteger(amountVal) || this.shouldShowAmount(amountVal))) {
      res.amount <- isSelfAmount && this.hasReachedMaxAmount()
        ? colorize("goodTextColor",
          loc("ui/parentheses/space", { text = amountVal + loc("ui/slash") + this.maxAmount }))
        : amountVal.tostring() + additionalTextInAmmount
      if (isSelfAmount && this.transferAmount > 0)
        res.isInTransfer <- true
    }
    if (getTblValue("showSellAmount", params, false)) {
      let sellAmount = this.getSellAmount()
      if (sellAmount > 1)
        res.amount <- sellAmount + additionalTextInAmmount
    }

    if (!res?.isItemLocked)
      res.isItemLocked <- this.isInventoryItem && !this.amount && !this.showAlwaysAsEnabledAndUnlocked()

    let boostEfficiency = this.getBoostEfficiency()
    if (params?.hasBoostEfficiency && boostEfficiency)
      res.boostEfficiency <- colorize(this.getAmount() > 0
        ? "activeTextColor"
        : "commonTextColor", loc("keysPlus") + boostEfficiency + loc("measureUnits/percent"))

    return res
  }

  function getBoostEfficiency() {
    return null
  }

  function getContentIconData() {
    return null
  }

  function hasLink() {
    return this.link != "" && hasFeature("AllowExternalLink")
  }

  function openLink() {
    if (!this.hasLink())
      return
    if (needShowGuestEmailRegistration()) {
      showGuestEmailRegistration()
      return
    }
    let validLink = validateLink(this.link)
    if (validLink)
      openUrl(validLink, this.forceExternalBrowser, false, this.linkBigQueryKey)
  }

  function _requestBuy(params = {}) {
    let blk = DataBlock()
    blk["name"] = this.id
    blk["count"] = getTblValue("count", params, this.getSellAmount())
    blk["cost"] = params.cost
    blk["costGold"] = params.costGold

    return ::char_send_blk("cln_buy_item", blk)
  }

  function _buy(cb, params = {}) {
    if (!this.isCanBuy() || !::check_balance_msgBox(this.getCost()))
      return false

    let item = this
    let onSuccessCb = function() {
      ::update_gamercards()
      item.forceRefreshLimits()
      if (cb)
        cb({
        success = true
        item = this
      })
      broadcastEvent("ItemBought", { item = item })
    }
    let onErrorCb = @(_res) item.forceRefreshLimits()

    let taskId = this._requestBuy(params)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccessCb, onErrorCb)
    return taskId >= 0
  }

  function buy(cb, handler = null, params = {}) {
    if (!this.isCanBuy() || !::check_balance_msgBox(this.getCost()))
      return false

    if (this.hasReachedMaxAmount()) {
      ::scene_msg_box("reached_max_amount", null, loc(this.getLocIdsList().reachedMaxAmount),
        [["cancel"]], "cancel")
      return false
    }

    let onCheck = Callback(@() this.onCheckLegalRestrictions(cb, handler, params), this)
    checkLegalRestrictions(this.getCountriesWithBuyRestrict(), onCheck)
    return true
  }

  onCheckLegalRestrictions = @(cb, handler, params) this.showBuyConfirm(cb, handler, params)

  function showBuyConfirm(cb, handler, params) {
    if (!handler?.isValid())
      handler = ::get_cur_base_gui_handler()

    let name = this.getName()
    let numItems = params?.amount ?? 1
    let cost = numItems == 1 ? this.getCost() : (Cost() + this.getCost()).multiply(numItems)
    let price = cost.getTextAccordingToBalance()
    let msgTextLocKey = numItems == 1
      ? "onlineShop/needMoneyQuestion"
      : "onlineShop/needMoneyQuestion/multiPurchase"
    let msgText = ::warningIfGold(
      loc(msgTextLocKey, { purchase = name, cost = price, amount = numItems }),
      cost)
    local item = this
    params["cost"] <- cost.wp
    params["costGold"] <- cost.gold
    handler.msgBox("need_money", msgText,
          [["purchase", @() item._buy(cb, params)],
          ["cancel", function() {} ]], "purchase")
  }

  function getBuyText(colored, short, locIdBuyText = "mainmenu/btnBuy", cost = null) {
    let res = loc(locIdBuyText)
    if (short)
      return res

    cost = cost ?? this.getCost()
    let costText = colored ? cost.getTextAccordingToBalance() : cost.getUncoloredText()
    return res + ((costText == "") ? "" : " (" + costText + ")")
  }

  function getMainActionData(isShort = false, _params = {}) {
    if (this.isCanBuy())
      return {
        btnName = this.getBuyText(false, isShort)
        btnColoredName = this.getBuyText(true, isShort)
        isInactive = this.hasReachedMaxAmount()
      }

    return null
  }

  function doMainAction(cb, handler, params = null) {
    return this.buy(cb, handler, params)
  }

  getActivateInfo    = @() ""
  getAltActionName   = @(_params = null) ""
  doAltAction        = @(_params = null) false

  getExpireDeltaSec  = @() (this.expiredTimeSec - get_time_msec() * 0.001).tointeger()
  isExpired          = @() this.expiredTimeSec != 0 && this.getExpireDeltaSec() < 0
  hasExpireTimer     = @() this.expiredTimeSec != 0
  hasTimer           = @() this.expiredTimeSec != 0
                           || (this.getCraftingItem()?.expiredTimeSec ?? 0) > 0
  getNoTradeableTimeLeft = @() max(0, this.tradeableTimestamp - ::get_charserver_time_sec())
  function getExpireType() {
    if (!this.hasTimer())
      return null
    let deltaSeconds = this.getExpireDeltaSec()
    return deltaSeconds > ITEM_SOON_EXPIRE_SEC ? null
      : deltaSeconds < ITEM_VERY_SOON_EXPIRE_SEC ? expireTypes.VERY_SOON
      : expireTypes.SOON
  }

  function canPreview() {
    return false
  }

  function doPreview() {
  }

  getTimeLeftText  = @() "\n".join([this.getExpireTimeTextShort(), this.getNoTradeableTimeTextShort()], true)

  onItemExpire     = @() ::ItemsManager.markInventoryUpdateDelayed()
  onTradeAllowed   = @() null

  function getExpireAfterActivationText(withTitle = true) {
    local res = ""
    if (!this.expiredTimeAfterActivationH)
      return res

    res = hoursToString(this.expiredTimeAfterActivationH, true, false, true)
    if (withTitle)
      res = loc("items/expireTimeAfterActivation") + loc("ui/colon") + colorize("activeTextColor", res)
    return res
  }

  function getExpireTimeTextShort() {
    if (this.expiredTimeSec <= 0)
      return ""
    let deltaSeconds = this.getExpireDeltaSec()
    if (deltaSeconds < 0) {
      if (this.isInventoryItem && this.amount > 0)
        this.onItemExpire()
      return loc(this.itemExpiredLocId)
    }
    let resStr = loc("icon/hourglass") + ::nbsp +
      ::stringReplace(hoursToString(secondsToHours(deltaSeconds), false, true, true), " ", ::nbsp)
    let expireTimeColor = this.getExpireType()?.color
    return expireTimeColor ? colorize(expireTimeColor, resStr) : resStr
  }

  function getCurExpireTimeText() {
    local res = ""
    let active = this.isActive()
    if (!active)
      res += this.getExpireAfterActivationText()

    let timeText = this.getExpireTimeTextShort()
    if (timeText != "") {
      let labelLocId = active ? "items/expireTimeLeft" : "items/expireTimeBeforeActivation"
      res += ((res != "") ? "\n" : "") + loc(labelLocId) + loc("ui/colon") +
        colorize("activeTextColor", timeText)
    }
    return res
  }

  function getNoTradeableTimeTextShort() {
    let seconds = this.getNoTradeableTimeLeft()
    if (seconds <= 0) {
      if (this.tradeableTimestamp > 0)
        this.onTradeAllowed()
      return ""
    }

    return loc("currency/gc/sign") + ::nbsp +
      ::stringReplace(hoursToString(secondsToHours(seconds), false, true, true), " ", ::nbsp)
  }

  function getTableData() {
    return null
  }

  function canStack(_item) {
    return false
  }

  function updateStackParams(_stackParams) {}

  function getContent() { return [] }
  function getContentNoRecursion() { return [] }

  function getStackName(_stackParams) {
    return this.getShortDescription()
  }

  function hasLimits() {
    return (this.limitGlobal > 0 || this.limitPersonalTotal > 0 || this.limitPersonalAtTime > 0) && !::ItemsManager.ignoreItemLimits
  }

  function forceRefreshLimits() {
    if (this.hasLimits())
      ::g_item_limits.requestLimitsForItem(this.id, true)
  }

  function getLimitsDescription() {
    if (this.isInventoryItem || !this.hasLimits())
      return ""

    let limitData = this.getLimitData()
    local locParams = null
    let textParts = []
    if (this.limitGlobal > 0) {
      locParams = {
        itemsLeft = colorize("activeTextColor", (this.limitGlobal - limitData.countGlobal))
      }
      textParts.append(loc("items/limitDescription/limitGlobal", locParams))
    }
    if (this.limitPersonalTotal > 0) {
      locParams = {
        itemsPurchased = colorize("activeTextColor", limitData.countPersonalTotal)
        itemsTotal = colorize("activeTextColor", this.limitPersonalTotal)
      }
      textParts.append(loc("items/limitDescription/limitPersonalTotal", locParams))
    }
    if (this.limitPersonalAtTime > 0 && limitData.countPersonalAtTime >= this.limitPersonalAtTime)
      textParts.append(loc("items/limitDescription/limitPersonalAtTime"))
    return "\n".join(textParts, true)
  }

  function getLimitsCheckData() {
    let data = {
      result = true
      reason = ""
    }
    if (!this.hasLimits())
      return data

    let limitData = this.getLimitData()
    foreach (name in ["Global", "PersonalTotal", "PersonalAtTime"]) {
      let limitName = format("limit%s", name)
      let limitValue = getTblValue(limitName, this, 0)
      let countName = format("count%s", name)
      let countValue = getTblValue(countName, limitData, 0)
      if (0 < limitValue && limitValue <= countValue) {
        data.result = false
        data.reason = loc(format("items/limitDescription/maxedOut/limit%s", name))
        break
      }
    }
    return data
  }

  function getGlobalLimitText() {
    if (this.limitGlobal == 0)
      return ""

    let limitData = this.getLimitData()
    if (limitData.countGlobal == -1)
      return ""

    let leftCount = this.limitGlobal - limitData.countGlobal
    let limitText = format("%s/%s", leftCount.tostring(), this.limitGlobal.tostring())
    let locParams = {
      ticketsLeft = colorize("activeTextColor", limitText)
    }
    return loc("items/limitDescription/globalLimitText", locParams)
  }

  function isForEvent(_checkEconomicName = "") {
    return false
  }

  function setDisguise(shouldDisguise) {
    this.isDisguised = shouldDisguise
    this.allowBigPicture = false
  }

  getDescTimers               = @() []
  makeDescTimerData           = @(params) { id = "", getText = @() "", needTimer = @() true }.__update(params)

  getCreationCaption          = @() loc("mainmenu/itemCreated/title")
  getDissasembledCaption      = @() loc("mainmenu/itemDisassembled/title")
  getOpeningAnimId            = @() "DEFAULT"

  isRare                      = @() false
  getRarity                   = @() 0
  getRarityColor              = @() ""
  getRelatedRecipes           = @() [] //recipes with this item in materials
  getMyRecipes                = @() [] //recipes with this item in result
  needShowActionButtonAlways  = @(_params) false

  getMaxRecipesToShow         = @() 0 //if 0, all recipes will be shown.
  getDescRecipeListHeader     = @(_showAmount, _totalAmount, _isMultipleExtraItems) ""
  getCantUseLocId             = @() ""
  static getEmptyConfirmMessageData = @() { text = "", headerRecipeMarkup = "", needRecipeMarkup = false }
  getConfirmMessageData      = @(_recipe) this.getEmptyConfirmMessageData()

  getCraftingItem = @() null
  isCrafting = @() !!this.getCraftingItem()
  hasCraftTimer = @() this.isCrafting()
  getCraftTimeTextShort = @() ""
  getCraftTimeLeft = @() - 1
  getCraftTimeText = @() ""
  isCraftResult = @() false
  getCraftResultItem = @() null
  hasCraftResult = @() !!this.getCraftResultItem()
  isHiddenItem = @() !this.isEnabled() || this.isCraftResult() || this.shouldAutoConsume
  getAdditionalTextInAmmount = @(_needColorize = true, _showOnlyIcon = false) ""
  cancelCrafting = @(...) false
  getRewardListLocId = @() "mainmenu/rewardsList"
  getItemsListLocId = @() "mainmenu/itemsList"
  hasReachedMaxAmount = @() this.isInventoryItem && this.maxAmount >= 0 ? this.getAmount() >= this.maxAmount : false
  isEnabled = @() true
  getContentItem = @() null
  needShowRewardWnd = @() true
  skipRoulette = @() true
  needOfferBuyAtExpiration = @() false
  isVisibleInWorkshopOnly = @() false
  getIconName = @() this.getSmallIconName()
  canCraftOnlyInCraftTree = @() false
  getLocIdsList = @() { reachedMaxAmount = "item/reached_max_amount" }
  consume = @(_cb, _params) false
  showAllowableRecipesOnly = @() false
  hasUsableRecipe = @() false
  canRecraftFromRewardWnd = @() false
  canOpenForGold = @() false
  getTopPrize = @() null
  getLottieImage = @(width = "1@itemWidth") this.lottieAnimation != null
    ? lottie({ image = this.lottieAnimation, width })
    : null
  isEveryDayAward = @() this.id.tostring().split(this.everyDayAwardPrefix).len() > 1
  showAlwaysAsEnabledAndUnlocked = @() false
  getCountriesWithBuyRestrict = @() (this.restrictedInCountries ?? "") != "" ? this.restrictedInCountries.split(",") : []
  getOpeningCaption = @() loc("mainmenu/trophyReward/title")
}
