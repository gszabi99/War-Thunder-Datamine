from "%scripts/unit/canBuyUnitOnMarketplace.nut" import isAvailableBuyUnitOnMarketPlace
from "%scripts/dagui_library.nut" import *

let unitEventIds = persist("unitEventIds", @() {})
let oldUnitsEvents = persist("unitsEvents", @() {})
foreach (unitName, row in oldUnitsEvents)
  unitEventIds[unitName] <- row.eventId
oldUnitsEvents.clear()

let getEventUnitsData = @() unitEventIds.keys().map(function(unitName) {
  let unit = getAircraftByName(unitName)
  if (unit == null)
    throw null
  return { unit, eventId = unitEventIds[unitName] }
})
let getEventMarkersData = @(countryId) getEventUnitsData().filter(@(u) u.unit.shopCountry == countryId)

return freeze({
  addUnitEventId = @(unitName, eventId) unitEventIds[unitName] <- eventId
  getUnitEventId = @(unitName) unitEventIds?[unitName]
  hasUnitEvent = @(unitName) unitEventIds?[unitName] != null
  isUnitOnlyFromEvent = @(unit) unit?.shopEvent != null && !isAvailableBuyUnitOnMarketPlace(unit)
  getEventUnitsData
  getEventMarkersData
})