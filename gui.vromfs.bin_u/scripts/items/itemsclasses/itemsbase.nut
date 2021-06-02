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


local { hoursToString, secondsToHours, getTimestampFromStringUtc } = require("scripts/time.nut")
local { validateLink, openUrl } = require("scripts/onlineShop/url.nut")
local lottie = require("scripts/utils/lottie.nut")

::items_classes <- {}

class ::BaseItem
{
  id = ""
  static iType = itemType.UNKNOWN
  static defaultLocId = "unknown"
  static defaultIcon = "#ui/gameuiskin#items_silver_bg"
  static defaultIconStyle = null
  static typeIcon = "#ui/gameuiskin#item_type_placeholder"
  static linkActionLocId = "mainmenu/btnBrowser"
  static linkActionIcon = ""
  static isPreferMarkupDescInTooltip = false
  static isDescTextBeforeDescDiv = true
  static itemExpiredLocId = "items/expired"

  static includeInRecentItems = true
  static hasRecentItemConfirmMessageBox = true

  blkType = ""
  canBuy = false
  isInventoryItem = false
  allowBigPicture = true
  iconStyle = ""
  shopFilterMask = null

  uids = null //only for inventory items
  expiredTimeSec = 0 //to comapre with 0.001 * ::dagor.getCurTime()
  expiredTimeAfterActivationH = 0
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
  craftedFrom = ""

  maxAmount = -1 // -1 means no max item amount
  lottieAnimation = null


  constructor(blk, invBlk = null, slotData = null)
  {
    id = blk.getBlockName() || invBlk?.id || ""
    locId = blk?.locId
    blkType = blk?.type
    isInventoryItem = invBlk != null
    purchaseFeature = blk?.purchase_feature ?? ""
    isDevItem = !isInventoryItem && purchaseFeature == "devItemShop"
    canBuy = canBuy && !isInventoryItem && getCost(true) > ::zero_money
    isHideInShop = blk?.hideInShop ?? false
    iconStyle = blk?.iconStyle ?? id
    lottieAnimation = blk?.lottieAnimation
    link = blk?.link ?? ""
    forceExternalBrowser = blk?.forceExternalBrowser ?? false
    shouldAutoConsume = blk?.shouldAutoConsume ?? false

    shopFilterMask = iType
    local types = blk % "additionalShopItemType"
    foreach(t in types)
      shopFilterMask = shopFilterMask | ::ItemsManager.getInventoryItemType(t)

    expiredTimeAfterActivationH = blk?.expiredTimeHAfterActivation ?? 0

    local expiredAt = blk?.expiredAt
      ? getTimestampFromStringUtc(blk.expiredAt) - ::get_charserver_time_sec() : null
    local invExpiredTime = invBlk?.expiredTime
    local expiredTime = (expiredAt != null && invExpiredTime != null)
      ? ::min(invExpiredTime, expiredAt) : expiredAt != null
        ? expiredAt : invExpiredTime

    expiredTimeSec = expiredTime != null ? expiredTime + 0.001 * ::dagor.getCurTime() : 0

    if (isInventoryItem)
    {
      uids = slotData?.uids ?? []
      amount = slotData?.count ?? 1
    } else
    {
      sellCountStep = blk?.sell_count_step || 1
      limitGlobal = blk?.limitGlobal ?? 0
      limitPersonalTotal = blk?.limitPersonalTotal ?? 0
      limitPersonalAtTime = blk?.limitPersonalAtTime ?? 0
    }
  }

  getSeenId = @() id.tostring()

  function makeEmptyInventoryItem()
  {
    local res = clone this
    res.isInventoryItem = true
    res.uids = []
    res.amount = 0
    return res
  }

  function isEqual(item)
  {
    if (item.isInventoryItem != isInventoryItem || item.id != id)
      return false
    if (!isInventoryItem)
      return true

    foreach(uid in item.uids)
      if (uids.indexof(uid) != null)
        return true
    return false
  }

