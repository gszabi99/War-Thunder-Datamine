from "%scripts/dagui_library.nut" import *

let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { RESET_ID, SELECT_ALL_ID } = require("%scripts/popups/popupFilterWidget.nut")
let { maxCountryRank } = require("%scripts/ranks.nut")

let filterTypes = {}

let buyTypes = [
  { name = "researchable", title = "wishlist/filter/researchableVehicle" }
  { name = "premium", title = "wishlist/filter/premiumVehicle" }
  { name = "shop", title = "wishlist/filter/shopVehicle" }
]

let availability = [
  { name = "available", title = "wishlist/filter/available" }
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
      imageAspectRatio = 0.66
      text = loc(inst)
      value = inst
    }
  return res
}

function fillRanks() {
  let res = {}
  let maxRank = maxCountryRank.get()
  for (local i = 1; i <= maxRank; i++)
    res[i] <- {
      id = $"rank_{i}"
      idx = i
      text = $"{loc("shop/age")} {get_roman_numeral(i)}"
      value = i
    }
  return res
}

function fillBuyType() {
  let res = {}
  foreach (i, buyType in buyTypes)
    res[i] <- {
      id = $"buyType_{i}"
      idx = i
      text = loc(buyType.title)
      value = buyType.name
    }

  return res
}

function fillAvailability() {
  let res = {}
  foreach (i, avail in availability)
    res[i] <- {
      id = $"availability_{i}"
      idx = i
      text = loc(avail.title)
      value = avail.name
    }

  return res
}

let filterNames = [
  { name = "country", fillFunction = fillCountries, selectedArr = persist("limitBuyFilterCountry", @() []) }
  { name = "unitType", fillFunction = fillUnitTypes, selectedArr = persist("limitBuyFilterUnitType", @() []) }
  { name = "rank", fillFunction = fillRanks, selectedArr = persist("limitBuyFilterRank", @() []) }
  { name = "buyType", fillFunction = fillBuyType, selectedArr = persist("limitBuyFilterBuyType", @() []) }
  { name = "availability", fillFunction = fillAvailability, selectedArr = persist("limitBuyFilterAvailability", @() []) }
]

function getFiltersView() {
  return filterNames
    .map(function(fName) {
      let { name, fillFunction, selectedArr } = fName
      let referenceData = fillFunction()
      filterTypes[name] <- { referenceData, selectedArr }

      let view = { checkbox = [] }
      foreach (key, inst in referenceData)
        view.checkbox.append({
          id = inst.id
          idx = inst.idx
          image = inst?.image
          imageAspectRatio = inst?.imageAspectRatio
          text = inst.text
          value = selectedArr.indexof(key) != null
        })

      view.checkbox.sort(@(a, b) a.idx <=> b.idx)
      return view
    })
}

let getSelectedFilters = @() filterTypes.map(@(value) value.selectedArr.map(@(v) value.referenceData[v].value))

function removeItemFromList(value, list) {
  let idx = list.findindex(@(v) v == value)
  if (idx != null)
    list.remove(idx)
}

function applyFilterChange(objId, tName, value) {
  let selectedArr = filterTypes[tName].selectedArr
  let referenceData = filterTypes[tName].referenceData

  if (objId == RESET_ID) {
    selectedArr.clear()
    return
  }

  if (objId == SELECT_ALL_ID) {
    referenceData.each(@(_v, idx) appendOnce(idx, selectedArr))
    return
  }

  foreach (idx, inst in referenceData) {
    if (inst.id != objId)
      continue

    if (value)
      appendOnce(idx, selectedArr)
    else
      removeItemFromList(idx, selectedArr)
    break
  }
}

return {
  getFiltersView
  applyFilterChange
  getSelectedFilters
}
