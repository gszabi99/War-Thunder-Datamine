let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")
let ExchangeRecipes = require("%scripts/items/exchangeRecipes.nut")

::items_classes.Key <- class extends ItemExternal {
  static iType = itemType.KEY
  static defaultLocId = "key"
  static typeIcon = "#ui/gameuiskin#item_type_key"
  static descReceipesListHeaderPrefix = "key/requires/"

  function getLongDescriptionMarkup(params = null)
  {
    return base.getLongDescriptionMarkup()
      + ExchangeRecipes.getRequirementsMarkup(getRelatedRecipes(), this, params)
  }

  function canConsume()
  {
    return false
  }
}