from "%scripts/dagui_library.nut" import *

let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { find_in_array } = require("%sqStdLibs/helpers/u.nut")

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
          // Same as for "all" discounts
          // because of same localization strings.
          type = $"all{postfix}"
          discountValue = blk[cName]
          countryName = countryName
        })
      for (local i = 1; i <= ::max_country_rank; ++i) {
        local name = $"{countryName}_rank{i}{postfix}"
        if ((name in blk) && blk[name] != 0)
          items[$"countryRank{postfix}"].append({
            paramName = name
            category = category
            // Same as for rank-only discounts
            // because of same localization strings.
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
  // Order corresponds to discount priorities.
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

/**
* Sorts description items with following rules:
* First items are sorted by categories. Same order
* as in blk. Then go all aircraft items sorted again
* as in discount item blk. Last go all non-aircraft
* items with order from blk.
*/
function sortDiscountDescriptionItems(items, sortData) {
  if (sortData == null)
    return
  items.sort(function (item1, item2) {
    if (item1.category != item2.category) {
      let catSortData1 = sortData[item1.category]
      let catSortData2 = sortData[item2.category]
      if (catSortData1.categoryIndex != catSortData2.categoryIndex)
        return catSortData1.categoryIndex < catSortData2.categoryIndex ? 1 : -1
      return 0
    }
    let isTypeAircraft1 = item1.type == "aircraft"
    let isTypeAircraft2 = item2.type == "aircraft"
    if (isTypeAircraft1 != isTypeAircraft2)
      return isTypeAircraft1 ? -1 : 1
    if (isTypeAircraft1) {
      if (item1.aircraftSortIndex != item2.aircraftSortIndex)
        return item1.aircraftSortIndex > item2.aircraftSortIndex ? 1 : -1
      return 0
    }
    let paramsOrder = sortData[item1.category].paramsOrder
    let index1 = find_in_array(paramsOrder, item1.paramName)
    let index2 = find_in_array(paramsOrder, item2.paramName)
    if (index1 != index2)
      return index1 > index2 ? 1 : -1
    return 0
  })
}

/**
* Creates special data object that
* helps to sort discount data items.
*/
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

/**
* Main parsing method.
*/
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
