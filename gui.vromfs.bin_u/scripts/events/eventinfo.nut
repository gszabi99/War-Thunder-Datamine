local { getSlotbarOverrideData } = require("scripts/slotbar/slotbarOverride.nut")
local { isRequireUnlockForUnit } = require("scripts/unit/unitStatus.nut")

local needShowOverrideSlotbar = @(event) event?.showEditSlotbar ?? false

local getCustomViewCountryData = @(event) event?.customViewCountry

local function getEventSlotbarHint(event, country) {
  if (!needShowOverrideSlotbar(event))
    return ""

  local overrideSlotbar = getSlotbarOverrideData(::events.getEventMission(event.name))
  if ((overrideSlotbar?.len() ?? 0) == 0)
    return ""

  local crews = overrideSlotbar.findvalue(@(v) v.country == country)?.crews
  if (crews == null)
    return ""

  local hasNotUnlockedUnit = crews.findindex(
    @(c) isRequireUnlockForUnit(::getAircraftByName(c.aircraft))
  ) != null

  return hasNotUnlockedUnit ? ::loc("event/unlockAircrafts") : ""
}

return {
  needShowOverrideSlotbar
  getCustomViewCountryData
  getEventSlotbarHint
}