//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let cache = {}

let function getValue(unitName, param) {
  return cache?[unitName][param]
}

let function cacheValue(unitName, param, value) {
  if (unitName not in cache)
    cache[unitName] <- {}

  cache[unitName][param] <- value
}

let function isShipDamageControlEnabled(unit) {
  let value = getValue(unit.name, "shipDamageControlEnabled")
  if (value != null)
    return value

  let unitBlk = ::get_full_unit_blk(unit.name)
  let shipDamageControlEnabled = unitBlk?.shipDamageControl.shipDamageControlEnabled ?? false

  cacheValue(unit.name, "shipDamageControlEnabled", shipDamageControlEnabled)
  return shipDamageControlEnabled
}

return {
  isShipDamageControlEnabled
}