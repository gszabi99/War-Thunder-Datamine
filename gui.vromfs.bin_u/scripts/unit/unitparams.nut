from "%scripts/dagui_library.nut" import *

let { getUnitFileName } = require("vehicleModel")
let { eventbus_subscribe } = require("eventbus")
let DataBlock = require("DataBlock")
let getAllUnits = require("%scripts/unit/allUnits.nut")

let cache = {}
let cacheUnitsBlk = {}

function getFullUnitBlk(unitName) {
  if (unitName in cacheUnitsBlk)
    return cacheUnitsBlk[unitName]

  let blk = DataBlock()
  let path = getUnitFileName(unitName)
  if (!blk.tryLoad(path, true))
    logerr($"not found unit blk on filePath = {path}")

  cacheUnitsBlk[unitName] <- blk
  return cacheUnitsBlk[unitName]
}

eventbus_subscribe("clearCacheForBullets", @(_) cacheUnitsBlk.clear())

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

  let unitBlk = getFullUnitBlk(unit.name)
  let shipDamageControlEnabled = unitBlk?.shipDamageControl.shipDamageControlEnabled ?? false

  cacheValue(unit.name, "shipDamageControlEnabled", shipDamageControlEnabled)
  return shipDamageControlEnabled
}

function findUnitNoCase(unitName) {
  unitName = unitName.tolower()
  foreach (name, unit in getAllUnits())
    if (name.tolower() == unitName)
      return unit
  return null
}

return {
  isShipDamageControlEnabled
  findUnitNoCase
  getFullUnitBlk
}