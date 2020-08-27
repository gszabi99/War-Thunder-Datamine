local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")
local ItemGenerators = require("scripts/items/itemsClasses/itemGenerators.nut")
local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")

class ::items_classes.Chest extends ItemExternal {
  static iType = itemType.CHEST
  static defaultLocId = "chest"
  static typeIcon = "#ui/gameuiskin#item_type_trophies"
  static openingCaptionLocId = "mainmenu/chestConsumed/title"
  static isPreferMarkupDescInTooltip = false
  static userlogOpenLoc = "open_trophy"
  static hasTopRewardAsFirstItem = false
  static includeInRecentItems = false
  static descReceipesListHeaderPrefix = "chest/requires/"

  _isInitialized = false
  generator = null

  function getGenerator()
  {
    if (!_isInitialized)
    {
      _isInitialized = true
      local genId = inventoryClient.getChestGeneratorItemdefIds(id)?[0]
      generator = genId && ItemGenerators.get(genId)
    }
    return generator
  }

  function getOpenedBigIcon()
  {
    return ""
  }

  canConsume = @() isInventoryItem

  function consume(cb, params)
  {
    if (base.consume(cb, params))
      return true

    if (!uids || !uids.len() || !canConsume())
      return false

    if (shouldAutoConsume)
    {
      params.cb <- cb
      params.shouldSkipMsgBox <- true
      ExchangeRecipes.tryUse(getRelatedRecipes(), this, params)
      return true
    }

    return false
  }

  function getMainActionData(isShort = false, params = {})
  {
    local res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (isInventoryItem && amount)
      return {
        btnName = ::loc("item/open")
      }

    return null
  }

  skipRoulette              = @() isContentPack()
  isContentPack             = @() getGenerator()?.isPack ?? false
  isAllowSkipOpeningAnim    = @() ::is_dev_version
  getOpeningAnimId          = @() itemDef?.tags?.isLongOpenAnim ? "LONG" : "DEFAULT"
  getConfirmMessageData    = @(recipe) getEmptyConfirmMessageData().__update({
    text = ::loc(getLocIdsList().msgBoxConfirm, { itemName = ::colorize("activeTextColor", getName()) })
    headerRecipeMarkup = recipe.getHeaderRecipeMarkupText()
    needRecipeMarkup = recipe.isMultipleItems
  })

  function getContent()
  {
    return getGenerator()?.getContent() ?? []
  }

  getDescRecipesText    = @(params) ExchangeRecipes.getRequirementsText(getRelatedRecipes(), this, params)
  getDescRecipesMarkup  = @(params) ExchangeRecipes.getRequirementsMarkup(getRelatedRecipes(), this, params)

  function getDescription()
  {
    local params = { receivedPrizes = false }

    local content = getContent()
    local hasContent = content.len() != 0

    return ::g_string.implode([
      getTransferText(),
      getMarketablePropDesc(),
      getCurExpireTimeText(),
      getDescRecipesText(params),
      (hasContent ? ::PrizesView.getPrizesListText(content, _getDescHeader) : ""),
      getHiddenItemsDesc() || "",
      getLongDescription(),
    ], "\n")
  }

  function getLongDescription()
  {
    return itemDef?.tags?.hideDesc ? "" : (itemDef?.description ?? "")
  }

  function getLongDescriptionMarkup(params = null)
  {
    params = params || {}
    params.receivedPrizes <- false

    local content = getContent()
    local hasContent = content.len() != 0

    return ::PrizesView.getPrizesListView([], { header = getTransferText() })
      + ::PrizesView.getPrizesListView([], { header = getMarketablePropDesc() })
      + (hasTimer() ? ::PrizesView.getPrizesListView([], { header = getCurExpireTimeText(), timerId = "expire_timer" }) : "")
      + getDescRecipesMarkup(params)
      + (hasContent ? ::PrizesView.getPrizesStacksView(content, _getDescHeader, params) : "")
      + (hasContent ? ::PrizesView.getPrizesListView([], { header = getHiddenItemsDesc() }) : "")
  }

  function _getDescHeader(fixedAmount = 1)
  {
    local locId = (fixedAmount > 1) ? "trophy/chest_contents/many" : "trophy/chest_contents"
    local headerText = ::loc(locId, { amount = ::colorize("commonTextColor", fixedAmount) })
    return ::colorize("grayOptionColor", headerText)
  }

  function getHiddenItemsDesc()
  {
    if (!getGenerator()?.hasHiddenItems || !getContent().len())
      return null
    return ::colorize("grayOptionColor", ::loc("trophy/chest_contents/other"))
  }

  function getHiddenTopPrizeParams()
  {
    return getGenerator()?.hiddenTopPrizeParams ?? null
  }

  function isHiddenTopPrize(prize)
  {
    return getGenerator()?.isHiddenTopPrize(prize) ?? false
  }

  function canPreview()
  {
    local content = getContent()
    return content.len() == 1 && content[0].item != null
      && ::ItemsManager.findItemById(content[0].item)?.canPreview()
  }

  function doPreview()
  {
    ::ItemsManager.findItemById(getContent()?[0]?.item)?.doPreview()
  }

  function doMainAction(cb, handler, params = null)
  {
    if (buy(cb, handler, params))
      return true
    if (!uids || !uids.len())
      return false

    return ExchangeRecipes.tryUse(getRelatedRecipes(), this, params)
  }

  getContentNoRecursion = @() getContent()

  getLocIdsListImpl = @() base.getLocIdsListImpl().__update({
    descReceipesListHeaderPrefix = descReceipesListHeaderPrefix
    msgBoxCantUse                = "msgBox/chestOpen/cant"
    msgBoxConfirm                = "msgBox/chestOpen/confirm"
  })
}