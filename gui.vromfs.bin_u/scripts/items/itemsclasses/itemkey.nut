from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")
let ExchangeRecipes = require("%scripts/items/exchangeRecipes.nut")

::items_classes.Key <- class (ItemExternal) {
  static iType = itemType.KEY
  static defaultLocId = "key"
  static typeIcon = "#ui/gameuiskin#item_type_key.svg"
  static descReceipesListHeaderPrefix = "key/requires/"

  function getLongDescriptionMarkup(params = null) {
    return base.getLongDescriptionMarkup()
      + ExchangeRecipes.getRequirementsMarkup(this.getRelatedRecipes(), this, params)
  }

  function canConsume() {
    return false
  }
}