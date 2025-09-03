from "%scripts/dagui_library.nut" import *
let unitsEvents = persist("unitsEvents", @() {})

let getEventUnitsData = @() unitsEvents.values().filter(@(u) u.unit != null)
let getEventMarkersData = @(countryId) getEventUnitsData().filter(@(u) u.unit.shopCountry == countryId)

return {
  addUnitEventId = @(unitName, unit, eventId) unitsEvents[unitName] <- { unit, eventId }
  getUnitEventId = @(unitName) unitsEvents?[unitName].eventId
  hasUnitEvent = @(unitName) unitsEvents?[unitName].eventId != null
  getEventUnitsData
  getEventMarkersData
}