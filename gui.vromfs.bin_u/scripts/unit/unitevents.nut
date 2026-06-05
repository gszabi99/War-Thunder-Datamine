from "%scripts/dagui_library.nut" import *
let { isAvailableBuyUnitOnMarketPlace } = require("%scripts/unit/canBuyUnitOnMarketplace.nut")

let unitsEvents = persist("unitsEvents", @() {})

let getEventUnitsData = @() unitsEvents.values().filter(@(u) u.unit != null)
let getEventMarkersData = @(countryId) getEventUnitsData().filter(@(u) u.unit.shopCountry == countryId)

return {
  addUnitEventId = @(unitName, unit, eventId) unitsEvents[unitName] <- { unit, eventId }
  getUnitEventId = @(unitName) unitsEvents?[unitName].eventId
  hasUnitEvent = @(unitName) unitsEvents?[unitName].eventId != null
  isUnitOnlyFromEvent = @(unit) unit?.shopEvent != null && !isAvailableBuyUnitOnMarketPlace(unit)
  getEventUnitsData
  getEventMarkersData
}