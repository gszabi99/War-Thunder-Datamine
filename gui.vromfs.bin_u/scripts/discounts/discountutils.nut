local { get_blk_by_path_array } = require("sqStdLibs/helpers/datablockUtils.nut")
local personalDiscount = require("scripts/discounts/personalDiscount.nut")
local { eachBlock } = require("std/datablock.nut")

//you can use array in any path part - in result will be max discount from them.
::getDiscountByPath <- function getDiscountByPath(path, blk = null, idx = 0)
{
  if (blk == null)
    blk = get_price_blk()
  local result = {
    maxDiscount = 0
  }
  ::invoke_multi_array(path, function (arr) {
    local block = get_blk_by_path_array(arr, blk)
    local discountValue = ::getTblValue("discount", block, 0)
    result.maxDiscount = ::max(result.maxDiscount, discountValue)
    local personalDiscountValue = personalDiscount.getDiscountByPath(arr)
    result.maxDiscount = ::max(result.maxDiscount, personalDiscountValue)
  })
  return result.maxDiscount
}

::get_max_weaponry_discount_by_unitName <- function get_max_weaponry_discount_by_unitName(unitName, discountTypes = null)
{
  local unitTable = ::get_price_blk()?.aircrafts[unitName]
  if (!unitTable)
    return 0

  local discount = 0
  discountTypes = discountTypes ?? ["weapons", "mods", "spare"]
  if (discountTypes.contains("weapons"))
    eachBlock(unitTable?.weapons, function(table, name) {
      if (!::shop_is_weapon_purchased(unitName, name))
        discount = ::max(discount,
          ::getTblValue("discount", table, 0),
          ::item_get_personal_discount_for_weapon(unitName, name))
    })

  if (discountTypes.contains("mods"))
    eachBlock(unitTable?.mods, function(table, name) {
      if (!::shop_is_modification_purchased(unitName, name))
        discount = ::max(discount,
          ::getTblValue("discount", table, 0),
          ::item_get_personal_discount_for_mod(unitName, name))
    })

  if (discountTypes.contains("spare") && unitTable?.spare)
    discount = ::max(discount, ::getTblValue("discount", unitTable.spare, 0))

  return discount
}

//You can use array of airNames - in result will be max discount from them.
::showAirDiscount <- function showAirDiscount(obj, airName, group=null, groupValue=null, fullUpdate=false)
{
  local path = ["aircrafts", airName]
  if (group)
    path.append(group)
  if (groupValue)
    path.append(groupValue)
  local discount = getDiscountByPath(path)
  ::showCurBonus(obj, discount, group? group : "buy", true, fullUpdate)
}

::showUnitDiscount <- function showUnitDiscount(obj, unitOrGroup)
{
  local discount = ::isUnitGroup(unitOrGroup)
    ? ::g_discount.getGroupDiscount(unitOrGroup.airsGroup)
    : ::g_discount.getUnitDiscount(unitOrGroup)
  ::showCurBonus(obj, discount, "buy")
}

::showDiscount <- function showDiscount(obj, name, group=null, groupValue=null, fullUpdate=false)
{
  local path = [name]
  if (group)
    path.append(group)
  if (groupValue)
    path.append(groupValue)
  local discount = getDiscountByPath(path)
  ::showCurBonus(obj, discount, name, true, fullUpdate)
}
