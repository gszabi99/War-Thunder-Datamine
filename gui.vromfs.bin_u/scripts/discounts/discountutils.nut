from "%scripts/dagui_natives.nut" import item_get_personal_discount_for_mod, shop_is_weapon_purchased, item_get_personal_discount_for_weapon
from "%scripts/dagui_library.nut" import *
let { getBlkByPathArray, eachBlock } = require("%sqstd/datablock.nut")
let personalDiscount = require("%scripts/discounts/personalDiscount.nut")
let { shopIsModificationPurchased } = require("chardResearch")
let { get_price_blk } = require("blkGetters")
let { format } = require("string")
let { isUnitGroup } = require("%scripts/unit/unitStatus.nut")
let { showCurBonus } = require("%scripts/bonusModule.nut")
let { getUnitDiscount, getGroupDiscount } = require("%scripts/discounts/discountsState.nut")

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


function getDiscountByPath(path, blk = null, _idx = 0) {
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


function showAirDiscount(obj, airName, group = null, groupValue = null, fullUpdate = false) {
  let path = ["aircrafts", airName]
  if (group)
    path.append(group)
  if (groupValue)
    path.append(groupValue)
  let discount = getDiscountByPath(path)
  showCurBonus(obj, discount, group ? group : "buy", true, fullUpdate)
}

function showUnitDiscount(obj, unitOrGroup) {
  let discount = isUnitGroup(unitOrGroup)
    ? getGroupDiscount(unitOrGroup.airsGroup)
    : getUnitDiscount(unitOrGroup)
  showCurBonus(obj, discount, "buy")
}

function showDiscount(obj, name, group = null, groupValue = null, fullUpdate = false) {
  let path = [name]
  if (group)
    path.append(group)
  if (groupValue)
    path.append(groupValue)
  let discount = getDiscountByPath(path)
  showCurBonus(obj, discount, name, true, fullUpdate)
}

function generateDiscountInfo(discountsTable, headerLocId = "") {
  local maxDiscount = 0
  let headerText = "".concat(loc(headerLocId == "" ? "discount/notification" : headerLocId), "\n")
  local discountText = ""
  foreach (locId, discount in discountsTable) {
    if (discount <= 0)
      continue

    discountText = "".concat(discountText, loc("discount/list_string", { itemName = loc(locId), discount = discount }), "\n")
    maxDiscount = max(maxDiscount, discount)
  }

  if (discountsTable.len() > 20)
    discountText = format(loc("discount/buy/tooltip"), maxDiscount.tostring())

  if (discountText == "")
    return {}

  discountText = "".concat(headerText, discountText)

  return { maxDiscount = maxDiscount, discountTooltip = discountText }
}

return {
  showUnitDiscount
  showDiscount
  getMaxWeaponryDiscountByUnitName
  showAirDiscount
  getDiscountByPath
  generateDiscountInfo
}