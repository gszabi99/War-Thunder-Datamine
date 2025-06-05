from "%scripts/dagui_library.nut" import *

let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { RESET_ID } = require("%scripts/popups/popupFilterWidget.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")

let filterTypes = {}

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
  for (local i = 1; i <= MAX_COUNTRY_RANK; i++) {
    res[i] <- {
      id = $"rank_{i}"
      idx = i
      text = $"{loc("shop/age")} {get_roman_numeral(i)}"
      value = i
    }
  }
  return res
}

let filterNames = [
  { name = "country", fillFunction = fillCountries, selectedArr = persist("serviceRecordsFilterCountry", @() []) }
  { name = "unitType", fillFunction = fillUnitTypes, selectedArr = persist("serviceRecordsFilterUnitType", @() []) }
  { name = "rank", fillFunction = fillRanks, selectedArr = persist("serviceRecordsFilterRank", @() []) }
]

function getUnitsStatsFiltersView() {
  return filterNames
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

let getUnitsStatsSelectedFilters = @() filterTypes.map(@(value) value.selectedArr.map(@(v) value.referenceArr[v].value))

function removeItemFromList(value, list) {
  let idx = list.findindex(@(v) v == value)
  if (idx != null)
    list.remove(idx)
}

function applyUnitsStatsFilterChange(objId, tName, value) {
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
  getUnitsStatsFiltersView
  applyUnitsStatsFilterChange
  getUnitsStatsSelectedFilters
}
