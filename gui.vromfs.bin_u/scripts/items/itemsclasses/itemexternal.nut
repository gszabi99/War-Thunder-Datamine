local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local ItemGenerators = require("scripts/items/itemsClasses/itemGenerators.nut")
local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")
local guidParser = require("scripts/guidParser.nut")
local itemRarity = require("scripts/items/itemRarity.nut")
local time = require("scripts/time.nut")
local chooseAmountWnd = require("scripts/wndLib/chooseAmountWnd.nut")
local recipesListWnd = require("scripts/items/listPopupWnd/recipesListWnd.nut")
local itemTransfer = require("scripts/items/itemsTransfer.nut")
local { getMarkingPresetsById, getCustomLocalizationPresets,
  getEffectOnOpenChestPresetById } = require("scripts/items/workshop/workshop.nut")

local emptyBlk = ::DataBlock()

local defaultLocIdsList = {
  assemble                              = "item/assemble"
  disassemble                           = "item/disassemble"
  recipes                               = "item/recipes"
  descReceipesListHeaderPrefix          = ""
  msgBoxCantUse                         = "msgBox/assembleItem/cant"
  msgBoxConfirm                         = ""
  msgBoxConfirmWhithItemName            = "msgBox/assembleItem/confirm"
  msgBoxConfirmWhithItemNameDisassemble = "msgBox/disassembleItem/confirmWhithItemName"
  craftCountdown                        = "items/craft_process/countdown"
  header                                = "item/create_header"
  craftingIconInAmmount                 = "icon/gear"
  craftResultIconInAmmount              = "icon/chest2"
  tryCreateRecipes                      = "item/try_create_recipes"
  createRecipes                         = "item/create_recipes"
  cancelTitle                           = ""
  reachedMaxAmount                      = "item/reached_max_amount"
  inventoryErrorPrefix                  = "inventoryError/"
  maxAmountIcon                         = "check_mark/green"
  reUseItemLocId                        = "item/consume/again"
}

