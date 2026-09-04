from "%sqStdLibs/helpers/u.nut" import find_in_array
from "%scripts/dagui_library.nut" import *

let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { maxCountryRank } = require("%scripts/ranks.nut")

let discountPostfixArray = ["_premium", ""]

function addDiscountDescriptionAircrafts(blk, category, items) {
  if (blk == null)
    return
  for (local i = 0; i < blk.paramCount(); ++i) {
    if (blk.getParamValue(i) == 0)
      continue
    let aircraftName = blk.getParamName(i)
    items.append({
      category = category
      type = "aircraft"
      discountValue = blk.getParamValue(i)
      aircraftName = aircraftName
      aircraftSortIndex = i
    })
  }
}

function parseDiscountDescriptionCountryRank(blk, category) {
  let items = {
    country_premium     = []
    country             = []
    countryRank_premium = []
    countryRank         = []
    rank_premium        = []
    rank                = []
  }
  if (blk == null)
    return items
  local needFillRanks = true
  foreach (countryName in shopCountriesList) {
    foreach (postfix in discountPostfixArray) {
      let cName = $"{countryName}{postfix}"
      if ((cName in blk) && blk[cName] != 0)
        items[$"country{postfix}"].append({
          paramName = cName
          category = category
          
          
          type = $"all{postfix}"
          discountValue = blk[cName]
          countryName = countryName
        })
      let maxRank = maxCountryRank.get()
      for (local i = 1; i <= maxRank; ++i) {
        local name = $"{countryName}_rank{i}{postfix}"
        if ((name in blk) && blk[name] != 0)
          items[$"countryRank{postfix}"].append({
            paramName = name
            category = category
            
            
            type = $"rank{postfix}"
            discountValue = blk[name]
            rank = i
            countryName = countryName
          })
        if (!needFillRanks)
          continue

        name = $"rank{i}{postfix}"
        if ((name not in blk) || blk[name] == 0)
          continue
        items[$"rank{postfix}"].append({
          paramName = name
          category = category
          type = $"rank{postfix}"
          discountValue = blk[name]
          rank = i
        })
      }
      needFillRanks = false
    }
  }
  return items
}

function addDiscountDescriptionAll(blk, category, items) {
  if (blk == null)
    return
  foreach (postfix in discountPostfixArray) {
    let name = $"all{postfix}"
    if ((name not in blk) || blk[name] == 0)
      continue
    items.append({
      paramName = name
      category = category
      type = name
      discountValue = blk[name]
    })
  }
}

function addDiscountDescriptionEntitlements(blk, category, items) {
  if (blk == null || category != "entitlements")
    return
  for (local i = 0; i < blk.paramCount(); ++i)
    items.append({
      category = category
      entitlementName = blk.getParamName(i)
      discountValue = blk.getParamValue(i)
    })
}

function parseDiscountDescriptionCategory(blk) {
  if (blk == null)
    return []
  let category = blk.getBlockName()
  
  let items = []
  addDiscountDescriptionAircrafts(blk?.aircrafts, category, items)
  let descriptionCountryRank = parseDiscountDescriptionCountryRank(blk, category)

  items.extend(descriptionCountryRank.countryRank_premium)
  items.extend(descriptionCountryRank.countryRank)
  items.extend(descriptionCountryRank.rank_premium)
  items.extend(descriptionCountryRank.rank)
  items.extend(descriptionCountryRank.country_premium)
  items.extend(descriptionCountryRank.country)
  addDiscountDescriptionAll(blk, category, items)
  addDiscountDescriptionEntitlements(blk, category, items)
  return items
}








function sortDiscountDescriptionItems(items, sortData) {
  if (sortData == null)
    return
  items.sort(function (item1, item2) {
    if (item1.category != item2.category)
      return sortData[item1.category].categoryIndex <=> sortData[item2.category].categoryIndex

    let isTypeAircraft1 = item1.type == "aircraft"
    let isTypeAircraft2 = item2.type == "aircraft"
    if (isTypeAircraft1 != isTypeAircraft2)
      return isTypeAircraft1 ? -1 : 1
    if (isTypeAircraft1)
      return item1.aircraftSortIndex <=> item2.aircraftSortIndex
    let paramsOrder = sortData[item1.category].paramsOrder
    let index1 = find_in_array(paramsOrder, item1.paramName)
    let index2 = find_in_array(paramsOrder, item2.paramName)
    return index1 <=> index2
  })
}





function createDiscountDescriptionSortData(blk) {
  if (blk == null)
    return null
  let sortData = {}
  for (local i = 0; i < blk.blockCount(); ++i) {
    let discountCategoryBlk = blk.getBlock(i)
    let paramsOrder = []
    for (local j = 0; j < discountCategoryBlk.paramCount(); ++j)
      paramsOrder.append(discountCategoryBlk.getParamName(j))
    sortData[discountCategoryBlk.getBlockName()] <- {
      categoryIndex = i
      paramsOrder = paramsOrder
    }
  }
  return sortData
}




function parseDiscountDescription(blk) {
  if (blk == null)
    return []
  let items = []
  for (local i = 0; i < blk.blockCount(); ++i)
    items.extend(parseDiscountDescriptionCategory(blk.getBlock(i)))
  return items
}

return {
  sortDiscountDescriptionItems
  createDiscountDescriptionSortData
  parseDiscountDescription
}
