from "%scripts/unlocks/unlocksModule.nut" import isUnlockOpened
from "%scripts/popups/popups.nut" import addPopup
from "%scripts/unit/unitInfo.nut" import getUnitName
from "%scripts/dagui_library.nut" import *
from "%globalScripts/shopItemConsts.nut" import *
from "%scripts/dagui_natives.nut" import shop_unit_research_status

function isUnitGift(unit) {
  return unit.gift != null
}

function canBuyUnitEvenNotInShop(unit) {
  if (isUnitGift(unit))  
    return false           

  if (unit.reqUnlock && !isUnlockOpened(unit.reqUnlock))
    return false

  let status = shop_unit_research_status(unit.name)
  return (status & ES_ITEM_STATUS_CAN_BUY) != 0
}

function canBuyUnit(unit) {
  return canBuyUnitEvenNotInShop(unit) && unit.isVisibleInShop()
}

function isUnitBought(unit) {
  return unit ? unit.isBought() : false
}

function canSpendGoldOnUnitWithPopup(unit) {
  if (unit.unitType.canSpendGold())
    return true

  addPopup(getUnitName(unit), loc("msgbox/unitTypeRestrictFromSpendGold"),
    null, null, null, "cant_spend_gold_on_unit")
  return false
}

return freeze({
  isUnitGift
  canBuyUnit
  canBuyUnitEvenNotInShop
  isUnitBought
  canSpendGoldOnUnitWithPopup
})