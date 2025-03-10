from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import shop_unit_research_status

let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")

function isUnitGift(unit) {
  return unit.gift != null
}

function canBuyUnit(unit) {
  if (isUnitGift(unit))  
    return false           

  if (unit.reqUnlock && !isUnlockOpened(unit.reqUnlock))
    return false

  let status = shop_unit_research_status(unit.name)
  return (0 != (status & ES_ITEM_STATUS_CAN_BUY)) && unit.isVisibleInShop()
}

function isUnitBought(unit) {
  return unit ? unit.isBought() : false
}

return {
  isUnitGift
  canBuyUnit
  isUnitBought
}