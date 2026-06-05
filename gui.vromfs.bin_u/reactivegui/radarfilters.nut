from "%rGui/globals/ui_library.nut" import *
let { canEnterAAComplexMenu, RadarTargetIconType } = require("guiRadar")
let { isUnitAlive, isUnitDelayed, playerUnitName, unitType } = require("%rGui/hudState.nut")
let { isInFlight } = require("%rGui/globalState.nut")
let { aaMenuCfg } = require("%rGui/antiAirComplexMenu/antiAirComplexMenuState.nut")
let { savedRadarFilters, AAComplexRadarFiltersSaveSlotName, ESMRadarFiltersSaveSlotName } = require("%appGlobals/hud/hudState.nut")
let { RadarTargetsIffFilterMask, GenericSourceType, sendIffFilterToRadars
} = require("radarGuiControls")
let { IFFFilter, typeFilter, genericSourceFilter, rangeFilter, ESMModeTypeFilter,
  targetsFilterConfig, iffOnlyFilter, defaultFilters, esmFilter
} = require("%rGui/radarFiltersConfig.nut")
let { eventbus_subscribe } = require("eventbus")
let { RADAR_TAGET_ICON_JET, RADAR_TAGET_ICON_HELICOPTER, RADAR_TAGET_ICON_ROCKET,
  RADAR_TAGET_ICON_SMALL, RADAR_TAGET_ICON_MEDIUM, RADAR_TAGET_ICON_LARGE } = RadarTargetIconType
let { IsRadarHasFilters, IsEsm } = require("%rGui/radarState.nut")

let filterPresets = [
  {
    filter = IFFFilter
    valuesList = [
      {
        locText = loc("hud/AAComplexMenu/IFF/ally")
        getImage = @(_imageSize) null
        valueMask = RadarTargetsIffFilterMask.ALLY
      },
      {
        locText = loc("hud/AAComplexMenu/IFF/enemy")
        getImage = @(_imageSize) null
        valueMask = RadarTargetsIffFilterMask.ENEMY
      }
    ]
  }
  {
    filter = typeFilter
    valuesList = [
      {
        locText = loc("mainmenu/type_aircraft")
        getImage = @(imageSize) Picture($"ui/gameuiskin#tws_filter_aircraft.svg:{imageSize}:P")
        valueMask = 1 << RADAR_TAGET_ICON_JET
        isSelected = Watched(false)
      },
      {
        locText = loc("mainmenu/type_helicopter")
        getImage = @(imageSize) Picture($"ui/gameuiskin#tws_filter_helicopter.svg:{imageSize}:P")
        valueMask = 1 << RADAR_TAGET_ICON_HELICOPTER
        isSelected = Watched(false)
      },
      {
        locText = loc("logs/ammunition")
        getImage = @(imageSize) Picture($"ui/gameuiskin#tws_filter_ammunition.svg:{imageSize}:P")
        valueMask = 1 << RADAR_TAGET_ICON_ROCKET
        isSelected = Watched(false)
      },
      {
        locText = loc("hud/small")
        getImage = @(imageSize) Picture($"ui/gameuiskin#tws_filter_small.svg:{imageSize}:P")
        valueMask = 1 << RADAR_TAGET_ICON_SMALL
        isSelected = Watched(false)
      },
      {
        locText = loc("hud/medium")
        getImage = @(imageSize) Picture($"ui/gameuiskin#tws_filter_medium.svg:{imageSize}:P")
        valueMask = 1 << RADAR_TAGET_ICON_MEDIUM
        isSelected = Watched(false)
      },
      {
        locText = loc("hud/large")
        getImage = @(imageSize) Picture($"ui/gameuiskin#tws_filter_large.svg:{imageSize}:P")
        valueMask = 1 << RADAR_TAGET_ICON_LARGE
        isSelected = Watched(false)
      },
    ]
  }
  {
    filter = genericSourceFilter
    valuesList = [
      {
        locText = ""
        getImage = @(imageSize) Picture($"ui/gameuiskin#tws_filter_aircraft.svg:{imageSize}:P")
        valueMask = GenericSourceType.AIR
        isSelected = Watched(false)
      },
      {
        locText = ""
        getImage = @(imageSize) Picture($"ui/gameuiskin#tws_filter_small.svg:{imageSize}:P")
        valueMask = GenericSourceType.GROUND
        isSelected = Watched(false)
      },
    ]
  }
  {
    filter = rangeFilter
    valuesList = [
      {
        locText = loc("hud/AAComplexMenu/AllowOutOfRangeTargers")
        getImage = @(imageSize) Picture($"ui/gameuiskin#tws_filter_aircraft.svg:{imageSize}:P")
        valueMask = 1
      }
    ]
  }
  {
    filter = ESMModeTypeFilter
    valuesList = [
      {
        locText = loc("hud/short_range_spaa")
        label = "S"
        getImage = @(_imageSize) null
        valueMask = 1 << RadarTargetIconType.RADAR_TAGET_ICON_SHORT_RANGE_SPAA
        isSelected = Watched(false)
      },
      {
        locText = loc("hud/medium_range_spaa")
        label = "M"
        getImage = @(_imageSize) null
        valueMask = 1 << RadarTargetIconType.RADAR_TAGET_ICON_MEDIUM_RANGE_SPAA
        isSelected = Watched(false)
      },
      {
        locText = loc("hud/long_range_spaa")
        label = "L"
        getImage = @(_imageSize) null
        valueMask = 1 << RadarTargetIconType.RADAR_TAGET_ICON_LONG_RANGE_SPAA
        isSelected = Watched(false)
      },
    ]
  }
]

