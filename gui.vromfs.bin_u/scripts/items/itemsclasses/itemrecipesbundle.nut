local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")
local ItemGenerators = require("scripts/items/itemsClasses/itemGenerators.nut")
local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")

class ::items_classes.RecipesBundle extends ::items_classes.Chest {
  static iType = itemType.RECIPES_BUNDLE
  static defaultLocId = "recipes_bundle"
  static typeIcon = "#ui/gameuiskin#items_blueprint"
  static openingCaptionLocId = "mainmenu/itemCreated/title"

  isDisassemble         = @() itemDef?.tags?.isDisassemble == true
  updateNameLoc         = @(locName) isDisassemble() ? ::loc("item/disassemble_header", { name = locName })
    : base.updateNameLoc(locName)

  canConsume            = @() false
  shouldShowAmount      = @(count) false
  getMaxRecipesToShow   = @() 1
  getMarketablePropDesc = @() ""

  getGenerator          = @() ItemGenerators.get(id) //recipes bundle created by generator, so has same id
  getDescRecipesText    = @(params) ExchangeRecipes.getRequirementsText(getMyRecipes(), this, params)
  getDescRecipesMarkup  = @(params) ExchangeRecipes.getRequirementsMarkup(getMyRecipes(), this, params)

  function _getDescHeader(fixedAmount = 1)
  {
    local locId = (fixedAmount > 1) ? "trophy/recipe_result/many" : "trophy/recipe_result"
    local headerText = ::loc(locId, { amount = ::colorize("commonTextColor", fixedAmount) })
    return ::colorize("grayOptionColor", headerText)
  }

  function getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes = false, timeText = "")
  {
    if (!isDisassemble())
      return base.getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes, timeText)

    local locId = totalAmount == 1 ? "item/disassemble_recipes/single" : "item/disassemble_recipes"
    return ::loc(locId,
      {
        count = totalAmount
        countColored = ::colorize("activeTextColor", totalAmount)
        exampleCount = showAmount
      })
  }

  function getMainActionData(isShort = false)
  {
    if (canAssemble())
      return {
        btnName = getAssembleButtonText()
        isInactive = hasReachedMaxAmount()
      }

    return null
  }

  getAssembleHeader     = @() isDisassemble() ? getName() : base.getAssembleHeader()
  getAssembleText       = @() isDisassemble() ? ::loc(getLocIdsList().disassemble) : ::loc(getLocIdsList().assemble)
  getAssembleButtonText = @() isDisassemble() ? ::loc(getLocIdsList().disassemble) : base.getAssembleButtonText()
  getConfirmMessageData = @(recipe) !isDisassemble() ? ItemExternal.getConfirmMessageData.call(this, recipe)
    : getEmptyConfirmMessageData().__update({
        text = ::loc(getLocIdsList().msgBoxConfirm)
        needRecipeMarkup = true
      })

  doMainAction          = @(cb, handler, params = null) assemble(cb, params)

  getRewardListLocId = @() isDisassemble() ? "mainmenu/itemsList" : base.getRewardListLocId()

  getLocIdsListImpl = @() base.getLocIdsListImpl().__update({
    msgBoxCantUse = isDisassemble()
      ? "msgBox/disassembleItem/cant"
      : "msgBox/assembleItem/cant"
    msgBoxConfirm = "msgBox/disassembleItem/confirm"
  })
}