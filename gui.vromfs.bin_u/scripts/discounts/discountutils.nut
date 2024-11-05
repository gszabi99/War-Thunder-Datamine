from "%scripts/dagui_natives.nut" import item_get_personal_discount_for_mod, shop_is_weapon_purchased, item_get_personal_discount_for_weapon
from "%scripts/dagui_library.nut" import *
let { getBlkByPathArray, eachBlock } = require("%sqstd/datablock.nut")
let personalDiscount = require("%scripts/discounts/personalDiscount.nut")
let { shopIsModificationPurchased } = require("chardResearch")
let { get_price_blk } = require("blkGetters")
let { isUnitGroup } = require("%scripts/unit/unitStatus.nut")
let { showCurBonus } = require("%scripts/bonusModule.nut")

function invokeMultiArray(multiArray, currentArray, currentIndex, invokeCallback) {
  if (currentIndex == multiArray.len()) {
    invokeCallback(currentArray)
    return
  }
  if (type(multiArray[currentIndex]) == "array") {
    foreach (name in multiArray[currentIndex]) {
      currentArray.append(name)
      invokeMultiArray(multiArray, currentArray, currentIndex + 1, invokeCallback)
      currentArray.pop()
    }
  }
  else {
    currentArray.append(multiArray[currentIndex])
    invokeMultiArray(multiArray, currentArray, currentIndex + 1, invokeCallback)
    currentArray.pop()
  }
}

//you can use array in any path part - in result will be max discount from them.
::getDiscountByPath <- function getDiscountByPath(path, blk = null, _idx = 0) {
  if (blk == null)
    blk = get_price_blk()
  let result = {
    maxDiscount = 0
  }
  invokeMultiArray(path, [], 0, function (arr) {
    let block = getBlkByPathArray(arr, blk)
    let discountValue = getTblValue("discount", block, 0)
    result.maxDiscount = max(result.maxDiscount, discountValue)
    local personalDiscountValue = personalDiscount.getDiscountByPath(arr)
    result.maxDiscount = max(result.maxDiscount, personalDiscountValue)
  })
  return result.maxDiscount
}

function getMaxWeaponryDiscountByUnitName(unitName, discountTypes = null) {
  let unitTable = get_price_blk()?.aircrafts[unitName]
  if (!unitTable)
    return 0

  local discount = 0
  discountTypes = discountTypes ?? ["weapons", "mods", "spare"]
  if (discountTypes.contains("weapons"))
    eachBlock(unitTable?.weapons, function(table, name) {
      if (!shop_is_weapon_purchased(unitName, name))
        discount = max(discount,
          getTblValue("discount", table, 0),
          item_get_personal_discount_for_weapon(unitName, name))
    })

  if (discountTypes.contains("mods"))
    eachBlock(unitTable?.mods, function(table, name) {
      if (!shopIsModificationPurchased(unitName, name))
        discount = max(discount,
          getTblValue("discount", table, 0),
          item_get_personal_discount_for_mod(unitName, name))
    })

  if (discountTypes.contains("spare") && unitTable?.spare)
    discount = max(discount, getTblValue("discount", unitTable.spare, 0))

  return discount
}

//You can use array of airNames - in result will be max discount from them.
function showAirDiscount(obj, airName, group = null, groupValue = null, fullUpdate = false) {
  let path = ["aircrafts", airName]
  if (group)
    path.append(group)
  if (groupValue)
    path.append(groupValue)
  let discount = ::getDiscountByPath(path)
  showCurBonus(obj, discount, group ? group : "buy", true, fullUpdate)
}

function showUnitDiscount(obj, unitOrGroup) {
  let discount = isUnitGroup(unitOrGroup)
    ? ::g_discount.getGroupDiscount(unitOrGroup.airsGroup)
    : ::g_discount.getUnitDiscount(unitOrGroup)
  showCurBonus(obj, discount, "buy")
}

function showDiscount(obj, name, group = null, groupValue = null, fullUpdate = false) {
  let path = [name]
  if (group)
    path.append(group)
  if (groupValue)
    path.append(groupValue)
  let discount = ::getDiscountByPath(path)
  showCurBonus(obj, discount, name, true, fullUpdate)
}

return {
  showUnitDiscount
  showDiscount
  getMaxWeaponryDiscountByUnitName
  showAirDiscount
}