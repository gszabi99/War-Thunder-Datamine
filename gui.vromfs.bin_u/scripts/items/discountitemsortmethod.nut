local { shopCountriesList } = require("scripts/shop/shopCountriesList.nut")

/**
* Sorts description items with following rules:
* First items are sorted by categories. Same order
* as in blk. Then go all aircraft items sorted again
* as in discount item blk. Last go all non-aircraft
* items with order from blk.
*/
::sort_discount_description_items <- function sort_discount_description_items(items, sortData)
{
  if (sortData == null)
    return
  items.sort((@(sortData) function (item1, item2) {
    if (item1.category != item2.category)
    {
      local catSortData1 = sortData[item1.category]
      local catSortData2 = sortData[item2.category]
      if (catSortData1.categoryIndex != catSortData2.categoryIndex)
        return catSortData1.categoryIndex < catSortData2.categoryIndex ? 1 : -1
      return 0
    }
    local isTypeAircraft1 = item1.type == "aircraft"
    local isTypeAircraft2 = item2.type == "aircraft"
    if (isTypeAircraft1 != isTypeAircraft2)
      return isTypeAircraft1 ? -1 : 1
    if (isTypeAircraft1)
    {
      if (item1.aircraftSortIndex != item2.aircraftSortIndex)
        return item1.aircraftSortIndex > item2.aircraftSortIndex ? 1 : -1
      return 0
    }
    local paramsOrder = sortData[item1.category].paramsOrder
    local index1 = ::find_in_array(paramsOrder, item1.paramName)
    local index2 = ::find_in_array(paramsOrder, item2.paramName)
    if (index1 != index2)
      return index1 > index2 ? 1 : -1
    return 0
  })(sortData))
}

/**
* Creates special data object that
* helps to sort discount data items.
*/
::create_discount_description_sort_data <- function create_discount_description_sort_data(blk)
{
  if (blk == null)
    return null
  local sortData = {}
  for (local i = 0; i < blk.blockCount(); ++i)
  {
    local discountCategoryBlk = blk.getBlock(i)
    local paramsOrder = []
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
::parse_discount_description <- function parse_discount_description(blk)
{
  if (blk == null)
    return []
  local items = []
  for (local i = 0; i < blk.blockCount(); ++i)
    items.extend(::parse_discount_description_category(blk.getBlock(i)))
  return items
}

::parse_discount_description_category <- function parse_discount_description_category(blk)
{
  if (blk == null)
    return []
  local category = blk.getBlockName()
  // Order corresponds to discount priorities.
  local items = []
  items.extend(::parse_discount_description_aircrafts(blk?.aircrafts, category))
  items.extend(::parse_discount_description_country_rank(blk, category, true))
  items.extend(::parse_discount_description_country_rank(blk, category, false))
  items.extend(::parse_discount_description_rank(blk, category, true))
  items.extend(::parse_discount_description_rank(blk, category, false))
  items.extend(::parse_discount_description_country(blk, category, true))
  items.extend(::parse_discount_description_country(blk, category, false))
  items.extend(::parse_discount_description_all(blk, category, true))
  items.extend(::parse_discount_description_all(blk, category, false))
  items.extend(::parse_discount_description_entitlements(blk, category))
  return items
}

::parse_discount_description_aircrafts <- function parse_discount_description_aircrafts(blk, category)
{
  if (blk == null)
    return []
  local items = []
  for (local i = 0; i < blk.paramCount(); ++i)
  {
    if (blk.getParamValue(i) == 0)
      continue
    local aircraftName = blk.getParamName(i)
    items.append({
      category = category
      type = "aircraft"
      discountValue = blk.getParamValue(i)
      aircraftName = aircraftName
      aircraftSortIndex = i
    })
  }
  return items
}

::parse_discount_description_country_rank <- function parse_discount_description_country_rank(blk, category, usePremium)
{
  if (blk == null)
    return []
  local items = []
  foreach (countryName in shopCountriesList)
  {
    for (local i = 1; i <= ::max_country_rank; ++i)
    {
      local name = countryName + "_rank" + i.tostring() + (usePremium ? "_premium" : "")
      if (!(name in blk) || blk[name] == 0)
        continue
      items.append({
        paramName = name
        category = category
        // Same as for rank-only discounts
        // because of same localization strings.
        type = "rank" + (usePremium ? "_premium" : "")
        discountValue = blk[name]
        rank = i
        countryName = countryName
      })
    }
  }
  return items
}

::parse_discount_description_country <- function parse_discount_description_country(blk, category, usePremium)
{
  if (blk == null)
    return []
  local items = []
  foreach (countryName in shopCountriesList)
  {
    local name = countryName + (usePremium ? "_premium" : "")
    if (!(name in blk) || blk[name] == 0)
      continue
    items.append({
      paramName = name
      category = category
      // Same as for "all" discounts
      // because of same localization strings.
      type = "all" + (usePremium ? "_premium" : "")
      discountValue = blk[name]
      countryName = countryName
    })
  }
  return items
}

::parse_discount_description_rank <- function parse_discount_description_rank(blk, category, usePremium)
{
  if (blk == null)
    return []
  local items = []
  for (local i = 1; i <= ::max_country_rank; ++i)
  {
    local name = "rank" + i.tostring() + (usePremium ? "_premium" : "")
    if (!(name in blk) || blk[name] == 0)
      continue
    items.append({
      paramName = name
      category = category
      type = "rank" + (usePremium ? "_premium" : "")
      discountValue = blk[name]
      rank = i
    })
  }
  return items
}

::parse_discount_description_all <- function parse_discount_description_all(blk, category, usePremium)
{
  if (blk == null)
    return []
  local name = "all" + (usePremium ? "_premium" : "")
  if (!(name in blk) || blk[name] == 0)
    return []
  return [{
    paramName = name
    category = category
    type = "all" + (usePremium ? "_premium" : "")
    discountValue = blk[name]
  }]
}

::parse_discount_description_entitlements <- function parse_discount_description_entitlements(blk, category)
{
  if (blk == null || category != "entitlements")
    return []
  local items = []
  for (local i = 0; i < blk.paramCount(); ++i)
  {
    items.append({
      category = category
      entitlementName = blk.getParamName(i)
      discountValue = blk.getParamValue(i)
    })
  }
  return items
}
