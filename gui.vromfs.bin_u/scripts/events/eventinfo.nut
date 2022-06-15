let { getSlotbarOverrideData } = require("%scripts/slotbar/slotbarOverride.nut")
let { isRequireUnlockForUnit } = require("%scripts/unit/unitStatus.nut")

let needShowOverrideSlotbar = @(event) event?.showEditSlotbar ?? false

let getCustomViewCountryData = @(event) event?.customViewCountry

let function getEventSlotbarHint(event, country) {
  if (!needShowOverrideSlotbar(event))
    return ""

  let overrideSlotbar = getSlotbarOverrideData(::events.getEventMission(event.name), event)
  if ((overrideSlotbar?.len() ?? 0) == 0)
    return ""

  let crews = overrideSlotbar.findvalue(@(v) v.country == country)?.crews
  if (crews == null)
    return ""

  let hasNotUnlockedUnit = crews.findindex(
    @(c) isRequireUnlockForUnit(::getAircraftByName(c.aircraft))
  ) != null

  return hasNotUnlockedUnit ? ::loc("event/unlockAircrafts") : ""
}

return {
  needShowOverrideSlotbar
  getCustomViewCountryData
  getEventSlotbarHint
}