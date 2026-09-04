from "%sqStdLibs/helpers/enums.nut" import enumsAddTypes, enumsGetCachedType
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem, MAX_SPARE_AMOUNT
from "%scripts/dagui_natives.nut" import get_spare_aircrafts_count

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

    canBuy = function(_unit, _item) { return false }
    getAmount = function(_unit, _item) { return 0 }
    getMaxAmount = function(_unit, _item) { return 0 }

    getUnlockCost = function(_unit, _item) { return Cost() }
    getCost = function(_unit, _item) { return Cost() }
    getScoreCostText = function(_unit, _item, _needToShowFullCost) { return "" }

    purchase = function() {}
    canPurchase = function() { return false }
  }
}

enumsAddTypes(weaponryTypes, { UNKNOWN = {} }, null, "typeName")

let getSpareAvailableAmount = @(unit) MAX_SPARE_AMOUNT - get_spare_aircrafts_count(unit.name)



let getWeaponryGroupHeader = @(unit) (unit.isAir() || unit.isHelicopter()) ? loc("options/secondary_weapons")
  : unit.isHuman() ? loc("options/infantry_presets")
  : loc("options/additional_weapons")

function getUpgradeTypeByItem(item) {
  if (!("type" in item))
    return weaponryTypes.UNKNOWN

  return enumsGetCachedType("type", item.type, weaponryTypes.cache.byType, weaponryTypes, weaponryTypes.UNKNOWN)
}

function addEnumWeaponryTypes(types) {
  enumsAddTypes(weaponryTypes, types, null, "typeName")
}

return {
  addEnumWeaponryTypes
  getUpgradeTypeByItem
  getWeaponryGroupHeader
  getSpareAvailableAmount
}