  function getLimitData()
  {
    return ::g_item_limits.getLimitDataByItemName(id)
  }

  function checkPurchaseFeature()
  {
    return purchaseFeature == "" || ::has_feature(purchaseFeature)
  }

  function getDebugName()
  {
    local myClass = getclass()
    foreach(name, iClass in ::items_classes)
      if (myClass == iClass)
        return name
    return "BaseItem"
  }

  function _tostring()
  {
    return ::format("Item %s (id = %s)", getDebugName(), id.tostring())
  }

  function isCanBuy()
  {
    return canBuy && checkPurchaseFeature()
  }

  function getCost(ignoreCanBuy = false)
  {
    if (isCanBuy() || ignoreCanBuy)
      return ::Cost(::wp_get_item_cost(id), ::wp_get_item_cost_gold(id)).multiply(getSellAmount())
    return ::Cost()
  }

  function getIcon(addItemName = true)
  {
    if (lottieAnimation != null)
      return ::LayersIcon.getIconData(null, getLottieImage())
    return ::LayersIcon.getIconData(iconStyle + "_shop", defaultIcon, 1.0, defaultIconStyle)
  }

  function getSmallIconName()
  {
    return typeIcon
  }

  function getBigIcon()
  {
    return getIcon()
  }

  function getOpenedIcon()
  {
    return getIcon()
  }

  function getOpenedBigIcon()
  {
    return getBigIcon()
  }

  function setIcon(obj, params = {})
  {
    if (!::checkObj(obj))
      return

    local bigPicture = ::getTblValue("bigPicture", params, false)

    local addItemName = ::getTblValue("addItemName", params, true)
    local imageData = bigPicture? getBigIcon() : getIcon(addItemName)
    if (!imageData)
      return

    local guiScene = obj.getScene()
    obj.doubleSize = bigPicture? "yes" : "no"
    obj.wideSize = params?.wideSize ? "yes" : "no"
    guiScene.replaceContentFromText(obj, imageData, imageData.len(), null)
  }

  function getName(colored = true)
  {
    local name = ::loc("item/" + id, ::loc("item/" + defaultLocId))
    if (locId != null)
      name = ::loc(locId, name)
    return name
  }

  function getNameWithCount(colored = true, count = 0)
  {
    local counttext = ""
    if (count > 1)
      counttext = colorize("activeTextColor", " x") + colorize("userlogColoredText", count)

    return getName(colored) + counttext
  }

  function getTypeName()
  {
    return ::loc("item/" + defaultLocId)
  }

  function getNameMarkup(count = 0, showTitle = true, hasPadding = false)
  {
    return ::handyman.renderCached("gui/items/itemString", {
      title = showTitle? colorize("activeTextColor",getName()) : null
      icon = getSmallIconName()
      tooltipId = ::g_tooltip.getIdItem(id, { isDisguised = isDisguised })
      count = count > 1? (colorize("activeTextColor", " x") + colorize("userlogColoredText", count)) : null
      hasPadding = hasPadding
    })
  }

  function getDescriptionTitle()
  {
    return getName()
  }

  function getDescriptionUnderTitle()
  {
    return ""
  }

  function getAmount()
  {
    return amount
  }

  function getSellAmount()
  {
    return sellCountStep
  }

  function getShortItemTypeDescription()
  {
    return ::loc("item/" + id + "/shortTypeDesc", ::loc("item/" + blkType + "/shortTypeDesc", ""))
  }

  function getItemTypeDescription(loc_params = {})
  {
    local idText = ""
    if (locId != null)
    {
      idText = ::loc(locId, locId + "/typeDesc", loc_params)
      if (idText != "")
        return idText
    }

    idText = ::loc("item/" + id + "/typeDesc", "", loc_params)
    if (idText != "")
      return idText

    idText = ::loc("item/" + blkType + "/typeDesc", "", loc_params)
    if (idText != "")
      return idText

    return ""
  }

  function getDescription()
  {
    return ::loc("item/" + id + "/desc", "")
  }

