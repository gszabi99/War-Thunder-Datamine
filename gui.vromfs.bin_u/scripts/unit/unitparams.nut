from "%scripts/dagui_library.nut" import *

let cache = {}

function getValue(unitName, param) {
  return cache?[unitName][param]
}

function cacheValue(unitName, param, value) {
  if (unitName not in cache)
    cache[unitName] <- {}

  cache[unitName][param] <- value
}

function isShipDamageControlEnabled(unit) {
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