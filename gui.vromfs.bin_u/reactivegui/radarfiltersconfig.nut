from "%rGui/globals/ui_library.nut" import *
let { getRadarTargetsIffFilterMask, setRadarTargetsIffFilterMask,
  getRadarCompositeFilterMask, setRadarCompositeFilterMask,
  getRadarTargetsGenericSourceTypeMask, setRadarTargetsGenericSourceTypeMask,
  getAllowOutOfRangeTargets, setAllowOutOfRangeTargets,
} = require("radarGuiControls")
let { RadarCompositeSubfilter } = require("guiRadar")

let IFFFilter = {
  filterId = "IFF"
  getFilterValue = getRadarTargetsIffFilterMask
  setFilterValue = setRadarTargetsIffFilterMask
}

let defaultModeBits = [
  { name = "JETS",        bit = RadarCompositeSubfilter.JETS },
  { name = "HELICOPTERS", bit = RadarCompositeSubfilter.HELICOPTERS },
  { name = "ROCKETS",     bit = RadarCompositeSubfilter.ROCKETS },
  { name = "SMALL",       bit = RadarCompositeSubfilter.SMALL },
  { name = "MEDIUM",      bit = RadarCompositeSubfilter.MEDIUM },
  { name = "LARGE",       bit = RadarCompositeSubfilter.LARGE },
]
let esmModeBits = [
  { name = "SHORT_RANGE_SPAA",  bit = RadarCompositeSubfilter.SHORT_RANGE_SPAA },
  { name = "MEDIUM_RANGE_SPAA", bit = RadarCompositeSubfilter.MEDIUM_RANGE_SPAA },
  { name = "LONG_RANGE_SPAA",   bit = RadarCompositeSubfilter.LONG_RANGE_SPAA },
]

function mkCompositeFilter(filterId, bits) {
  let bitsMask = bits.reduce(@(m, b) m | (1 << b.bit), 0)
  return {
    filterId
    getFilterValue = @() getRadarCompositeFilterMask() & bitsMask
    setFilterValue = @(value, notify = true) setRadarCompositeFilterMask(
      (getRadarCompositeFilterMask() & ~bitsMask) | (value & bitsMask), notify)
    serialize = function(mask) {
      let res = {}
      foreach (b in bits)
        res[b.name] <- (mask & (1 << b.bit)) != 0
      return res
    }
    deserialize = @(saved) (type(saved) != "table")
      ? 0
      : bits.reduce(@(mask, b) (saved?[b.name] ?? false) ? (mask | (1 << b.bit)) : mask, 0)
  }
}

let typeFilter = mkCompositeFilter("DefaultModeComposite", defaultModeBits)

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

let ESMModeTypeFilter = mkCompositeFilter("ESMModeComposite", esmModeBits)

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
let esmFilter = makeFilterMap([IFFFilter, ESMModeTypeFilter])

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
