from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")
let ExchangeRecipes = require("%scripts/items/exchangeRecipes.nut")

::items_classes.Key <- class extends ItemExternal {
  static iType = itemType.KEY
  static defaultLocId = "key"
  static typeIcon = "#ui/gameuiskin#item_type_key.svg"
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