  function getDescriptionUnderTable() { return "" }
  function getDescriptionAboveTable() { return "" }
  function getLongDescriptionMarkup(params = null) { return "" }
  function getStopConditions() { return "" }

  function getLongDescription() { return getDescription() }

  function getShortDescription(colored = true) { return getName(colored) }
  getPrizeDescription = @(count) null

  function isActive(...) { return false }

  shouldShowAmount = @(count) count > 1 || count == 0 || transferAmount > 0

  function getViewData(params = {})
  {
    local openedPicture = ::getTblValue("openedPicture", params, false)
    local bigPicture = ::getTblValue("bigPicture", params, false)
    local addItemName = ::getTblValue("addItemName", params, true)
    local res = {
      layered_image = params?.overrideLayeredImage
        ?? (openedPicture? (bigPicture? getOpenedBigIcon() : getOpenedIcon()) : bigPicture? getBigIcon() : getIcon(addItemName))
      enableBackground = ::getTblValue("enableBackground", params, true)
    }

    if (::getTblValue("showTooltip", params, true))
      res.tooltipId <- isInventoryItem && uids && uids.len()
                       ? ::g_tooltip.getIdInventoryItem(uids[0])
                       : ::g_tooltip.getIdItem(id, { isDisguised = isDisguised })

    if (::getTblValue("showPrice", params, true))
      res.price <- getCost().getTextAccordingToBalance()

    foreach(paramName, value in params)
      res[paramName] <- value

    local craftTimerText = params?.craftTimerText
    if ((hasCraftTimer() && (params?.hasCraftTimer ?? true)) || craftTimerText)
      res.craftTime <- craftTimerText ?? getCraftTimeTextShort()

    if (hasTimer() && ::getTblValue("hasTimer", params, true))
      res.expireTime <- getTimeLeftText()

    if (isRare() && (params?.showRarity ?? true))
      res.rarityColor <- getRarityColor()

    if (isActive())
      res.active <- true

    res.hasButton <- ::getTblValue("hasButton", params, true)
    res.onClick <- ::getTblValue("onClick", params, null)
    res.hasFocusBorder <- params?.hasFocusBorder ?? true

    if (::getTblValue("contentIcon", params, true))
      res.contentIconData <- getContentIconData()

    return getSubstitutionViewData(res, params)
  }

  // Parameters that can be overridden by item substitution
  // have been took out in separate function getSubstitutionViewData
  function getSubstitutionViewData(res, params)
  {
    if (::getTblValue("showAction", params, true))
    {
      local mainActionData = params?.overrideMainActionData ?? getMainActionData(true, params)
      res.isInactive <- (params?.showButtonInactiveIfNeed ?? false)
        && (mainActionData?.isInactive ?? false)
      if (mainActionData && getLimitsCheckData().result)
      {
        res.modActionName <- mainActionData?.btnColoredName ?? mainActionData.btnName
        res.needShowActionButtonAlways <- mainActionData?.needShowActionButtonAlways ?? needShowActionButtonAlways(params)
      }
    }

    local isSelfAmount = params?.count == null
    local amountVal = params?.count || getAmount()
    local additionalTextInAmmount = params?.shouldHideAdditionalAmmount ? ""
      : getAdditionalTextInAmmount()
    if (!shouldAutoConsume && (!::u.isInteger(amountVal) || shouldShowAmount(amountVal)))
    {
      res.amount <- isSelfAmount && hasReachedMaxAmount()
        ? ::colorize("goodTextColor",
          ::loc("ui/parentheses/space", {text = amountVal + ::loc("ui/slash") + maxAmount}))
        : amountVal.tostring() + additionalTextInAmmount
      if (isSelfAmount && transferAmount > 0)
        res.isInTransfer <- true
    }
    if (::getTblValue("showSellAmount", params, false))
    {
      local sellAmount = getSellAmount()
      if (sellAmount > 1)
        res.amount <- sellAmount + additionalTextInAmmount
    }

    if (!res?.isItemLocked)
      res.isItemLocked <- isInventoryItem && !amount

    local boostEfficiency = getBoostEfficiency()
    if(params?.hasBoostEfficiency && boostEfficiency)
      res.boostEfficiency <- ::colorize(getAmount() > 0
        ? "activeTextColor"
        : "commonTextColor", ::loc("keysPlus") + boostEfficiency + ::loc("measureUnits/percent"))

    return res
  }

