from "%scripts/dagui_library.nut" import *

let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { RESET_ID } = require("%scripts/popups/popupFilterWidget.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")

let filterTypes = {}

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

function fillBought() {
  let res = {}
  res[0] <- {
    id = "bought"
    idx = 0
    text = $"{loc("profile/only_for_bought")}"
    value = true
  }
  return res
}

let filterNames = [
  {
    name = "bought"
    fillFunction = fillBought
    filterFunction = @(cond) cond
    selectedArr = persist("skinsFilterBought", @() [])
  }
  {
    name = "rank"
    fillFunction = fillRanks
    filterFunction = @(_cond) true
    selectedArr = persist("skinsFilterRank", @() [])
  }
]

function getFiltersView(hasReceived) {
  return filterNames
    .filter(@(fName) fName.filterFunction(hasReceived))
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
