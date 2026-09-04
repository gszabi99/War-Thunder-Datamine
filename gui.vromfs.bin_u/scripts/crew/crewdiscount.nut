from "blkGetters" import get_warpoints_blk, get_price_blk
from "%sqstd/datablock.nut" import eachBlock
from "string" import format
from "%scripts/dagui_library.nut" import *

let { crewSpecTypes } = require("%scripts/crew/crewSpecType.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")
let { getDiscountByPath, generateDiscountInfo } = require("%scripts/discounts/discountUtils.nut")

function getCrewDiscountInfo(countryId = -1, idInCountry = -1) {
  if (countryId < 0 || idInCountry < 0)
    return {}

  let countrySlot = (getCrewsList()?[countryId] ?? {})
  let crewSlot = "crews" in countrySlot && idInCountry in countrySlot.crews ? countrySlot.crews[idInCountry] : {}

  let country = countrySlot.country
  let unitNames = (crewSlot?.trained ?? [])

  let packNames = []
  eachBlock(get_warpoints_blk()?.crewSkillPointsCost, @(_, n) packNames.append(n))

  let result = {}
  result.buyPoints <- getDiscountByPath(["skills", country, packNames], get_price_blk())
  foreach (t in crewSpecTypes.types)
    if (t.hasPrevType())
      result[t.specName] <- t.getDiscountValueByUnitNames(unitNames)
  return result
}

function getCrewMaxDiscountByInfo(discountInfo, includeBuyPoints = true) {
  local maxDiscount = 0
  foreach (name, discount in discountInfo)
    if (name != "buyPoints" || includeBuyPoints)
      maxDiscount = max(maxDiscount, discount)

  return maxDiscount
}

function getCrewDiscountsTooltipByInfo(discountInfo, showBuyPoints = true) {
  let maxDiscount = getCrewMaxDiscountByInfo(discountInfo, showBuyPoints).tostring()

  local numPositiveDiscounts = 0
  local positiveDiscountCrewSpecType = null
  foreach (t in crewSpecTypes.types)
    if (t.hasPrevType() && discountInfo[t.specName] > 0) {
      ++numPositiveDiscounts
      positiveDiscountCrewSpecType = t
    }

  if (numPositiveDiscounts == 0) {
    if (showBuyPoints && discountInfo.buyPoints > 0)
      return format(loc("discount/buyPoints/tooltip"), maxDiscount)
    else
      return ""
  }

  if (numPositiveDiscounts == 1)
    return positiveDiscountCrewSpecType.getDiscountTooltipByValue(maxDiscount)

  let table = {}
  foreach (t in crewSpecTypes.types)
    if (t.hasPrevType())
      table[t.getNameLocId()] <- discountInfo[t.specName]

  if (showBuyPoints)
    table["mainmenu/btnBuySkillPoints"] <- discountInfo.buyPoints

  return generateDiscountInfo(table, format(loc("discount/specialization/tooltip"), maxDiscount)).discountTooltip
}

return {
  getCrewDiscountInfo
  getCrewMaxDiscountByInfo
  getCrewDiscountsTooltipByInfo
}