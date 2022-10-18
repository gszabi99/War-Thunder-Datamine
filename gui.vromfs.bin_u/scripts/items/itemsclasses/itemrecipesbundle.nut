from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")
let ItemGenerators = require("%scripts/items/itemsClasses/itemGenerators.nut")
let ExchangeRecipes = require("%scripts/items/exchangeRecipes.nut")

::items_classes.RecipesBundle <- class extends ::items_classes.Chest {
  static iType = itemType.RECIPES_BUNDLE
  static defaultLocId = "recipes_bundle"
  static typeIcon = "#ui/gameuiskin#items_blueprint.png"

  isDisassemble         = @() this.itemDef?.tags?.isDisassemble == true
  updateNameLoc         = @(locName) isDisassemble() ? loc("item/disassemble_header", { name = locName })
    : base.updateNameLoc(locName)

  canConsume            = @() false
  shouldShowAmount      = @(_count) false
  getMaxRecipesToShow   = @() 1
  getMarketablePropDesc = @() ""

  getGenerator          = @() ItemGenerators.get(this.id) //recipes bundle created by generator, so has same id
  getDescRecipesText    = @(params) ExchangeRecipes.getRequirementsText(this.getMyRecipes(), this, params)
  getDescRecipesMarkup  = @(params) ExchangeRecipes.getRequirementsMarkup(this.getMyRecipes(), this, params)

  function _getDescHeader(fixedAmount = 1)
  {
    let locId = (fixedAmount > 1) ? "trophy/recipe_result/many" : "trophy/recipe_result"
    let headerText = loc(locId, { amount = colorize("commonTextColor", fixedAmount) })
    return colorize("grayOptionColor", headerText)
  }

  function getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes = false, timeText = "")
  {
    if (!isDisassemble())
      return base.getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes, timeText)

    let locId = totalAmount == 1 ? "item/disassemble_recipes/single" : "item/disassemble_recipes"
    return loc(locId,
      {
        count = totalAmount
        countColored = colorize("activeTextColor", totalAmount)
        exampleCount = showAmount
      })
  }

  function getMainActionData(_isShort = false, _params = {})
  {
    if (this.canAssemble())
      return {
        btnName = getAssembleButtonText()
        isInactive = this.hasReachedMaxAmount()
      }

    return null
  }

  getAssembleHeader     = @() isDisassemble() ? this.getName() : base.getAssembleHeader()
  getAssembleText       = @() isDisassemble() ? loc(this.getLocIdsList().disassemble) : loc(this.getLocIdsList().assemble)
  getAssembleButtonText = @() isDisassemble() ? loc(this.getLocIdsList().disassemble) : base.getAssembleButtonText()
  getConfirmMessageData = @(recipe) !isDisassemble() ? ItemExternal.getConfirmMessageData.call(this, recipe)
    : this.getEmptyConfirmMessageData().__update({
        text = loc(this.getLocIdsList().msgBoxConfirm)
        needRecipeMarkup = true
      })

  doMainAction          = @(cb, _handler, params = null) this.assemble(cb, params)

  getRewardListLocId = @() isDisassemble() ? "mainmenu/itemsList" : base.getRewardListLocId()

  getLocIdsListImpl = @() base.getLocIdsListImpl().__update({
    msgBoxCantUse = isDisassemble()
      ? "msgBox/disassembleItem/cant"
      : "msgBox/assembleItem/cant"
    msgBoxConfirm = "msgBox/disassembleItem/confirm"
    openingRewardTitle = "mainmenu/itemCreated/title"
  })
}