//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { getSlotbarOverrideData } = require("%scripts/slotbar/slotbarOverride.nut")
let { isRequireUnlockForUnit } = require("%scripts/unit/unitStatus.nut")
let { getSeparateLeaderboardPlatformValue } = require("%scripts/social/crossplay.nut")

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

  return hasNotUnlockedUnit ? loc("event/unlockAircrafts") : ""
}

let isLeaderboardsAvailable = @() !getSeparateLeaderboardPlatformValue()
  || hasFeature("ConsoleSeparateEventsLeaderboards")

return {
  needShowOverrideSlotbar
  getCustomViewCountryData
  getEventSlotbarHint
  isLeaderboardsAvailable
}