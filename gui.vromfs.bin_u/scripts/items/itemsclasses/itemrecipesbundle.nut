from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")
let { getItemGenerator } = require("%scripts/items/itemGeneratorsManager.nut")
let { getRequirementsMarkup, getRequirementsText } = require("%scripts/items/exchangeRecipes.nut")
let { Chest } = require("itemChest.nut")
let { registerItemClass } = require("%scripts/items/itemsTypeClasses.nut")

let RecipesBundle = class (Chest) {
  static iType = itemType.RECIPES_BUNDLE
  static name = "RecipesBundle"
  static defaultLocId = "recipes_bundle"
  typeIcon = "#ui/gameuiskin#item_type_blueprints.svg"

  constructor(itemDefDesc, itemDesc = null, slotData = null) {
    base.constructor(itemDefDesc, itemDesc, slotData)
    if (this.forceShowRewardReceiving)
      this.typeIcon = "#ui/gameuiskin#item_type_trophies.svg"
  }

  isDisassemble         = @() this.itemDef?.tags?.isDisassemble == true
  updateNameLoc         = @(locName) this.isDisassemble() ? loc("item/disassemble_header", { name = locName })
    : base.updateNameLoc(locName)

  canConsume            = @() false
  shouldShowAmount      = @(_count) false
  getMaxRecipesToShow   = @() 1
  getMarketablePropDesc = @() ""

  getGenerator          = @() getItemGenerator(this.id) //recipes bundle created by generator, so has same id
  getDescRecipesText    = @(params) getRequirementsText(this.getMyRecipes(), this, params)
  getDescRecipesMarkup  = @(params) getRequirementsMarkup(this.getMyRecipes(), this, params)

  function _getDescHeader(fixedAmount = 1) {
    let locId = (fixedAmount > 1) ? "trophy/recipe_result/many" : "trophy/recipe_result"
    let headerText = loc(locId, { amount = colorize("commonTextColor", fixedAmount) })
    return colorize("grayOptionColor", headerText)
  }

  function getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes = false, timeText = "") {
    if (!this.isDisassemble())
      return base.getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes, timeText)

    let locId = totalAmount == 1 ? "item/disassemble_recipes/single" : "item/disassemble_recipes"
    return loc(locId,
      {
        count = totalAmount
        countColored = colorize("activeTextColor", totalAmount)
        exampleCount = showAmount
      })
  }

  function getMainActionData(_isShort = false, _params = {}) {
    if (this.canAssemble())
      return {
        btnName = this.getAssembleButtonText()
        isInactive = this.hasReachedMaxAmount()
      }

    return null
  }

  getAssembleHeader     = @() this.isDisassemble() ? this.getName() : base.getAssembleHeader()
  getAssembleText       = @() this.isDisassemble() ? loc(this.getLocIdsList().disassemble) : loc(this.getLocIdsList().assemble)
  getAssembleButtonText = @() this.isDisassemble() ? loc(this.getLocIdsList().disassemble) : base.getAssembleButtonText()
  getConfirmMessageData = @(recipe, quantity) !this.isDisassemble() ? ItemExternal.getConfirmMessageData.call(this, recipe, quantity)
    : this.getEmptyConfirmMessageData().__update({
        text = loc(this.getLocIdsList().msgBoxConfirm)
        needRecipeMarkup = true
      })

  doMainAction          = @(cb, _handler, params = null) this.assemble(cb, params)

  getRewardListLocId = @() this.isDisassemble() ? "mainmenu/itemsList" : base.getRewardListLocId()

  getLocIdsListImpl = @() base.getLocIdsListImpl().__update({
    msgBoxCantUse = this.isDisassemble()
      ? "msgBox/disassembleItem/cant"
      : "msgBox/assembleItem/cant"
    msgBoxConfirm = "msgBox/disassembleItem/confirm"
    openingRewardTitle = "mainmenu/itemCreated/title"
  })
}

registerItemClass(RecipesBundle)
