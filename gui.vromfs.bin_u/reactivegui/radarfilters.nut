from "%rGui/globals/ui_library.nut" import *
let { canEnterAAComplexMenu } = require("guiRadar")
let { isUnitAlive, isUnitDelayed, playerUnitName, unitType } = require("%rGui/hudState.nut")
let { isInFlight } = require("%rGui/globalState.nut")
let { aaMenuCfg } = require("%rGui/antiAirComplexMenu/antiAirComplexMenuState.nut")
let { savedRadarFilters, AAComplexRadarFiltersSaveSlotName } = require("%appGlobals/hud/hudState.nut")
let { getRadarTargetsIffFilterMask, setRadarTargetsIffFilterMask,
  getRadarTargetsTypeFilterMask, setRadarTargetsTypeFilterMask,
  getAllowOutOfRangeTargets, setAllowOutOfRangeTargets
} = require("radarGuiControls")
let { eventbus_subscribe } = require("eventbus")

let IFFFilter = {
  filterId = "IFF"
  getFilterValue = getRadarTargetsIffFilterMask
  setFilterValue = setRadarTargetsIffFilterMask
}

let typeFilter = {
  filterId = "typeIcon"
  getFilterValue = getRadarTargetsTypeFilterMask
  setFilterValue = setRadarTargetsTypeFilterMask
}

let rangeFilter = {
  filterId = "outOfRange"
  getFilterValue = getAllowOutOfRangeTargets
  setFilterValue = setAllowOutOfRangeTargets
}

let targetsFilterConfig = [
  IFFFilter
  typeFilter
  rangeFilter
]

let clearAllFilters = function() {
  targetsFilterConfig.each(@(v) v.setFilterValue(0, false))
}

let getFiltersList = @(targetListColumnsConfig)
  targetsFilterConfig.filter(@(value) targetListColumnsConfig?[value.filterId] ?? true)

let getSaveSlotKey = @() canEnterAAComplexMenu() ? AAComplexRadarFiltersSaveSlotName : unitType.get()
let getFiltersSaveSlot = @(key) savedRadarFilters.get()?[key] ?? {}

function restoreVisibleFilters(config) {
  let filterList = getFiltersList(config)
  let key = getSaveSlotKey()
  let saveSlot = getFiltersSaveSlot(key)
  filterList.each(function(v) {
    if (v.filterId in saveSlot){
      let value = saveSlot[v.filterId]
      v.setFilterValue(value, false)
    }
  })
}

isInFlight.subscribe(@(v) !v ? clearAllFilters() : null)
isUnitAlive.subscribe(@(v) !v ? clearAllFilters() : null)

let needRestoreFilters = keepref(Computed(@() isUnitAlive.get()
  && !isUnitDelayed.get() && isInFlight.get()))

let defaultFilter = targetsFilterConfig.reduce(function(res, filter){
  if (res == null)
    res = {}
  res[filter.filterId] <- false
  return res
}).__update({
  "IFF": true
})

function getFilterConfig(){
  if (canEnterAAComplexMenu())
    return aaMenuCfg.get().targetList
  return defaultFilter
}

needRestoreFilters.subscribe(@(v) v ? restoreVisibleFilters(getFilterConfig()) : null)
playerUnitName.subscribe(@(_) restoreVisibleFilters(getFilterConfig()))

function saveFilters(){
  let config = getFilterConfig()
  let activeFilters = getFiltersList(config)

  let key = getSaveSlotKey()
  let save = clone getFiltersSaveSlot(key)
  foreach (filter in activeFilters) {
    let { filterId, getFilterValue } = filter
    let currValue = getFilterValue()

    save[filterId] <- currValue
  }
  savedRadarFilters.mutate(@(v) v[key] <- save)
}

eventbus_subscribe("hud.radar.filtersUpdated", @(_) saveFilters())

return {
  IFFFilter
  typeFilter
  rangeFilter
  targetsFilterConfig
  AAComplexRadarFiltersSaveSlotName
}