  function getBoostEfficiency()
  {
    return null
  }

  function getContentIconData()
  {
    return null
  }

  function hasLink()
  {
    return link != "" && ::has_feature("AllowExternalLink")
  }

  function openLink()
  {
    if (!hasLink())
      return
    local validLink = validateLink(link)
    if (validLink)
      openUrl(validLink, forceExternalBrowser, false, linkBigQueryKey)
  }

  function _requestBuy(params = {})
  {
    local blk = ::DataBlock()
    blk["name"] = id
    blk["count"] = ::getTblValue("count", params, getSellAmount())
    blk["cost"] = params.cost
    blk["costGold"] = params.costGold

    return ::char_send_blk("cln_buy_item", blk)
  }

  function _buy(cb, params = {})
  {
    if (!isCanBuy() || !check_balance_msgBox(getCost()))
      return false

    local item = this
    local onSuccessCb = (@(cb, item) function() {
      ::update_gamercards()
      item.forceRefreshLimits()
      if (cb) cb({
        success = true
        item = this
      })
      ::broadcastEvent("ItemBought", { item = item })
    })(cb, item)
    local onErrorCb = (@(item) function(res) { item.forceRefreshLimits() })(item)

    local taskId = _requestBuy(params)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccessCb, onErrorCb)
    return taskId >= 0
  }

  function buy(cb, handler = null, params = {})
  {
    if (!isCanBuy() || !check_balance_msgBox(getCost()))
      return false

    if (hasReachedMaxAmount())
    {
      ::scene_msg_box("reached_max_amount", null, ::loc(getLocIdsList().reachedMaxAmount),
        [["cancel"]], "cancel")
      return false
    }

    handler = handler || ::get_cur_base_gui_handler()

    local name = getName()
    local cost = getCost()
    local price = cost.getTextAccordingToBalance()
    local msgText = ::warningIfGold(
      ::loc("onlineShop/needMoneyQuestion",{purchase = name, cost = price }),
      cost)
    local item = this
    params["cost"] <- cost.wp
    params["costGold"] <- cost.gold
    handler.msgBox("need_money", msgText,
          [["purchase", (@(item, cb, params) function() { item._buy(cb, params) })(item, cb, params) ],
          ["cancel", function() {} ]], "purchase")

    return true
  }

  function getBuyText(colored, short, locIdBuyText = "mainmenu/btnBuy", cost = null)
  {
    local res = ::loc(locIdBuyText)
    if (short)
      return res

    cost = cost ?? getCost()
    local costText = colored? cost.getTextAccordingToBalance() : cost.getUncoloredText()
    return res + ((costText == "")? "" : " (" + costText + ")")
  }

  function getMainActionData(isShort = false, params = {})
  {
    if (isCanBuy())
      return {
        btnName = getBuyText(false, isShort)
        btnColoredName = getBuyText(true, isShort)
        isInactive = hasReachedMaxAmount()
      }

    return null
  }

  function doMainAction(cb, handler, params = null)
  {
    return buy(cb, handler, params)
  }

  getActivateInfo    = @() ""
  getAltActionName   = @() ""
  doAltAction        = @(params = null) false

  isExpired          = @() expiredTimeSec != 0 && (expiredTimeSec - ::dagor.getCurTime() * 0.001) < 0
  hasExpireTimer     = @() expiredTimeSec != 0
  hasTimer           = @() expiredTimeSec != 0
                           || (getCraftingItem()?.expiredTimeSec ?? 0) > 0
  getNoTradeableTimeLeft = @() ::max(0, tradeableTimestamp - ::get_charserver_time_sec())

  function canPreview()
  {
    return false
  }

  function doPreview()
  {
  }

  getTimeLeftText  = @() ::g_string.implode([getExpireTimeTextShort(), getNoTradeableTimeTextShort()], "\n")

  onItemExpire     = @() ::ItemsManager.markInventoryUpdateDelayed()
  onTradeAllowed   = @() null

  function getExpireAfterActivationText(withTitle = true)
  {
    local res = ""
    if (!expiredTimeAfterActivationH)
      return res

    res = hoursToString(expiredTimeAfterActivationH, true, false, true)
    if (withTitle)
      res = ::loc("items/expireTimeAfterActivation") + ::loc("ui/colon") + ::colorize("activeTextColor", res)
    return res
  }

  function getExpireTimeTextShort()
  {
    if (expiredTimeSec <= 0)
      return ""
    local curSeconds = ::dagor.getCurTime() * 0.001
    local deltaSeconds = (expiredTimeSec - curSeconds).tointeger()
    if (deltaSeconds < 0)
    {
      if (isInventoryItem && amount > 0)
        onItemExpire()
      return ::loc(itemExpiredLocId)
    }
    return ::loc("icon/hourglass") + ::nbsp +
      ::stringReplace(hoursToString(secondsToHours(deltaSeconds), false, true, true), " ", ::nbsp)
  }

  function getCurExpireTimeText()
  {
    local res = ""
    local active = isActive()
    if (!active)
      res += getExpireAfterActivationText()

    local timeText = getExpireTimeTextShort()
    if (timeText != "")
    {
      local labelLocId = active ? "items/expireTimeLeft" : "items/expireTimeBeforeActivation"
      res += ((res!="") ? "\n" : "") + ::loc(labelLocId) + ::loc("ui/colon") +
        ::colorize("activeTextColor", timeText)
    }
    return res
  }

  function getNoTradeableTimeTextShort()
  {
    local seconds = getNoTradeableTimeLeft()
    if (seconds <= 0)
    {
      if (tradeableTimestamp > 0)
        onTradeAllowed()
      return ""
    }

    return ::loc("currency/gc/sign") + ::nbsp +
      ::stringReplace(hoursToString(secondsToHours(seconds), false, true, true), " ", ::nbsp)
  }

  function getTableData()
  {
    return null
  }

  function canStack(item)
  {
    return false
  }

  function updateStackParams(stackParams) {}

  function getContent() { return [] }
  function getContentNoRecursion() { return [] }

  function getStackName(stackParams)
  {
    return getShortDescription()
  }

  function hasLimits()
  {
    return (limitGlobal > 0 || limitPersonalTotal > 0 || limitPersonalAtTime > 0) && !::ItemsManager.ignoreItemLimits
  }

  function forceRefreshLimits()
  {
    if (hasLimits())
      ::g_item_limits.requestLimitsForItem(id, true)
  }

  function getLimitsDescription()
  {
    if (isInventoryItem || !hasLimits())
      return ""

    local limitData = getLimitData()
    local locParams = null
    local textParts = []
    if (limitGlobal > 0)
    {
      locParams = {
        itemsLeft = ::colorize("activeTextColor", (limitGlobal - limitData.countGlobal))
      }
      textParts.append(::loc("items/limitDescription/limitGlobal", locParams))
    }
    if (limitPersonalTotal > 0)
    {
      locParams = {
        itemsPurchased = ::colorize("activeTextColor", limitData.countPersonalTotal)
        itemsTotal = ::colorize("activeTextColor", limitPersonalTotal)
      }
      textParts.append(::loc("items/limitDescription/limitPersonalTotal", locParams))
    }
    if (limitPersonalAtTime > 0 && limitData.countPersonalAtTime >= limitPersonalAtTime)
      textParts.append(::loc("items/limitDescription/limitPersonalAtTime"))
    return ::g_string.implode(textParts, "\n")
  }

  function getLimitsCheckData()
  {
    local data = {
      result = true
      reason = ""
    }
    if (!hasLimits())
      return data

    local limitData = getLimitData()
    foreach (name in ["Global", "PersonalTotal", "PersonalAtTime"])
    {
      local limitName = ::format("limit%s", name)
      local limitValue = ::getTblValue(limitName, this, 0)
      local countName = ::format("count%s", name)
      local countValue = ::getTblValue(countName, limitData, 0)
      if (0 < limitValue && limitValue <= countValue)
      {
        data.result = false
        data.reason = ::loc(::format("items/limitDescription/maxedOut/limit%s", name))
        break
      }
    }
    return data
  }

  function getGlobalLimitText()
  {
    if (limitGlobal == 0)
      return ""

    local limitData = getLimitData()
    if (limitData.countGlobal == -1)
      return ""

    local leftCount = limitGlobal - limitData.countGlobal
    local limitText = ::format("%s/%s", leftCount.tostring(), limitGlobal.tostring())
    local locParams = {
      ticketsLeft = ::colorize("activeTextColor", limitText)
    }
    return ::loc("items/limitDescription/globalLimitText", locParams)
  }

  function isForEvent(checkEconomicName = "")
  {
    return false
  }

  function setDisguise(shouldDisguise)
  {
    isDisguised = shouldDisguise
    allowBigPicture = false
  }

  getDescTimers               = @() []
  makeDescTimerData           = @(params) { id = "", getText = @() "", needTimer = @() true }.__update(params)

  getCreationCaption          = @() ::loc("mainmenu/itemCreated/title")
  getOpeningAnimId            = @() "DEFAULT"

  isRare                      = @() false
  getRarity                   = @() 0
  getRarityColor              = @() ""
  getRelatedRecipes           = @() [] //recipes with this item in materials
  getMyRecipes                = @() [] //recipes with this item in result
  needShowActionButtonAlways  = @(params) false

  getMaxRecipesToShow         = @() 0 //if 0, all recipes will be shown.
  getDescRecipeListHeader     = @(showAmount, totalAmount, isMultipleExtraItems) ""
  getCantUseLocId             = @() ""
  static getEmptyConfirmMessageData = @() { text = "", headerRecipeMarkup = "", needRecipeMarkup = false }
  getConfirmMessageData      = @(recipe) getEmptyConfirmMessageData()

  getCraftingItem = @() null
  isCrafting = @() !!getCraftingItem()
  hasCraftTimer = @() isCrafting()
  getCraftTimeTextShort = @() ""
  getCraftTimeText = @() ""
  isCraftResult = @() false
  getCraftResultItem = @() null
  hasCraftResult = @() !!getCraftResultItem()
  isHiddenItem = @() !isEnabled() || isCraftResult() || shouldAutoConsume
  getAdditionalTextInAmmount = @(needColorize = true, showOnlyIcon = false) ""
  cancelCrafting = @(...) false
  getRewardListLocId = @() "mainmenu/rewardsList"
  getItemsListLocId = @() "mainmenu/itemsList"
  hasReachedMaxAmount = @() isInventoryItem && maxAmount >= 0 ? getAmount() >= maxAmount : false
  isEnabled = @() true
  getContentItem = @() null
  needShowRewardWnd = @() true
  skipRoulette = @() true
  needOfferBuyAtExpiration = @() false
  isVisibleInWorkshopOnly = @() false
  getIconName = @() getSmallIconName()
  canCraftOnlyInCraftTree = @() false
  getLocIdsList = @() { reachedMaxAmount = "item/reached_max_amount" }
  consume = @(cb, params) false
  showAllowableRecipesOnly = @() false
  canRecraftFromRewardWnd = @() false
  canOpenForGold = @() false
  getTopPrize = @() null
  getLottieImage = @(width = "1@itemWidth") lottieAnimation != null
    ? lottie({ image = lottieAnimation, width })
    : null
}
