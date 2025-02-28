from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")
let { getRequirementsMarkup } = require("%scripts/items/exchangeRecipes.nut")
let { registerItemClass } = require("%scripts/items/itemsTypeClasses.nut")

let Key = class (ItemExternal) {
  static iType = itemType.KEY
  static name = "Key"
  static defaultLocId = "key"
  static typeIcon = "#ui/gameuiskin#item_type_key.svg"
  static descReceipesListHeaderPrefix = "key/requires/"

  function getLongDescriptionMarkup(params = null) {
    return base.getLongDescriptionMarkup()
      + getRequirementsMarkup(this.getRelatedRecipes(), this, params)
  }

  function canConsume() {
    return false
  }
}

registerItemClass(Key)