let isFiltersExpanded = Watched(true)

function updateFilterSelectedState(filter, currentMask = null) {
  let data = filterPresets.findvalue(@(f) f.filter == filter)
  if (data == null)
    return
  currentMask = currentMask ?? filter.getFilterValue()
  foreach (valueData in data.valuesList) {
    if (!valueData?.isSelected)
      continue
    valueData.isSelected.set((currentMask & valueData.valueMask) != 0)
  }
}

function clearAllFilters() {
  foreach (filter in targetsFilterConfig) {
    filter.setFilterValue(0, false)
    updateFilterSelectedState(filter, 0)
  }
}

let getFiltersList = @(targetListColumnsConfig)
  targetsFilterConfig.filter(@(value) targetListColumnsConfig?[value.filterId] ?? true)

function getSaveSlotKey() {
  if (canEnterAAComplexMenu())
    return AAComplexRadarFiltersSaveSlotName
  if (IsEsm.get())
    return ESMRadarFiltersSaveSlotName
  return unitType.get()
}
let getFiltersSaveSlot = @(key) savedRadarFilters.get()?[key] ?? {}

function restoreVisibleFilters(config) {
  let filterList = getFiltersList(config)
  let key = getSaveSlotKey()
  let saveSlot = getFiltersSaveSlot(key)
  filterList.each(function(v) {
    if (v.filterId in saveSlot){
      let value = saveSlot[v.filterId]
      v.setFilterValue(value, false)
      updateFilterSelectedState(v, value)
    }
  })
  sendIffFilterToRadars()
  isFiltersExpanded.set(saveSlot?["isBtnsVisible"] ?? true)
}

isInFlight.subscribe(@(v) !v ? clearAllFilters() : null)
isUnitAlive.subscribe(@(v) !v ? clearAllFilters() : null)

let needRestoreFilters = keepref(Computed(@() isUnitAlive.get()
  && !isUnitDelayed.get() && isInFlight.get()))

function getFilterConfig() {
  if (canEnterAAComplexMenu())
    return aaMenuCfg.get().targetList
  if (IsEsm.get())
    return esmFilter
  if (IsRadarHasFilters.get())
    return defaultFilters
  return iffOnlyFilter
}

needRestoreFilters.subscribe(@(v) v ? restoreVisibleFilters(getFilterConfig()) : null)
playerUnitName.subscribe(@(_) restoreVisibleFilters(getFilterConfig()))

function saveFilters() {
  let config = getFilterConfig()
  let activeFilters = getFiltersList(config)
  let key = getSaveSlotKey()
  let save = clone getFiltersSaveSlot(key)
  foreach (filter in activeFilters) {
    let { filterId, getFilterValue } = filter
    let currValue = getFilterValue()
    save[filterId] <- currValue
    updateFilterSelectedState(filter, currValue)
  }
  savedRadarFilters.mutate(@(v) v[key] <- save)
}

function saveFilterButtonsVisibility(val) {
  let key = getSaveSlotKey()
  let save = getFiltersSaveSlot(key)
  save["isBtnsVisible"] <- val
}

isFiltersExpanded.subscribe(saveFilterButtonsVisibility)

IsRadarHasFilters.subscribe(function(_) {
  clearAllFilters()
  restoreVisibleFilters(getFilterConfig())
})

IsEsm.subscribe(function(_) {
  clearAllFilters()
  restoreVisibleFilters(getFilterConfig())
})

function switchFilter(filter, mask) {
  let data = filterPresets.findvalue(@(f) f.filter == filter)
  if (data == null)
    return
  let currentMask = filter.getFilterValue()
  let needSetFilter = (currentMask & mask) == 0
  let newValueMask = needSetFilter
    ? (currentMask | mask)
    : (currentMask & ~mask)
  filter.setFilterValue(newValueMask, true)
}

foreach (filter in targetsFilterConfig)
  updateFilterSelectedState(filter)

eventbus_subscribe("hud.radar.filtersUpdated", @(_) saveFilters())

return {
  IFFFilter
  typeFilter
  rangeFilter
  targetsFilterConfig
  AAComplexRadarFiltersSaveSlotName
  filterPresets
  switchFilter
  isFiltersExpanded
  ESMModeTypeFilter
}