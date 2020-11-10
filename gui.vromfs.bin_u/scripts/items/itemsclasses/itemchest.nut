local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")
local ItemGenerators = require("scripts/items/itemsClasses/itemGenerators.nut")
local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")
local { getPrizeChanceLegendMarkup } = require("scripts/items/prizeChance.nut")

class ::items_classes.Chest extends ItemExternal {
  static iType = itemType.CHEST
  static defaultLocId = "chest"
  static typeIcon = "#ui/gameuiskin#item_type_trophies"
  static openingCaptionLocId = "mainmenu/chestConsumed/title"
  static isPreferMarkupDescInTooltip = true
  static userlogOpenLoc = "open_trophy"
  static hasTopRewardAsFirstItem = false
  static includeInRecentItems = false
  static descReceipesListHeaderPrefix = "chest/requires/"

  _isInitialized = false
  generator = null
  categoryWeight = null

  function getGenerator()
  {
    if (!_isInitialized)
    {
      _isInitialized = true
      local genIds = inventoryClient.getChestGeneratorItemdefIds(id)
      local genId = genIds.findvalue(@(genId) (ItemGenerators.get(genId)?.bundle ?? "") != "")
      generator = ItemGenerators.get(genId)
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

    if (!uids || !uids.len() || !canConsume() || !hasUsableRecipe())
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
    if (canOpenForGold() && isInventoryItem && amount > 0) {
      local openCost = getOpenForGoldRecipe()?.getOpenCost(this)
      if (openCost != null)
        return {
          btnName = getBuyText(false, isShort, "item/open", openCost)
          btnColoredName = getBuyText(true, isShort, "item/open", openCost)
      }
    }
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
      (hasContent ? ::PrizesView.getPrizesListText(content, getDescHeaderFunction()) : ""),
      getHiddenItemsDesc() || "",
      getLongDescription(),
    ], "\n")
  }

  function getLongDescription()
  {
    return itemDef?.tags?.hideDesc ? "" : (itemDef?.description ?? "")
  }

  function getDescHeaderFunction() {
    return isContentPack() ? (@(fixedAmount = 1) ::loc("trophy/chest_contents/all"))
      : _getDescHeader
  }

  function getLongDescriptionMarkup(params = null)
  {
    params = params || {}
    params.receivedPrizes <- false
    params.needShowDropChance <- needShowDropChance()
    local content = getContent()
    local hasContent = content.len() != 0

    local prizeMarkupArray = [::PrizesView.getPrizesListView([], { header = getTransferText() }),
      ::PrizesView.getPrizesListView([], { header = getMarketablePropDesc() }),
      (hasTimer() ? ::PrizesView.getPrizesListView([], { header = getCurExpireTimeText(), timerId = "expire_timer" }) : ""),
      getDescRecipesMarkup(clone params)
    ]

    if (hasContent) {
      local categoryWeightArray = getCategoryWeight()
      if (params.needShowDropChance && categoryWeightArray.len() > 0) {
        params.categoryWeight <- categoryWeightArray
        prizeMarkupArray.append(::PrizesView.getPrizesStacksViewByWeight(content, getDescHeaderFunction(),clone params))
      }
      else
        prizeMarkupArray.append(::PrizesView.getPrizesStacksView(content, getDescHeaderFunction(), params))
      prizeMarkupArray.append(::PrizesView.getPrizesListView([], { header = getHiddenItemsDesc() }))
    }
    return "".join(prizeMarkupArray)
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

    if (openForGold(cb, params))
      return true

    return ExchangeRecipes.tryUse(getRelatedRecipes(), this, params)
  }

  getContentNoRecursion = @() getContent()

  getLocIdsListImpl = @() base.getLocIdsListImpl().__update({
    descReceipesListHeaderPrefix = descReceipesListHeaderPrefix
    msgBoxCantUse                = "msgBox/chestOpen/cant"
    msgBoxConfirm                = "msgBox/chestOpen/confirm"
  })

  needShowDropChance = @() ::has_feature("ShowDropChanceInTrophy")
    && ((itemDef?.tags?.showDropChance ?? false)
      || getCategoryWeight().len() > 0)

  function getTableData() {
    if (!needShowDropChance())
      return null

    local markup = getPrizeChanceLegendMarkup()
    if (markup == "")
      return null

    return markup
  }

  canOpenForGold = @() itemDef?.tags.openForGoldByFeature != null
    && ::has_feature(itemDef.tags.openForGoldByFeature)
  hasUsableRecipe = @() getRelatedRecipes().findvalue(@(recipe) recipe.isUsable) != null
  getOpenForGoldRecipe = @() getRelatedRecipes().findvalue(
    (@(recipe) recipe.getOpenCost(this) != null).bindenv(this))

  function openForGold(cb, params = null) {
    if (!canOpenForGold() || !isInventoryItem || amount == 0)
      return false

    local openForGoldRecipe = getOpenForGoldRecipe()
    if (openForGoldRecipe == null)
      return true

    local cost = openForGoldRecipe.getOpenCost(this)
    if (!::check_balance_msgBox(cost))
      return true

    local item = this
    local text = ::warningIfGold(
      ::loc("item/openForGold/needMoneyQuestion", { itemName = getName(), cost = cost.getTextAccordingToBalance() }),
      cost)
    ::scene_msg_box("open_ches_for_gold", null, text, [
      [ "yes", @() openForGoldRecipe.buyAllRequiredComponets(item) ],
      [ "no" ]
    ], "yes")

    return true
  }

  function getCost(ignoreCanBuy = false) {
    if (canOpenForGold() && isInventoryItem && amount > 0)
      return getOpenForGoldRecipe()?.getOpenCost(this) ?? ::Cost()

    return base.getCost(ignoreCanBuy)
  }

  function getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes = false, timeText = "") {
    if (canOpenForGold())
      return ::loc($"{getLocIdsList().descReceipesListHeaderPrefix}item")

    return base.getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes, timeText)
  }

  function getCategoryWeight() {
    if (categoryWeight != null)
      return categoryWeight

    categoryWeight = []
    if (itemDef?.tags.categoryWeight == null)
      return categoryWeight

    foreach (category in (itemDef.tags % "categoryWeight")) {
      local paramsArray = category.split("_")
      if (paramsArray.len() < 2)
        continue

      local prizeType = paramsArray[0]
      local weight = paramsArray[1]
      local rarity = paramsArray?[2]
      local hasRarity = rarity != null
      local categoryIdx = categoryWeight.findindex(@(c) c.prizeType == prizeType)
      if (categoryIdx == null) {
        categoryWeight.append({
          prizeType = prizeType
          rarity = hasRarity ? [{ rarity = rarity, weight = weight }] : null
          weight = hasRarity ? null : weight
        })
        continue
      }

      local categ = categoryWeight[categoryIdx]
      if (categ?.weight != null)  //All prizes of this type are filled by one group
        continue

      if (!hasRarity) {
        categ.__update({ weight = weight })
        continue
      }

      categ.__update({ rarity = categ.rarity.append({ rarity = rarity, weight = weight }) })
    }
    return categoryWeight
  }
}