local ItemExternal = class extends ::BaseItem
{
  static defaultLocId = ""
  static combinedNameLocId = null
  static descHeaderLocId = ""
  static openingCaptionLocId = "mainmenu/itemConsumed/title"
  static linkActionLocId = "msgbox/btn_find_on_marketplace"
  static linkActionIcon = "#ui/gameuiskin#gc.svg"
  static userlogOpenLoc = "coupon_exchanged"
  static linkBigQueryKey = "marketplace_item"
  static isPreferMarkupDescInTooltip = true
  static isDescTextBeforeDescDiv = false
  static hasRecentItemConfirmMessageBox = false
  static descReceipesListHeaderPrefix = "item/requires/"
  static descReceipesListWithCurQuantities = true
  static expireCountdownColor = "badTextColor"
  static expireCountdownLocId = "items/expireDate"
  static craftColor = "goodTextColor"
  static craftFinishedLocId = "items/craft_process/finished"

  canBuy = true

  rarity = null
  expireTimestamp = -1

  itemDef = null
  metaBlk = null

  amountByUids = null //{ <uid> = <amount> }, need for recipe materials
  requirement = null

  aditionalConfirmationMsg = null
  locIdsList = null
  substitutionItemData = []

  constructor(itemDefDesc, itemDesc = null, slotData = null)
  {
    base.constructor(emptyBlk)

    itemDef = itemDefDesc
    id = itemDef.itemdefid
    blkType = itemDefDesc?.tags?.type ?? ""
    maxAmount = (itemDefDesc?.tags?.maxCount ?? -1).tointeger()
    requirement = itemDefDesc?.tags?.showWithFeature
    updateSubstitutionItemDataOnce()

    aditionalConfirmationMsg = {}
    local confirmationActions = itemDefDesc?.tags ? (itemDefDesc.tags % "confirmationAction") : []
    if (confirmationActions.len())
    {
       local confirmationMsg = itemDefDesc.tags % "confirmationMsg"
       foreach (idx, action in confirmationActions)
         aditionalConfirmationMsg[action] <- confirmationMsg?[idx] ?? ""
    }
    rarity = itemRarity.get(itemDef?.item_quality, itemDef?.name_color)
    shouldAutoConsume = !!itemDefDesc?.tags?.autoConsume || canOpenForGold()

    link = inventoryClient.getMarketplaceItemUrl(id, itemDesc?.itemid) || ""
    forceExternalBrowser = true

    if (itemDesc)
    {
      isInventoryItem = true
      amount = 0
      uids = []
      amountByUids = {}
      if ("itemid" in itemDesc)
        addUid(itemDesc.itemid, itemDesc.quantity)
      lastChangeTimestamp = time.getTimestampFromIso8601(itemDesc?.timestamp)
      tradeableTimestamp = getTradebleTimestamp(itemDesc)
      craftedFrom = itemDesc?.craftedFrom ?? ""
    }

    expireTimestamp = getExpireTimestamp(itemDefDesc, itemDesc)
    if (expireTimestamp != -1)
      expiredTimeSec = (::dagor.getCurTime() * 0.001) + (expireTimestamp - ::get_charserver_time_sec())

    local meta = getTblValue("meta", itemDef)
    if (meta && meta.len()) {
      metaBlk = ::DataBlock()
      if (!metaBlk.loadFromText(meta, meta.len())) {
        metaBlk = null
      }
    }

    canBuy = !isInventoryItem && checkPurchaseFeature() && ::has_feature("PurchaseMarketItemsForGold")

    addResources()

    updateShopFilterMask()
  }

  function getTradebleTimestamp(itemDesc)
  {
    if (!::has_feature("Marketplace"))
      return 0
    local res = ::to_integer_safe(itemDesc?.tradable_after_timestamp || 0)
    return res > ::get_charserver_time_sec() ? res : 0
  }

  function updateShopFilterMask()
  {
    shopFilterMask = iType
  }

  function tryAddItem(itemDefDesc, itemDesc)
  {
    if (id != itemDefDesc.itemdefid
        || expireTimestamp != getExpireTimestamp(itemDefDesc, itemDesc)
        || tradeableTimestamp != getTradebleTimestamp(itemDesc))
      return false
    addUid(itemDesc.itemid, itemDesc.quantity)
    lastChangeTimestamp = ::max(lastChangeTimestamp, time.getTimestampFromIso8601(itemDesc?.timestamp))
    return true
  }

  function addUid(uid, count)
  {
    uids.append(uid)
    amountByUids[uid] <- count
    amount += count
  }

  onItemExpire     = @() ::ItemsManager.refreshExtInventory()
  onTradeAllowed   = @() ::ItemsManager.markInventoryUpdateDelayed()

  function getTimestampfromString(str) {
    if (str == "")
      return -1

    local res = to_integer_safe(str, -1, false)
    if (res < 0)
      res = time.getTimestampFromIso8601(str) //compatibility with old inventory version
    return res
  }

  function getExpireTimestamp(itemDefDesc, itemDesc)
  {
    local tShop = getTimestampfromString(itemDefDesc?.expireAt ?? "")
    local tInv  = getTimestampfromString(itemDesc?.expireAt ?? "")
    return (tShop != -1 && (tInv == -1 || tShop < tInv)) ? tShop : tInv
  }

  updateNameLoc = @(locName) !shouldAutoConsume && combinedNameLocId
    ? ::loc(combinedNameLocId, { name = locName })
    : locName

  function getName(colored = true)
  {
    local item = getSubstitutionItem()
    if(item != null)
      return item.getName(colored)

    local res = ""
    if (isDisguised)
      res = ::loc("item/disguised")
    else
      res = updateNameLoc(itemDef?.name ?? "")

    if (colored)
      res = ::colorize(getRarityColor(), res)
    return res
  }

  function getDescription()
  {
    if (isDisguised)
      return ""

    local desc = [
      getResourceDesc()
    ]

    local tags = getTagsLoc()
    if (tags.len())
    {
      tags = ::u.map(tags, @(txt) ::colorize("activeTextColor", txt))
      desc.append(::loc("ugm/tags") + ::loc("ui/colon") + ::g_string.implode(tags, ::loc("ui/comma")))
    }

    if (! itemDef?.tags?.hideDesc)
      desc.append(itemDef?.description ?? "")

    return ::g_string.implode(desc, "\n\n")
  }

  function getIcon(addItemName = true)
  {
    return isDisguised ? ::LayersIcon.getIconData("disguised_item")
      : ::LayersIcon.getIconData(null, itemDef.icon_url)
  }

  function getBigIcon()
  {
    if (isDisguised)
      return ::LayersIcon.getIconData("disguised_item")

    local url = !::u.isEmpty(itemDef.icon_url_large) ?
      itemDef.icon_url_large : itemDef.icon_url
    return ::LayersIcon.getIconData(null, url)
  }

  function getOpeningCaption()
  {
    return ::loc(openingCaptionLocId)
  }

  function isAllowSkipOpeningAnim()
  {
    return true
  }

  isCanBuy = @() canBuy && !inventoryClient.getItemCost(id).isZero()

  function getCost(ignoreCanBuy = false)
  {
    if (isCanBuy() || ignoreCanBuy)
      return inventoryClient.getItemCost(id)
    return ::Cost()
  }

  getTransferText = @() transferAmount > 0
    ? ::loc("items/waitItemsInTransaction", { amount = ::colorize("activeTextColor", transferAmount) })
    : ""

  getDescTimers   = @() [
    makeDescTimerData({
      id = "craft_timer"
      getText = getCraftTimeText
      needTimer = hasCraftTimer
    }),
    makeDescTimerData({
      id = "expire_timer"
      getText = getCurExpireTimeText
      needTimer = hasExpireTimer
    }),
    makeDescTimerData({
      id = "marketable_timer"
      getText = getMarketablePropDesc
      needTimer = @() getNoTradeableTimeLeft() > 0
    })
  ]

  getDescHeaderLocId = @() !shouldAutoConsume ? descHeaderLocId : ""

  function getLongDescriptionMarkup(params = null)
  {
    params = params || {}
    params.receivedPrizes <- false

    if (isDisguised)
      return getDescRecipesMarkup(params)

    local content = []
    local headers = [
      { header = getTransferText() }
      { header = getMarketablePropDesc(), timerId = "marketable_timer" }
    ]

    if (hasCraftTimer())
      headers.append({ header = getCraftTimeText(), timerId = "craft_timer" })

    if (hasTimer())
      headers.append({ header = getCurExpireTimeText(), timerId = "expire_timer" })

    if (metaBlk)
    {
      headers.append({ header = ::colorize("grayOptionColor", ::loc(getDescHeaderLocId())) })
      content = [ metaBlk ]
      params.showAsTrophyContent <- true
      params.receivedPrizes <- false
      params.relatedItem <- id
    }

    params.header <- headers
    local recipes = []
    local resultContent = []
    if (needShowAsDisassemble())
    {
      local recipe = getDisassembleRecipe()
      if (recipe)
      {
        recipes.append(recipe)
        resultContent = getDisassembleResultContent(recipe)
      }
    }
    else if(hasReachedMaxAmount())
      headers.append({ header = ::loc(getLocIdsList().reachedMaxAmount) })
    else
      recipes = getMyRecipes()
    return ::PrizesView.getPrizesListView(content, params)
      + ExchangeRecipes.getRequirementsMarkup(recipes, this, params)
      + ::PrizesView.getPrizesListView(resultContent,
          { widthByParentParent = true,
            header = ::colorize("grayOptionColor", ::loc("mainmenu/you_will_receive")) },
          false)
  }

  function getMarketablePropDesc()
  {
    if (!::has_feature("Marketplace"))
      return ""

    local canSell = itemDef?.marketable
    local noTradeableSec = getNoTradeableTimeLeft()
    local locEnding = !canSell ? "no"
      : noTradeableSec > 0 ? "afterTime"
      : "yes"
    local text = ::loc("item/marketable/" + locEnding,
      { name =  ::g_string.utf8ToLower(getTypeName())
        time = noTradeableSec > 0
          ? ::colorize("badTextColor",
              ::stringReplace(time.hoursToString(time.secondsToHours(noTradeableSec), false, true, true), " ", ::nbsp))
          : ""
      })
    return ::loc("currency/gc/sign/colored", "") + " " +
      ::colorize(canSell ? "userlogColoredText" : "badTextColor", text)
  }

  function getResourceDesc()
  {
    if (!metaBlk || !metaBlk?.resource || !metaBlk?.resourceType)
      return ""
    local decoratorType = ::g_decorator_type.getTypeByResourceType(metaBlk.resourceType)
    local decorator = ::g_decorator.getDecorator(metaBlk.resource, decoratorType)
    if (!decorator)
      return ""
    return ::g_string.implode([
      decorator.getTypeDesc()
      decorator.getRestrictionsDesc()
    ], "\n")
  }

  function getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes = false, timeText = "")
  {
    if (showAmount < totalAmount)
      return ::loc(hasFakeRecipes ? getLocIdsList().tryCreateRecipes : getLocIdsList().createRecipes,
        {
          count = totalAmount
          countColored = ::colorize("activeTextColor", totalAmount)
          exampleCount = showAmount
          createTime = timeText.len() ? "\n" + timeText + "\n" : ""
        })

    local isMultipleRecipes = showAmount > 1
    local headerSuffix = isMultipleRecipes && isMultipleExtraItems  ? "any_of_item_sets"
      : !isMultipleRecipes && isMultipleExtraItems ? "items_set"
      : isMultipleRecipes && !isMultipleExtraItems ? "any_of_items"
      : "item"

    return (timeText.len() ? timeText + "\n" : "") +
      ::loc(getLocIdsList().descReceipesListHeaderPrefix + headerSuffix)
  }

  isRare              = @() isDisguised ? base.isRare() : rarity.isRare
  getRarity           = @() isDisguised ? base.getRarity() :rarity.value
  getRarityColor      = @() isDisguised ? base.getRarityColor() :rarity.color
  getTagsLoc          = @() rarity.tag && !isDisguised ? [ rarity.tag ] : []

  canConsume          = @() false
  canAssemble         = @() !isExpired() && getVisibleRecipes().len() > 0
  canConvertToWarbonds = @() isInventoryItem && !isExpired() && ::has_feature("ItemConvertToWarbond") && amount > 0 && getWarbondRecipe() != null
  canDisassemble       = @() isInventoryItem && itemDef?.tags?.canBeDisassembled
    && !isExpired() && getDisassembleRecipe() != null
  getMaxRecipesToShow = @() 1

  hasMainActionDisassemble  = @() itemDef?.tags?.canBeDisassembled == "mainAction"
  needShowAsDisassemble     = @() hasMainActionDisassemble() || (canDisassemble() && !canAssemble())

  function getMainActionData(isShort = false, params = {})
  {
    local res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (amount && canConsume() && (params?.canConsume ?? true))
      return {
        btnName = ::loc("item/consume")
      }
    if (isCrafting())
      return {
        btnName = ::loc("item/craft_process/cancel")
      }
    if (hasCraftResult())
      return {
        btnName = ::loc("items/craft_process/finish")
      }
    if (hasMainActionDisassemble() && canDisassemble() && amount > 0)
      return {
        btnName = getDisassembleText()
      }
    if (canAssemble())
      return {
        btnName = getAssembleButtonText()
        isInactive = hasReachedMaxAmount()
      }
    if (canRunCustomMission())
      return {
        btnName = getCustomMissionButtonText()
      }

    return null
  }

  function doMainAction(cb, handler, params = null)
  {
    return buy(cb, handler, params)
      || consume(cb, params)
      || cancelCrafting(cb, params)
      || seeCraftResult(cb, handler, params)
      || (hasMainActionDisassemble() && disassemble(params))
      || assemble(cb, params)
      || runCustomMission()
  }

  getAltActionName   = @() (amount && canConsume() && canAssemble()) ? ::loc(getLocIdsList().assemble)
    : canConvertToWarbonds() ? ::loc("items/exchangeTo", { currency = getWarbondExchangeAmountText() })
    : (!hasMainActionDisassemble() && canDisassemble() && amount > 0 && !isCrafting() && !hasCraftResult())
      ? getDisassembleText()
    : ""
  doAltAction        = @(params) (canConsume() && assemble(null, params))
    || convertToWarbonds(params)
    || (!hasMainActionDisassemble() && disassemble(params))

  function consume(cb, params)
  {
    if (!uids || !uids.len() || !metaBlk || !canConsume() || !(params?.canConsume ?? true))
      return false

    if (shouldAutoConsume)
    {
      consumeImpl(cb, params)
      return true
    }

    local text = ::loc("recentItems/useItem", { itemName = ::colorize("activeTextColor", getName()) })
      + "\n" + ::loc("msgBox/coupon_exchange")
    local msgboxParams = {
      cancel_fn = @() null
      baseHandler = ::get_cur_base_gui_handler() //FIX ME: handler used only for prizes tooltips
      data_below_text = ::PrizesView.getPrizesListView([ metaBlk ],
        { showAsTrophyContent = true, receivedPrizes = false, widthByParentParent = true })
      data_below_buttons = ::has_feature("Marketplace") && itemDef?.marketable
        ? ::format("textarea{overlayTextColor:t='warning'; text:t='%s'}", ::g_string.stripTags(::loc("msgBox/coupon_will_be_spent")))
        : null
    }
    local item = this //we need direct link, to not lose action on items list refresh.
    ::scene_msg_box("coupon_exchange", null, text, [
      [ "yes", @() item.consumeImpl(cb, params) ],
      [ "no" ]
    ], "yes", msgboxParams)
    return true
  }

  function consumeImpl(cb = null, params = null)
  {
    local uid = uids?[0]
    if (!uid)
      return

    local blk = ::DataBlock()
    blk.setInt("itemId", uid.tointeger())

    local itemAmountByUid = amountByUids[uid] //to not remove item while in progress
    local taskCallback = function() {
      local item = ::ItemsManager.findItemByUid(uid)
      //items list refreshed, but ext inventory only requested.
      //so update item amount to avoid repeated request before real update
      if (item && item.amountByUids[uid] == itemAmountByUid)
      {
        item.amountByUids[uid]--
        item.amount--
        if (item.amountByUids[uid] <= 0)
        {
          inventoryClient.removeItem(uid)
          if (item.uids?[0] == uid)
            item.uids.remove(0)
        }
      }
      if (cb)
        cb({ success = true })
    }

    local taskId = ::char_send_blk("cln_consume_inventory_item", blk)
    ::g_tasker.addTask(taskId, { showProgressBox = !shouldAutoConsume }, taskCallback)
  }

  getAssembleHeader       = @() ::loc(getLocIdsList().headerRecipesList, { itemName = getName() })
  getAssembleText         = @() ::loc(getLocIdsList().assemble)
  getAssembleButtonText   = @() getVisibleRecipes().len() > 1 ? ::loc(getLocIdsList().recipes) : getAssembleText()
  getCantUseLocId         = @() getLocIdsList().msgBoxCantUse
  getConfirmMessageData   = @(recipe) getEmptyConfirmMessageData().__update({
    text = ::loc(recipe.getConfirmMessageLocId(getLocIdsList()),
        { itemName = ::colorize("activeTextColor", getName()) })
      + (recipe.hasCraftTime() ? "\n" + recipe.getCraftTimeText() : "")
    headerRecipeMarkup = recipe.getHeaderRecipeMarkupText()
    needRecipeMarkup = true
  })

  function assemble(cb = null, params = null)
  {
    if (!canAssemble())
      return false

    local recipesList = params?.recipes ?? getVisibleRecipes()
    if (recipesList.len() == 1)
    {
      ExchangeRecipes.tryUse(recipesList, this, params)
      return true
    }

    local item = this
    recipesListWnd.open({
      recipesList = recipesList
      headerText = getAssembleHeader()
      buttonText = getAssembleText()
      alignObj = params?.obj
      onAcceptCb = function(recipe)
      {
        ExchangeRecipes.tryUse([recipe], item, params)
        return !recipe.isUsable
      }
    })
    return true
  }

  function getWarbondExchangeAmountText()
  {
    local recipe = getWarbondRecipe()
    if (amount <= 0 || !recipe)
      return ""
    local warbondItem = ::ItemsManager.findItemById(recipe.generatorId)
    local warbond = warbondItem && warbondItem.getWarbond()
    if (!warbond)
      return ""
    return warbondItem.getWarbondsAmount() + ::loc(warbond.fontIcon)
  }

  getDisassembleText = @() ::loc(getLocIdsList().disassemble)
  function disassemble(params = null)
  {
    if (!canDisassemble() || amount <= 0 || isCrafting() || hasCraftResult())
      return false

    local recipe = getDisassembleRecipe()
    if (amount <= 0 || !recipe)
      return false

    local content = getDisassembleResultContent(recipe)
    ExchangeRecipes.tryUse([ recipe ], this,
      { rewardListLocId = getItemsListLocId()
        bundleContent = content
      })
      return true
  }

  getDisassembleResultContent = function(recipe)
  {
    local gen = ItemGenerators.get(recipe.generatorId)
    local content = gen?.isPack ? gen.getContent() : []
    return gen?.isDelayedxchange?() && content.len() > 0
      ? ::ItemsManager.findItemById(content[0].item)?.getContent?() ?? []
      : content
  }

  function convertToWarbonds(params = null)
  {
    if (!canConvertToWarbonds())
      return false
    local recipe = getWarbondRecipe()
    if (amount <= 0 || !recipe)
      return false

    local warbondItem = ::ItemsManager.findItemById(recipe.generatorId)
    local warbond = warbondItem && warbondItem.getWarbond()
    if (!warbond)
      return false

    local leftWbAmount = ::g_warbonds.getLimit() - warbond.getBalance()
    if (leftWbAmount <= 0)
    {
      ::showInfoMsgBox(::loc("items/cantExchangeToWarbondsMessage"))
      return true
    }

    local maxAmount = ::ceil(leftWbAmount.tofloat() / warbondItem.getWarbondsAmount()).tointeger()
    maxAmount = ::min(maxAmount, amount)
    if (maxAmount == 1 || !::has_feature("ItemConvertToWarbondMultiple"))
    {
      convertToWarbondsImpl(recipe, warbondItem, 1)
      return true
    }

    local item = this
    local icon = ::loc(warbond.fontIcon)
    chooseAmountWnd.open({
      parentObj = params?.obj
      align = params?.align ?? "bottom"
      minValue = 1
      maxValue = maxAmount
      curValue = maxAmount
      valueStep = 1

      headerText = ::loc("items/exchangeTo", { currency = icon })
      buttonText = ::loc("items/btnExchange")
      getValueText = @(value) value + " x " + warbondItem.getWarbondsAmount() + icon
        + " = " + value * warbondItem.getWarbondsAmount() + icon

      onAcceptCb = @(value) item.convertToWarbondsImpl(recipe, warbondItem, value)
      onCancelCb = null
    })
    return true
  }

  function convertToWarbondsImpl(recipe, warbondItem, convertAmount)
  {
    local msg = ::loc("items/exchangeMessage", {
      amount = convertAmount
      item = getName()
      currency = convertAmount * warbondItem.getWarbondsAmount() + ::loc(warbondItem.getWarbond()?.fontIcon)
    })
    ::scene_msg_box("warbond_exchange", null, msg, [
      [ "yes", @() recipe.doExchange(warbondItem, convertAmount) ],
      [ "no" ]
    ], "yes", { cancel_fn = @() null })
  }

  /*override */ function hasLink()
  {
    return !isDisguised && base.hasLink()
      && itemDef?.marketable && getNoTradeableTimeLeft() == 0
      && ::has_feature("Marketplace")
  }

  function getMetaResource()
  {
    return metaBlk?.resource
  }

  function addResources(params = null)
  {
    if (!metaBlk?.resource || !metaBlk?.resourceType || !itemDef)
      return
    local resource = metaBlk.resource
    if (!guidParser.isGuid(resource))
      return

    ::g_decorator.buildLiveDecoratorFromResource(metaBlk.resource, metaBlk.resourceType, itemDef, params)
  }

  function getRelatedRecipes()
  {
    local res = []
    foreach (genItemdefId in inventoryClient.getChestGeneratorItemdefIds(id))
    {
      local gen = ItemGenerators.get(genItemdefId)
      if (gen == null || ::ItemsManager.findItemById(gen.id)?.iType == itemType.WARBONDS)
        continue
      res.extend(gen.getRecipesWithComponent(id))
    }
    return res
  }

  function getWarbondRecipe()
  {
    foreach (genItemdefId in inventoryClient.getChestGeneratorItemdefIds(id))
    {
      local item = ::ItemsManager.findItemById(genItemdefId)
      if (item?.iType != itemType.WARBONDS)
        continue
      local gen = ItemGenerators.get(genItemdefId)
      if (!gen)
        continue
      local recipes = gen.getRecipesWithComponent(id)
      if (recipes.len())
        return recipes[0]
    }
    return null
  }

  function getDisassembleRecipe()
  {
    foreach (genItemdefId in inventoryClient.getChestGeneratorItemdefIds(id))
    {
      local gen = ItemGenerators.get(genItemdefId)
      if (!gen || !gen?.tags?.isDisassemble)
        continue
      local recipes = gen.getRecipesWithComponent(id)
      if (recipes.len())
        return recipes[0]
    }
    return null
  }

  getMyRecipes = @() ItemGenerators.get(id)?.getRecipes() ?? []

  function getVisibleRecipes() {
    local gen = ItemGenerators.get(id)
    if (showAllowableRecipesOnly())
      return gen?.getUsableRecipes() ?? []
    return gen?.getRecipes() ?? []
  }

  getExpireTimeTextShort = @() ::colorize(expireCountdownColor, base.getExpireTimeTextShort())

  function getCurExpireTimeText()
  {
    if (expireTimestamp == -1)
      return ""
    return ::colorize(expireCountdownColor, ::loc(expireCountdownLocId, {
      datetime = time.buildDateTimeStr(expireTimestamp)
      timeleft = getExpireTimeTextShort()
    }))
  }

  function needShowActionButtonAlways(params)
  {
    if(getMainActionData(true, params)?.isInactive ?? false)
      return false

    if (canRunCustomMission())
      return true

    if (hasCraftResult())
      return true

    if (!canAssemble())
      return false

    foreach (recipes in getVisibleRecipes())
      if (recipes.isUsable)
        return true

    return false
  }

  isGoldPurchaseInProgress = @() ::u.search(itemTransfer.getSendingList(), @(data) (data?.goldCost ?? 0) > 0) != null

  function _buy(cb = null, params = null)
  {
    if (!isCanBuy())
      return false

    if (isGoldPurchaseInProgress())
    {
      ::g_popups.add(null, ::loc("items/msg/waitPreviousGoldTransaction"), null, null, null, "waitPrevGoldTrans")
      return true
    }

    local blk = ::DataBlock()
    blk.key = ::inventory_generate_key()
    blk.itemDefId = id
    blk.goldCost = getCost().gold

    local onSuccess = function() {
      if (cb)
        cb({ success = true })
    }
    local onError = @(errCode) cb ? cb({ success = false }) : null

    local taskId = ::char_send_blk("cln_inventory_purchase_item", blk)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess, onError)
    return true
  }

  onItemCraft     = @() ::ItemsManager.refreshExtInventory()
  function getCraftingItem()
  {
    local recipes = []
    if (needShowAsDisassemble())
    {
      local recipe = getDisassembleRecipe()
      if (recipe)
        recipes.append(recipe)
    }
    else
    {
      local gen = ItemGenerators.get(id)
      recipes = gen ? gen.getRecipes() : []
    }

    foreach (recipe in recipes)
    {
      local item = ::ItemsManager.getInventoryItemById(recipe.generatorId)
      if (item)
        return item?.itemDef?.type == "delayedexchange" ? item : null
    }

    return null
  }

  function getCraftTimeTextShort()
  {
    local craftingItem = getCraftingItem()
    local craftTimeSec = craftingItem?.expiredTimeSec ?? 0
    if (craftTimeSec <= 0)
      return ""

    local curSeconds = ::dagor.getCurTime() * 0.001
    local deltaSeconds = (craftTimeSec - curSeconds).tointeger()
    if (deltaSeconds < 0)
    {
      if (isInventoryItem)
        onItemCraft()
      return ::colorize(craftColor, ::loc(craftFinishedLocId))
    }
    return ::colorize(craftColor, ::loc("icon/hourglass") + ::nbsp +
      ::stringReplace(time.hoursToString(time.secondsToHours(deltaSeconds), false, true, true), " ", ::nbsp))
  }

  function getCraftTimeText()
  {
    local craftingItem = getCraftingItem()
    local craftTime = craftingItem?.expireTimestamp ?? -1
    if (craftTime == -1)
      return ""

    return ::colorize(craftColor, ::loc(getLocIdsList().craftCountdown, {
      datetime = time.buildDateTimeStr(craftTime)
      timeleft = getCraftTimeTextShort()
    }))
  }

  isCraftResult = @() craftedFrom.indexof(";") != null
  getParentGen = @() isCraftResult() ? ItemGenerators.findGenByReceptUid(craftedFrom) : null

  function getCraftResultItem()
  {
    local recipes = []
    if (needShowAsDisassemble())
    {
      local recipe = getDisassembleRecipe()
      if (recipe)
        recipes.append(recipe)
    }
    else
    {
      local gen = ItemGenerators.get(id)
      recipes = gen ? gen.getRecipes() : []
    }

    foreach (recipe in recipes)
    {
      local item = ::ItemsManager.getInventoryItemByCraftedFrom(recipe.uid)
      if (item)
        return item
    }

    return null
  }

  function seeCraftResult(cb, handler, params = {})
  {
    local craftResult = getCraftResultItem()
    if (!craftResult)
      return false

    params.shouldSkipMsgBox <- true
    craftResult.doMainAction(cb, handler, params)
    return true
  }

  function getAdditionalTextInAmmount(needColorize = true, needOnlyIcon = false)
  {
    local locIds = getLocIdsList()
    local textIcon = isCrafting()
      ? locIds.craftingIconInAmmount
      : hasCraftResult()
        ? locIds.craftResultIconInAmmount
        : ""

    if (textIcon == "")
      return ""

    local text = ::loc(textIcon)
    if (!needOnlyIcon)
      text = " + 1{0}".subst(text)
    return needColorize ? ::colorize(craftColor, text) : text
  }

  function cancelCrafting(cb = null, params = {})
  {
    local craftingItem = getCraftingItem()

    if (!craftingItem || craftingItem?.itemDef?.type != "delayedexchange")
      return false

    // prevent infinite recursion on incorrectly configured delayedexchange
    if (craftingItem == this)
    {
      ::dagor.logerr("Inventory: delayedexchange " + id + " instance has type " +
          ::getEnumValName("itemType", iType) + " which does not implement cancelCrafting()")
      return false
    }

    params.parentItem <- this
    params.isDisassemble <- needShowAsDisassemble()
    craftingItem.cancelCrafting(cb, params)
    return true
  }

  isHiddenItem = @() !isEnabled() || isCraftResult() || itemDef?.tags?.devItem == true
  isEnabled = @() requirement == null || ::has_feature(requirement)
  function getAdditionalConfirmMessage(actionName, delimiter = "\n")
  {
     local locKey = aditionalConfirmationMsg?[actionName]
     if (!locKey)
       return ""

     return delimiter + ::loc("confirmationMsg/" + locKey)
  }

  getCustomMissionBlk = function() {
    local misName = itemDef?.tags?.canRunCustomMission
    if (!misName)
      return null

    local misBlk = ::get_mission_meta_info(misName)
    if (!misBlk || (("reqFeature" in misBlk) && !::has_feature(misBlk.reqFeature)))
      return null

    return misBlk
  }

  canRunCustomMission = @() amount > 0 && getCustomMissionBlk() != null
  getCustomMissionButtonText = @() get_mission_name(itemDef.tags.canRunCustomMission, getCustomMissionBlk())

  function runCustomMission()
  {
    if (!canRunCustomMission())
        return false

    local misBlk = ::get_mission_meta_info(itemDef.tags.canRunCustomMission)
    if (misBlk?.requiredPackage != null && !check_package_and_ask_download(misBlk.requiredPackage))
      return true

    ::broadcastEvent("BeforeStartCustomMission")
    ::custom_miss_flight <- true
    ::current_campaign_mission <- itemDef.tags.canRunCustomMission
    ::select_training_mission(misBlk)
    return true
  }

  function getViewData(params = {})
  {
    local item = getSubstitutionItem()
    if(item != null)
      return getSubstitutionViewData(item.getViewData(params), params)

    local res = base.getViewData(params)
    if(res.layered_image == "")
      res.nameText <- getName()
    local markPresetName = itemDef?.tags?.markingPreset
    if (!markPresetName)
      return res

    local data = getMarkingPresetsById(markPresetName)
    if(!data)
      return res

    res.needMarkIcon <- true
    res.markIcon <- ::loc(data.markIconLocId)
    res.markIconColor <- data.color

    return res
  }

  function updateSubstitutionItemDataOnce()
  {
    local tag = itemDef.tags?.showAsAnotherItem
    if(tag == null)
      return

    substitutionItemData = []
    local tagData = split(tag, "_")
    for (local i = tagData.len() - 1; i >= 0 ; i--)
    {
      local ids = split(tagData[i], "-")
      if (ids.len() < 2)
        continue
      substitutionItemData.append(ids)
      inventoryClient.requestItemdefsByIds(ids)
    }
  }

  function getSubstitutionItem()
  {
    if(substitutionItemData?.len() == 0)
      return null
    for (local i = 0; i < substitutionItemData.len(); i++)
      if (::ItemsManager.getInventoryItemById(substitutionItemData[i][0].tointeger()))
        return ::ItemsManager.findItemById(substitutionItemData[i][1].tointeger())

    return null
  }

  function getDescriptionUnderTitle()
  {
    local markPresetName = itemDef?.tags?.markingPreset
    if (!markPresetName || isDisguised)
      return ""

    local data = getMarkingPresetsById(markPresetName)
    if (!data)
      return ""

    return ::colorize(data.color, ::loc(data.additionalDesc))
  }

  getLocIdsList = function() {
    if (locIdsList)
      return locIdsList

    locIdsList = getLocIdsListImpl()
    local localizationPreset = itemDef?.tags?.customLocalizationPreset
    if (localizationPreset)
      locIdsList.__update(getCustomLocalizationPresets(localizationPreset))

    return locIdsList
  }

  getLocIdsListImpl = @() defaultLocIdsList.__merge({
    descReceipesListHeaderPrefix = descReceipesListHeaderPrefix
      + (needShowAsDisassemble() ? "disassemble/" : "")
    msgBoxCantUse                = needShowAsDisassemble()
      ? "msgBox/disassembleItem/cant"
      : "msgBox/assembleItem/cant"
    craftCountdown               = "items/craft_process/countdown"
      + (needShowAsDisassemble() ? "/disassemble" : "")
    headerRecipesList            = ExchangeRecipes.hasFakeRecipes(getVisibleRecipes())
      ? "item/create_header/findTrue"
      : "item/create_header"
    craftingIconInAmmount        = needShowAsDisassemble() ? "hud/iconRepair" : "icon/gear"
    reUseItemLocId               = canConsume() ? "item/consume/again"
      : hasMainActionDisassemble() && canDisassemble() ? "item/disassemble/again"
      : canAssemble() ? "item/assemble/again"
      : defaultLocIdsList.reUseItemLocId
  })

  needOfferBuyAtExpiration = @() !isHiddenItem() && itemDef?.tags?.offerToBuyAtExpiration
  isVisibleInWorkshopOnly = @() itemDef?.tags?.showInWorkshopOnly ?? false
  getDescRecipesMarkup = @(params) ExchangeRecipes.getRequirementsMarkup(getMyRecipes(), this, params)
  getIconName = @() isDisguised ? getSmallIconName() : itemDef.icon_url
  hasUsableRecipeOrNotRecipes = function ()
  {
    local recipes = getVisibleRecipes()
    if (recipes.len() == 0)
      return true

    return ::u.search(recipes, @(r) r.isUsable) != null
  }

  function getBoostEfficiency()
  {
    local substitutionItem = getSubstitutionItem()
    return substitutionItem != null
      ? substitutionItem.getBoostEfficiency()
      : itemDef?.tags?.boostEfficiency.tointeger()
  }

  getEffectOnOpenChest = @() getEffectOnOpenChestPresetById(itemDef?.tags?.effectOnOpenChest ?? "")
  canCraftOnlyInCraftTree = @() itemDef?.tags?.canCraftOnlyInCraftTree ?? false
  showAllowableRecipesOnly = @() itemDef?.tags?.showAllowableRecipesOnly ?? false
  canRecraftFromRewardWnd = @() itemDef?.tags?.allowRecraftFromRewardWnd ?? false
  getQuality = @() itemDef?.tags?.quality ?? "common"
}

return ItemExternal
