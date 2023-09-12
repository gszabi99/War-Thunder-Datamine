//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")


let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")
let ItemGenerators = require("%scripts/items/itemsClasses/itemGenerators.nut")
let ExchangeRecipes = require("%scripts/items/exchangeRecipes.nut")
let { getPrizeChanceLegendMarkup } = require("%scripts/items/prizeChance.nut")
let inventoryItemTypeByTag = require("%scripts/items/inventoryItemTypeByTag.nut")

::items_classes.Chest <- class extends ItemExternal {
  static iType = itemType.CHEST
  static defaultLocId = "chest"
  static typeIcon = "#ui/gameuiskin#item_type_trophies.svg"
  static isPreferMarkupDescInTooltip = true
  static userlogOpenLoc = "open_trophy"
  static hasTopRewardAsFirstItem = false
  static includeInRecentItems = false
  static descReceipesListHeaderPrefix = "chest/requires/"

  _isInitialized = false
  generator = null
  categoryWeight = null
  categoryByItems = null

  function getGenerator() {
    if (!this._isInitialized) {
      this._isInitialized = true
      let genIds = inventoryClient.getChestGeneratorItemdefIds(this.id)
      let genId = genIds.findvalue(@(genId) (ItemGenerators.get(genId)?.bundle ?? "") != "")
      this.generator = ItemGenerators.get(genId)
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
      ExchangeRecipes.tryUse(this.getRelatedRecipes(), this, params)
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
  isAllowSkipOpeningAnim    = @() this.itemDef?.tags.isAllowSkipOpeningAnim || ::is_dev_version
  getOpeningAnimId          = @() this.itemDef?.tags?.isLongOpenAnim ? "LONG" : "DEFAULT"
  getConfirmMessageData    = @(recipe) this.getEmptyConfirmMessageData().__update({
    text = loc(this.getLocIdsList().msgBoxConfirm, { itemName = colorize("activeTextColor", this.getName()) })
    headerRecipeMarkup = recipe.getHeaderRecipeMarkupText()
    needRecipeMarkup = recipe.isMultipleItems
  })

  function getContent() {
    return this.getGenerator()?.getContent() ?? []
  }

  getDescRecipesText    = @(params) ExchangeRecipes.getRequirementsText(this.getRelatedRecipes(), this, params)
  getDescRecipesMarkup  = @(params) ExchangeRecipes.getRequirementsMarkup(this.getRelatedRecipes(), this, params)

  function getDescription() {
    let params = { receivedPrizes = false }

    let content = this.getContent()
    local hasContent = content.len() != 0

    return "\n".join([
      this.getTransferText(),
      this.getMarketablePropDesc(),
      this.getCurExpireTimeText(),
      this.getDescRecipesText(params),
      (hasContent ? ::PrizesView.getPrizesListText(content, this.getDescHeaderFunction()) : ""),
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

  function getLongDescriptionMarkup(params = null) {
    params = params || {}
    params.receivedPrizes <- false
    params.needShowDropChance <- this.needShowDropChance()
    let content = this.getContent()
    let hasContent = content.len() != 0

    let prizeMarkupArray = [::PrizesView.getPrizesListView([], { header = this.getTransferText() }),
      ::PrizesView.getPrizesListView([], { header = this.getMarketablePropDesc() }),
      (this.hasTimer() ? ::PrizesView.getPrizesListView([], { header = this.getCurExpireTimeText(), timerId = "expire_timer" }) : ""),
      this.getDescRecipesMarkup(clone params)
    ]

    if (hasContent) {
      let categoryWeightArray = this.getCategoryWeight()
      let categoryByItemsArray = this.getCategoryByItems()
      if (params.needShowDropChance && categoryWeightArray.len() > 0) {
        params.categoryWeight <- categoryWeightArray
        prizeMarkupArray.append(::PrizesView.getPrizesStacksViewByWeight(content, this.getDescHeaderFunction(), clone params))
      }
      else if (categoryByItemsArray.len() > 0) {
        params.categoryByItems <- categoryByItemsArray
        prizeMarkupArray.append(::PrizesView.getPrizesStacksViewByCategory(content, this.getDescHeaderFunction(), clone params))
      }
      else
        prizeMarkupArray.append(::PrizesView.getPrizesStacksView(content, this.getDescHeaderFunction(), params))
      prizeMarkupArray.append(::PrizesView.getPrizesListView([], { header = this.getHiddenItemsDesc() }))
    }
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
      && ::ItemsManager.findItemById(content[0].item)?.canPreview()
  }

  function doPreview() {
    ::ItemsManager.findItemById(this.getContent()?[0]?.item)?.doPreview()
  }

  function doMainAction(cb, handler, params = null) {
    if (this.buy(cb, handler, params))
      return true
    if (!this.uids || !this.uids.len())
      return false

    if (this.openForGold(cb, params))
      return true

    return ExchangeRecipes.tryUse(this.getRelatedRecipes(), this, params)
  }

  getContentNoRecursion = @() this.getContent()

  getLocIdsListImpl = @() base.getLocIdsListImpl().__update({
    descReceipesListHeaderPrefix = this.descReceipesListHeaderPrefix
    msgBoxCantUse                = "msgBox/chestOpen/cant"
    msgBoxConfirm                = "msgBox/chestOpen/confirm"
    openingRewardTitle           = "mainmenu/chestConsumed/title"
  })

  needShowDropChance = @() hasFeature("ShowDropChanceInTrophy")
    && ((this.itemDef?.tags?.showDropChance ?? false)
      || this.getCategoryWeight().len() > 0)

  function getTableData() {
    if (!this.needShowDropChance())
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
    if (!::check_balance_msgBox(cost))
      return true

    let item = this
    let text = ::warningIfGold(
      loc("item/openForGold/needMoneyQuestion", { itemName = this.getName(), cost = cost.getTextAccordingToBalance() }),
      cost)
    scene_msg_box("open_ches_for_gold", null, text, [
      [ "yes", @() openForGoldRecipe.buyAllRequiredComponets(item) ],
      [ "no" ]
    ], "yes")

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

  function validateCategoryTypeArray(paramsArray) { //To correctly display weights for items that have "_" in their name
    if (paramsArray.len() <= 2)
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

  function getCategoryWeight() {
    if (this.categoryWeight != null)
      return this.categoryWeight

    this.categoryWeight = []
    if (this.itemDef?.tags.categoryWeight == null)
      return this.categoryWeight

    foreach (category in (this.itemDef.tags % "categoryWeight")) {
      local paramsArray = category.split("_")
      if (paramsArray.len() < 2)
        continue

      paramsArray = this.validateCategoryTypeArray(paramsArray)
      let prizeType = paramsArray[0]
      let weight = paramsArray[1]
      let rarity = paramsArray?[2]
      let hasRarity = rarity != null
      let categoryIdx = this.categoryWeight.findindex(@(c) c.prizeType == prizeType)
      if (categoryIdx == null) {
        this.categoryWeight.append({
          prizeType = prizeType
          rarity = hasRarity ? [{ rarity = rarity, weight = weight }] : null
          weight = hasRarity ? null : weight
        })
        continue
      }

      let categ = this.categoryWeight[categoryIdx]
      if (categ?.weight != null)  //All prizes of this type are filled by one group
        continue

      if (!hasRarity) {
        categ.__update({ weight = weight })
        continue
      }

      categ.__update({ rarity = categ.rarity.append({ rarity = rarity, weight = weight }) })
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
}
