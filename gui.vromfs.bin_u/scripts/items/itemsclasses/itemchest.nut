from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import *

let { Cost } = require("%scripts/money.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")
let { getItemGenerator } = require("%scripts/items/itemGeneratorsManager.nut")
let { getRequirementsMarkup, getRequirementsText, tryUseRecipes
} = require("%scripts/items/exchangeRecipes.nut")
let { getPrizeChanceLegendMarkup } = require("%scripts/items/prizeChance.nut")
let inventoryItemTypeByTag = require("%scripts/items/inventoryItemTypeByTag.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { registerItemClass } = require("%scripts/items/itemsTypeClasses.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { getPrizesStacksViewByWeight, getPrizesStacksViewByCategory, getPrizesListText,
  getPrizesListView, getPrizesStacksView
} = require("%scripts/items/prizesView.nut")

let Chest = class (ItemExternal) {
  static name = "Chest"
  static iType = itemType.CHEST
  static defaultLocId = "chest"
  static typeIcon = "#ui/gameuiskin#item_type_trophies.svg"
  static isPreferMarkupDescInTooltip = true
  static userlogOpenLoc = "open_trophy"
  static hasTopRewardAsFirstItem = false
  static includeInRecentItems = false
  static descReceipesListHeaderPrefix = "chest/requires/"

  canMultipleConsume = false

  _isInitialized = false
  generator = null
  categoryWeight = null
  categoryByItems = null

  function getGenerator() {
    if (!this._isInitialized) {
      this._isInitialized = true
      let genIds = inventoryClient.getChestGeneratorItemdefIds(this.id)
      let genId = genIds.findvalue(@(genId) (getItemGenerator(genId)?.bundle ?? "") != "")
      this.generator = getItemGenerator(genId)
    }
    return this.generator
  }

  function getOpenedBigIcon() {
    return ""
  }

  canConsume = @() this.isInventoryItem

  function consume(cb, params) {
    if (base.consume(cb, params))
      return true

    if (!this.uids || !this.uids.len() || !this.canConsume() || !this.hasUsableRecipe())
      return false

    if (this.shouldAutoConsume) {
      params.cb <- cb
      params.shouldSkipMsgBox <- true
      tryUseRecipes(this.getRelatedRecipes(), this, params)
      return true
    }

    return false
  }

  function getMainActionData(isShort = false, params = {}) {
    if (this.canOpenForGold() && this.isInventoryItem && this.amount > 0) {
      let openCost = this.getOpenForGoldRecipe()?.getOpenCost(this)
      if (openCost != null)
        return {
          btnName = this.getBuyText(false, isShort, "item/open", openCost)
          btnColoredName = this.getBuyText(true, isShort, "item/open", openCost)
      }
    }
    let res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (this.isInventoryItem && this.amount)
      return {
        btnName = loc("item/open")
      }

    return null
  }

  skipRoulette              = @() this.isContentPack()
  isContentPack             = @() this.getGenerator()?.isPack ?? false
  isAllowSkipOpeningAnim    = @() this.itemDef?.tags.isAllowSkipOpeningAnim || is_dev_version()
  getOpeningAnimId          = @() this.itemDef?.tags?.isLongOpenAnim ? "LONG" : "DEFAULT"
  function getConfirmMessageData(recipe, quantity) {
    let confirmLocId = quantity == 1 ? this.getLocIdsList().msgBoxConfirm : this.getLocIdsList().msgBoxSeveralConfirm
    let itemName = quantity == 1 ? this.getName() : $"{this.getName()} {loc("ui/multiply")}{quantity}"
    return this.getEmptyConfirmMessageData().__update({
      text = loc(confirmLocId, { itemName = colorize("activeTextColor", itemName) })
      headerRecipeMarkup = recipe.getHeaderRecipeMarkupText()
      needRecipeMarkup = recipe.isMultipleItems
    })
  }

  function getContent() {
    return this.getGenerator()?.getContent() ?? []
  }

  getDescRecipesText    = @(params) getRequirementsText(this.getRelatedRecipes(), this, params)
  getDescRecipesMarkup  = @(params) getRequirementsMarkup(this.getRelatedRecipes(), this, params)

  function getDescription() {
    let params = { receivedPrizes = false }

    let content = this.getContent()
    local hasContent = content.len() != 0

    return "\n".join([
      this.getTransferText(),
      this.getMarketablePropDesc(),
      this.getCurExpireTimeText(),
      this.getDescRecipesText(params),
      (hasContent ? getPrizesListText(content, this.getDescHeaderFunction()) : ""),
      this.getHiddenItemsDesc() || "",
      this.getLongDescription(),
    ], true)
  }

  function getLongDescription() {
    return this.itemDef?.tags?.hideDesc ? "" : (this.itemDef?.description ?? "")
  }

  function getDescHeaderFunction() {
    return this.isContentPack() ? (@(_fixedAmount = 1) loc("trophy/chest_contents/all"))
      : this._getDescHeader
  }

  function needShowTextChances() {
    return this.itemDef?.tags?.showChances ?? false
  }

  function getDropChanceType() {
    if (!hasFeature("ShowDropChanceInTrophy"))
      return CHANCE_VIEW_TYPE.NONE

    if (this.needShowTextChances())
      return CHANCE_VIEW_TYPE.TEXT

    if (this.itemDef?.tags?.showDropChance ?? (this.getCategoryWeight().len() > 0))
      return CHANCE_VIEW_TYPE.ICON

    return CHANCE_VIEW_TYPE.NONE
  }

  function getContentMarkupForDescription(params) {
    let res = []
    let content = this.getContent()
    let hasContent = content.len() != 0
    if (!hasContent)
      return res

    params.receivedPrizes <- false
    params.dropChanceType <- this.getDropChanceType()
    let categoryWeightArray = this.getCategoryWeight()
    let categoryByItemsArray = this.getCategoryByItems()
    if (categoryWeightArray.len() > 0) {
      params.categoryWeight <- categoryWeightArray
      res.append(getPrizesStacksViewByWeight(content, this.getDescHeaderFunction(), clone params))
    }
    else if (categoryByItemsArray.len() > 0) {
      params.categoryByItems <- categoryByItemsArray
      res.append(getPrizesStacksViewByCategory(content, this.getDescHeaderFunction(), clone params))
    }
    else
      res.append(getPrizesStacksView(content, this.getDescHeaderFunction(), params))
    res.append(getPrizesListView([], { header = this.getHiddenItemsDesc() }))
    return res
  }

  function getLongDescriptionMarkup(params = null) {
    params = params ?? {}
    let prizeMarkupArray = [getPrizesListView([], { header = this.getTransferText() }),
      getPrizesListView([], { header = this.getMarketablePropDesc() }),
      (this.hasTimer() ? getPrizesListView([], { header = this.getCurExpireTimeText(), timerId = "expire_timer" }) : ""),
      this.getDescRecipesMarkup(clone params)
    ]

    prizeMarkupArray.extend(this.getContentMarkupForDescription(clone params))
    return "".join(prizeMarkupArray)
  }

  function _getDescHeader(fixedAmount = 1) {
    let locId = (fixedAmount > 1) ? "trophy/chest_contents/many" : "trophy/chest_contents"
    let headerText = loc(locId, { amount = colorize("commonTextColor", fixedAmount) })
    return colorize("grayOptionColor", headerText)
  }

  function getHiddenItemsDesc() {
    if (!this.getGenerator()?.hasHiddenItems || !this.getContent().len())
      return null
    return colorize("grayOptionColor", loc("trophy/chest_contents/other"))
  }

  function getHiddenTopPrizeParams() {
    return this.getGenerator()?.hiddenTopPrizeParams
  }

  function isHiddenTopPrize(prize) {
    return this.getGenerator()?.isHiddenTopPrize(prize) ?? false
  }

  function canPreview() {
    let content = this.getContent()
    return content.len() == 1 && content[0].item != null
      && findItemById(content[0].item)?.canPreview()
  }

  function doPreview() {
    findItemById(this.getContent()?[0]?.item)?.doPreview()
  }

  function doMainAction(cb, handler, params = null) {
    if (this.buy(cb, handler, params))
      return true
    if (!this.uids || !this.uids.len())
      return false

    if (this.openForGold(cb, params))
      return true

    return tryUseRecipes(this.getRelatedRecipes(), this, params)
  }

  getContentNoRecursion = @() this.getContent()

  getLocIdsListImpl = @() base.getLocIdsListImpl().__update({
    descReceipesListHeaderPrefix = this.descReceipesListHeaderPrefix
    msgBoxCantUse                = "msgBox/chestOpen/cant"
    msgBoxConfirm                = "msgBox/chestOpen/confirm"
    msgBoxSeveralConfirm         = "msgBox/chestOpen/several/confirm"
    openingRewardTitle           = "mainmenu/chestConsumed/title"
  })

  function getTableData() {
    if (this.getDropChanceType() != CHANCE_VIEW_TYPE.ICON)
      return null

    let markup = getPrizeChanceLegendMarkup()
    if (markup == "")
      return null

    return markup
  }

  canOpenForGold = @() this.itemDef?.tags.openForGoldByFeature != null
    && hasFeature(this.itemDef.tags.openForGoldByFeature)
  hasUsableRecipe = @() this.getRelatedRecipes().findvalue(@(recipe) recipe.isUsable) != null
  getOpenForGoldRecipe = @() this.getRelatedRecipes().findvalue(
    (@(recipe) recipe.getOpenCost(this) != null).bindenv(this))

  function openForGold(_cb, _params = null) {
    if (!this.canOpenForGold() || !this.isInventoryItem || this.amount == 0)
      return false

    let openForGoldRecipe = this.getOpenForGoldRecipe()
    if (openForGoldRecipe == null)
      return true

    let cost = openForGoldRecipe.getOpenCost(this)
    if (!checkBalanceMsgBox(cost))
      return true

    let item = this
    let text = warningIfGold(
      loc("item/openForGold/needMoneyQuestion", { itemName = this.getName(), cost = cost.getTextAccordingToBalance() }),
      cost)
    purchaseConfirmation("open_ches_for_gold", text, @() openForGoldRecipe.buyAllRequiredComponets(item))
    return true
  }

  function getCost(ignoreCanBuy = false) {
    if (this.canOpenForGold() && this.isInventoryItem && this.amount > 0)
      return this.getOpenForGoldRecipe()?.getOpenCost(this) ?? Cost()

    return base.getCost(ignoreCanBuy)
  }

  function getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes = false, timeText = "") {
    if (this.canOpenForGold())
      return loc($"{this.getLocIdsList().descReceipesListHeaderPrefix}item")

    return base.getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes, timeText)
  }

  function validateCategoryTypeArray(paramsArray) { 
    if (paramsArray.len() < 2)
      return paramsArray

    let prizeType = paramsArray[0]
    let weight = paramsArray[1]
    if (prizeType in inventoryItemTypeByTag
        || $"{prizeType}_{weight}" not in inventoryItemTypeByTag)
      return paramsArray

    let res = [$"{prizeType}_{weight}"]
    for (local i = 2; i < paramsArray.len(); i++)
      res.append(paramsArray[i])

    return res
  }

  function parseCategory(category) {
    let showTextChances = this.needShowTextChances()
    local paramsArray = category.split("_")
    paramsArray = this.validateCategoryTypeArray(paramsArray)
    if (paramsArray.len() < 2 && !showTextChances)
      return null

    let prizeType = paramsArray[0]
    let weight = showTextChances ? "none" : paramsArray[1]
    let rarity = showTextChances ? paramsArray?[1] : paramsArray?[2]
    let hasRarity = rarity != null
    return {
      prizeType,
      hasRarity,
      weight = hasRarity ? null : weight,
      rarity = hasRarity ? [{ rarity = rarity, weight = weight }] : null
    }
  }

  function getCategoryWeight() {
    if (this.categoryWeight != null)
      return this.categoryWeight

    this.categoryWeight = []
    if (this.itemDef?.tags.categoryWeight == null)
      return this.categoryWeight

    let cateoryWeightsArray = this.itemDef.tags % "categoryWeight"
    foreach (category in cateoryWeightsArray) {
      let parsedCategory = this.parseCategory(category)
      if (parsedCategory == null)
        continue

      let {prizeType, weight, rarity, hasRarity} = parsedCategory
      let categoryIdx = this.categoryWeight.findindex(@(c) c.prizeType == prizeType)
      if (categoryIdx == null) {
        this.categoryWeight.append(parsedCategory)
        continue
      }

      let categ = this.categoryWeight[categoryIdx]
      if (categ?.weight != null)  
        continue

      if (!hasRarity) {
        categ.weight = weight
        continue
      }
      categ.rarity.append(rarity[0])
    }
    return this.categoryWeight
  }

  function getCategoryByItems() {
    if (this.categoryByItems != null)
      return this.categoryByItems

    this.categoryByItems = []
    if (this.itemDef?.tags.category == null)
      return this.categoryByItems

    foreach (category in (this.itemDef.tags % "category")) {
      local paramsArray = category.split("_")
      if (paramsArray.len() < 2)
        continue

      let itemDefId = to_integer_safe(paramsArray[0])
      let categoryName = paramsArray[1]
      let categoryIdx = this.categoryByItems.findindex(@(c) c.categoryName == categoryName)
      if (categoryIdx == null) {
        this.categoryByItems.append({
          categoryName
          itemDefIds = [itemDefId]
        })
        continue
      }

      this.categoryByItems[categoryIdx].itemDefIds.append(itemDefId)
    }

    return this.categoryByItems
  }

  function getBaseDescription() {
    return this.getDescription()
  }
}

registerItemClass(Chest)

return {Chest}
