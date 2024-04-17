from "%scripts/dagui_library.nut" import *

let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { RESET_ID } = require("%scripts/popups/popupFilter.nut")

let filterTypes = {}
let buyTypes = [
  { name = "researchable", title = "wishlist/filter/researchableVehicle" }
  { name = "premium", title = "wishlist/filter/premiumVehicle" }
  { name = "squadron", title = "wishlist/filter/squadronVehicle" }
  { name = "shop", title = "wishlist/filter/shopVehicle" }
  { name = "marketPlace", title = "wishlist/filter/marketPlaceVehicle", availableFunc = @() hasFeature("Marketplace")}
  { name = "conditionToReceive", title = "wishlist/filter/conditionToReceive" }
]

let availability = [
  { name = "available", title = "wishlist/filter/available" }
  { name = "discount", title = "wishlist/filter/discount" }
]

function fillUnitTypes() {
  let res = {}
  foreach (unitType in unitTypes.types) {
    if (!unitType.isAvailable())
      continue

    let typeIdx = unitType.esUnitType
    res[unitType.armyId] <- {
      id = $"unitType_{typeIdx}"
      idx = typeIdx
      image = unitType.testFlightIcon
      text = unitType.getArmyLocName()
      value = unitType.esUnitType
    }
  }
  return res
}

function fillCountries() {
  let res = {}
  foreach (idx, inst in shopCountriesList)
    res[inst] <- {
      id = inst
      idx = idx
      image = getCountryIcon(inst)
      text = loc(inst)
      value = inst
    }
  return res
}

function fillRanks() {
  let res = {}
  for (local i = 1; i <= ::max_country_rank; i++) {
    res[i] <- {
      id = $"rank_{i}"
      idx = i
      text = $"{loc("shop/age")} {get_roman_numeral(i)}"
      value = i
    }
  }
  return res
}

function fillBuyType() {
  let res = {}
  for (local i = 0; i < buyTypes.len(); i++) {
    let { availableFunc = null } = buyTypes[i]
    if (!(availableFunc?() ?? true))
      continue
    res[i] <- {
      id = $"buyType_{i}"
      idx = i
      text = loc(buyTypes[i].title)
      value = buyTypes[i].name
    }
  }

  return res
}

function fillAvailability() {
  let res = {}
  for (local i = 0; i < availability.len(); i++) {
    res[i] <- {
      id = $"availability_{i}"
      idx = i
      text = loc(availability[i].title)
      value = availability[i].name
    }
  }

  return res
}

let filterNames = [
  { name = "country", fillFunction = fillCountries, showInFriendWishlist = true, selectedArr = persist("wishlistFilterCountry", @() []) }
  { name = "unitType", fillFunction = fillUnitTypes, showInFriendWishlist = true, selectedArr = persist("wishlistFilterUnitType", @() []) }
  { name = "rank", fillFunction = fillRanks, showInFriendWishlist = true, selectedArr = persist("wishlistFilterRank", @() []) }
  { name = "buyType", fillFunction = fillBuyType, showInFriendWishlist = false, selectedArr = persist("wishlistFilterBuyType", @() []) }
  { name = "availability", fillFunction = fillAvailability, showInFriendWishlist = false, selectedArr = persist("wishlistFilterAvailability", @() []) }
]

function getFiltersView(isFriendWishlist = false) {
  return filterNames
    .filter(@(fName) !isFriendWishlist || fName.showInFriendWishlist)
    .map(function(fName) {
      let { name, fillFunction, selectedArr } = fName
      let referenceArr = fillFunction()
      filterTypes[name] <- { referenceArr, selectedArr }

      let view = { checkbox = [] }
      foreach (key, inst in referenceArr)
        view.checkbox.append({
          id = inst.id
          idx = inst.idx
          image = inst?.image
          text = inst.text
          value = selectedArr.indexof(key) != null
        })

      view.checkbox.sort(@(a, b) a.idx <=> b.idx)
      return view
    })
}

let getSelectedFilters = @() filterTypes.map(@(value) value.selectedArr.map(@(v) value.referenceArr[v].value))

function removeItemFromList(value, list) {
  let idx = list.findindex(@(v) v == value)
  if (idx != null)
    list.remove(idx)
}

function applyFilterChange(objId, tName, value) {
  let selectedArr = filterTypes[tName].selectedArr
  let referenceArr = filterTypes[tName].referenceArr
  let isReset = objId == RESET_ID

  foreach (idx, inst in referenceArr) {
    if (!isReset && inst.id != objId)
      continue

    if (value)
      appendOnce(idx, selectedArr)
    else
      removeItemFromList(idx, selectedArr)
  }
}

return {
  getFiltersView
  applyFilterChange
  getSelectedFilters
}
