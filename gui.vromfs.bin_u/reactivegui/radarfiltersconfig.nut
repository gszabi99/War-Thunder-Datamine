from "%rGui/globals/ui_library.nut" import *
let { getRadarTargetsIffFilterMask, setRadarTargetsIffFilterMask,
  getRadarTargetsTypeFilterMask, setRadarTargetsTypeFilterMask,
  getRadarTargetsGenericSourceTypeMask, setRadarTargetsGenericSourceTypeMask,
  getAllowOutOfRangeTargets, setAllowOutOfRangeTargets,
} = require("radarGuiControls")

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

let genericSourceFilter = {
  filterId = "genericSource"
  getFilterValue = getRadarTargetsGenericSourceTypeMask
  setFilterValue = setRadarTargetsGenericSourceTypeMask
}

let rangeFilter = {
  filterId = "outOfRange"
  getFilterValue = getAllowOutOfRangeTargets
  setFilterValue = setAllowOutOfRangeTargets
}

let ESMModeTypeFilter = {
  filterId = "ESMModeType"
  getFilterValue = getRadarTargetsTypeFilterMask
  setFilterValue = setRadarTargetsTypeFilterMask
}

let targetsFilterConfig = [
  IFFFilter
  typeFilter
  genericSourceFilter
  rangeFilter
  ESMModeTypeFilter
]

let allFiltersDisabledMap = {}
foreach (filter in targetsFilterConfig)
  allFiltersDisabledMap[filter.filterId] <- false

function makeFilterMap(enabledFilters) {
  let res = clone allFiltersDisabledMap
  foreach (filter in enabledFilters)
    res[filter.filterId] = true
  return res
}

let iffOnlyFilter = makeFilterMap([IFFFilter])
let defaultFilters = makeFilterMap([IFFFilter, typeFilter, rangeFilter])
let esmFilter = makeFilterMap([genericSourceFilter, ESMModeTypeFilter])

return {
  IFFFilter
  typeFilter
  genericSourceFilter
  rangeFilter
  ESMModeTypeFilter
  targetsFilterConfig
  iffOnlyFilter
  defaultFilters
  esmFilter
}
