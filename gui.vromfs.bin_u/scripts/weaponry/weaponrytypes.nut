from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem

let { enumsAddTypes, enumsGetCachedType } = require("%sqStdLibs/helpers/enums.nut")
let { dynamic_content } = require("%sqstd/analyzer.nut")
let { Cost } = require("%scripts/money.nut")

let weaponryTypes = {
  types = []
  cache = {
    byType = {}
  }

  template = {
    type = weaponsItem.unknown
    isSpendable = false
    isPremium = false

    getLocName = function(_unit, _item, _limitedName = false) { return "" }
    getHeader = @(_unit) ""

    canBuy = function(_unit, _item) { return false }
    getAmount = function(_unit, _item) { return 0 }
    getMaxAmount = function(_unit, _item) { return 0 }

    getUnlockCost = function(_unit, _item) { return Cost() }
    getCost = function(_unit, _item) { return Cost() }
    getScoreCostText = function(_unit, _item) { return "" }

    purchase = function() {}
    canPurchase = function() { return false }
  }
}

function getUpgradeTypeByItem(item) {
  if (!("type" in item))
    return weaponryTypes.UNKNOWN

  return enumsGetCachedType("type", item.type, weaponryTypes.cache.byType, weaponryTypes, weaponryTypes.UNKNOWN)
}

function addEnumWeaponryTypes(types) {
  enumsAddTypes(weaponryTypes, types, null, "typeName")
}

return {
  weaponryTypes = dynamic_content(weaponryTypes)
  addEnumWeaponryTypes
  getUpgradeTypeByItem
}
