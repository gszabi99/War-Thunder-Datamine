from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let DataBlock  = require("DataBlock")
let { round } = require("math")
let { set_rnd_seed } = require("dagor.random")
let { get_time_msec, ref_time_ticks } = require("dagor.time")
let { split_by_chars } = require("string")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { ExchangeRecipes, hasFakeRecipesInList, saveMarkedRecipes } = require("%scripts/items/exchangeRecipes.nut")
let time = require("%scripts/time.nut")
let workshop = require("%scripts/items/workshop/workshop.nut")
let ItemLifetimeModifier = require("%scripts/items/itemLifetimeModifier.nut")
let { get_game_settings_blk } = require("blkGetters")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")

let collection = {}

let ItemGenerator = class {
  id = -1
  genType = ""
  exchange = null
  bundle  = null
  timestamp = ""
  rawCraftTime = 0
  lifetimeModifier = null

  isPack = false
  hasHiddenItems = false
  hiddenTopPrizeParams = null
  tags = null

  _contentUnpacked = null

  constructor(itemDefDesc) {
    this.id = itemDefDesc.itemdefid
    this.genType = itemDefDesc?.type ?? ""
    this.exchange = itemDefDesc?.exchange ?? ""
    this.bundle   = itemDefDesc?.bundle ?? ""
    this.isPack   = isInArray(this.genType, [ "bundle", "delayedexchange" ])
    this.tags     = itemDefDesc?.tags
    this.timestamp = itemDefDesc?.Timestamp ?? ""
    this.rawCraftTime = time.getSecondsFromTemplate(itemDefDesc?.lifetime ?? "")
    let lifetimeModifierText = itemDefDesc?.lifetime_modifier
    if (!u.isEmpty(lifetimeModifierText))
      this.lifetimeModifier = ItemLifetimeModifier(lifetimeModifierText)
  }

  _exchangeRecipes = null
  _exchangeRecipesUpdateTime = 0

  function getCraftTime() {
    local result = this.rawCraftTime
    if (this.lifetimeModifier != null) {
      let mul = this.lifetimeModifier.calculate()
      result = max(1, round(result * mul))
    }
    return result
  }

  function getRecipes(needUpdateRecipesList = true) {
    if (!this._exchangeRecipes
      || (needUpdateRecipesList && this._exchangeRecipesUpdateTime <= ::ItemsManager.getExtInventoryUpdateTime())) {
      let generatorId = this.id
      let generatorCraftTime = this.getCraftTime()
      let parsedRecipes = inventoryClient.parseRecipesString(this.exchange)
      let isDisassemble = this.tags?.isDisassemble ?? false
      let localizationPresetName = this.tags?.customLocalizationPreset
      let effectOnStartCraftPresetName = this.tags?.effectOnStartCraft
      let allowableComponents = this.getAllowableRecipeComponents()
      let showRecipeAsProduct = this.tags?.showRecipeAsProduct
      let shouldSkipMsgBox = !!this.tags?.shouldSkipMsgBox
      let needSaveMarkRecipe = this.tags?.needSaveMarkRecipe ?? true
      this._exchangeRecipes = parsedRecipes.map(@(parsedRecipe) ExchangeRecipes({
         parsedRecipe
         generatorId
         craftTime = generatorCraftTime
         isDisassemble
         localizationPresetName
         effectOnStartCraftPresetName
         allowableComponents
         showRecipeAsProduct
         shouldSkipMsgBox
         needSaveMarkRecipe
      }))

      // Adding additional recipes
      local hasAdditionalRecipes = false
      let itemBlk = workshop.getItemAdditionalRecipesById(this.id)?[0]
      if (itemBlk != null) {
        foreach (paramName in ["fakeRecipe", "trueRecipe"])
          foreach (itemdefId in itemBlk % paramName) {
            ::ItemsManager.findItemById(itemdefId) // calls pending generators list update
            let gen = collection?[itemdefId]
            let additionalParsedRecipes = gen ? inventoryClient.parseRecipesString(gen.exchange) : []
            this._exchangeRecipes.extend(additionalParsedRecipes.map(@(pr) ExchangeRecipes({
              parsedRecipe = pr
              generatorId = gen.id
              craftTime = gen.getCraftTime()
              isFake = paramName != "trueRecipe"
              isDisassemble = isDisassemble
              localizationPresetName = gen?.tags?.customLocalizationPreset ?? localizationPresetName
              effectOnStartCraftPresetName = gen?.tags?.effectOnStartCraft
              allowableComponents = gen?.getAllowableRecipeComponents() ?? allowableComponents
              showRecipeAsProduct = gen?.tags?.showRecipeAsProduct
              shouldSkipMsgBox = !!gen?.tags?.shouldSkipMsgBox
              needSaveMarkRecipe = gen?.tags.needSaveMarkRecipe ?? true
            })))
            hasAdditionalRecipes = hasAdditionalRecipes || additionalParsedRecipes.len() > 0
          }
      }
      if (hasAdditionalRecipes) {
        local minIdx = this._exchangeRecipes[0].idx
        set_rnd_seed(userIdInt64.value + this.id)
        this._exchangeRecipes = u.shuffle(this._exchangeRecipes)
        foreach (recipe in this._exchangeRecipes)
          recipe.idx = minIdx++
        set_rnd_seed(ref_time_ticks())
      }

      this._exchangeRecipesUpdateTime = get_time_msec()
    }
    return this._exchangeRecipes.filter(@(ec) ec.isEnabled())
  }

  function getUsableRecipes() {
    let showAllowableRecipesOnly = this.tags?.showAllowableRecipesOnly ?? false
    let recipes = this.getRecipes() ?? []
    if (!showAllowableRecipesOnly)
      return recipes

    local filteredRecipes = []
    local maxMultiComponentCount = 0
    foreach (recipe in recipes) {
      if (!recipe.isUsable)
        continue
      let multiComponentCount = recipe.components.filter(@(c) c.curQuantity > c.reqQuantity).len()
      if (multiComponentCount < maxMultiComponentCount)
        continue
      if (multiComponentCount == maxMultiComponentCount) {
        filteredRecipes.append(recipe)
        continue
      }

      maxMultiComponentCount = multiComponentCount
      filteredRecipes = [recipe]
    }
    return filteredRecipes
  }

  function getRecipesWithComponent(componentItemdefId) {
    return this.getRecipes().filter(@(ec) ec.hasComponent(componentItemdefId))
  }

  function _unpackContent(contentRank = null, fromGenId = null) {
    this._contentUnpacked = []
    let parsedBundles = inventoryClient.parseRecipesString(this.bundle)
    let trophyWeightsBlk = get_game_settings_blk()?.visualizationTrophyWeights
    let trophyWeightsBlockCount = trophyWeightsBlk?.blockCount() ?? 0
    foreach (set in parsedBundles)
      foreach (cfg in set.components) {
        let item = ::ItemsManager.findItemById(cfg.itemdefid)
        let generator = !item ? collection?[cfg.itemdefid] : null
        let rank = contentRank != null ? min(cfg.quantity, contentRank) : cfg.quantity
        if (item) {
          if (item.isHiddenItem())
            continue
          let b = DataBlock()
          b.item =  item.id
          b.rank = rank
          b.fromGenId = fromGenId ?? this.id
          if (this.tags?.showFreq)
            b.dropChance = this.tags.showFreq.tointeger() / 100.0
          if (trophyWeightsBlk != null && trophyWeightsBlockCount > 0
            && rank <= trophyWeightsBlockCount) {
            let weightBlock = trophyWeightsBlk.getBlock(rank - 1)
            b.weight = weightBlock.getBlockName()
          }
          this._contentUnpacked.append(b)
        }
        else if (generator) {
          let content = generator.getContent(rank, fromGenId ?? cfg.itemdefid)
          this.hasHiddenItems = this.hasHiddenItems || generator.hasHiddenItems
          this.hiddenTopPrizeParams = this.hiddenTopPrizeParams || generator.hiddenTopPrizeParams
          this._contentUnpacked.extend(content)
        }
      }

    let isBundleHidden = !this._contentUnpacked.len()
    this.hasHiddenItems = this.hasHiddenItems || isBundleHidden
    this.hiddenTopPrizeParams = isBundleHidden ? this.tags : this.hiddenTopPrizeParams
  }

  function getContent(contentRank = null, fromGenId = null) {
    if (!this._contentUnpacked)
      this._unpackContent(contentRank, fromGenId)
    return this._contentUnpacked
  }

  function isHiddenTopPrize(prize) {
    let content = this.getContent()
    if (!this.hasHiddenItems || !prize?.item)
      return false
    foreach (v in content)
      if (prize.item == v?.item)
        return false
    return true
  }

  function getRecipeByUid(uid) {
    return u.search(this.getRecipes(), @(r) r.uid == uid)
  }

  function markAllRecipes() {
    let recipes = this.getRecipes()
    if (!hasFakeRecipesInList(recipes))
      return

    let markedRecipes = []
    foreach (recipe in recipes)
      if (recipe.markRecipe(false, false))
        markedRecipes.append(recipe.uid)

    saveMarkedRecipes(markedRecipes)
  }

  isDelayedxchange = @() this.genType == "delayedexchange"
  getContentNoRecursion = @() this.getContent()

  function getAllowableRecipeComponents() {
    let allowableItemsForRecipes = this.tags?.allowableItemsForRecipes
    if (allowableItemsForRecipes == null)
      return null

    let allowableItems = {}
    foreach (itemId in split_by_chars(allowableItemsForRecipes, "_"))
      allowableItems[to_integer_safe(itemId, itemId, false)] <- true

    return allowableItems
  }
}

let get = function(itemdefId) {
  ::ItemsManager.findItemById(itemdefId) // calls pending generators list update
  return collection?[itemdefId]
}

let add = function(itemDefDesc) {
  if (itemDefDesc?.Timestamp != collection?[itemDefDesc.itemdefid]?.timestamp)
    collection[itemDefDesc.itemdefid] <- ItemGenerator(itemDefDesc)
}

let findGenByReceptUid = @(recipeUid)
  u.search(collection, @(gen) u.search(gen.getRecipes(false),
    @(recipe) recipe.uid == recipeUid
     && (recipe.isDisassemble || !gen.isDelayedxchange())) != null) //!!!FIX ME There should be no two recipes with the same uid.

return {
  get = get
  add = add
  findGenByReceptUid = findGenByReceptUid
}
