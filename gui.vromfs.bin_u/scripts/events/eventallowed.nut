import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, CONFIG_VALIDATION

let { getEventDisplayType, hasEventFeature, isVrModeAllowedInEvent, isEventAllowedByPackage, getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { g_event_display_type } = require("%scripts/events/eventDisplayType.nut")
let { eventRequiresTicket, getEventActiveTicket } = require("%scripts/events/eventTickets.nut")
let { isCompatibilityMode, isVrModeEnable } = require("%scripts/options/systemOptions.nut")
let { EVENTS_DATA_UPDATED, INVENTORY_UPDATE } = require("%scripts/crossModuleEvents.nut")
let { gameEvents } = require("%scripts/events/eventsState.nut")





let isEventAllowedByVrMode = @(event) isVrModeAllowedInEvent(event) || !isVrModeEnable()
let isEventAllowedByComaptibilityMode = @(event) event?.isAllowedForCompatibility != false || !isCompatibilityMode()

function isEventAllowed(event) {
  return getEventDisplayType(event) != g_event_display_type.NONE
    && hasEventFeature(event)
    && isEventAllowedByComaptibilityMode(event)
    && isEventAllowedByVrMode(event)
    && isEventAllowedByPackage(event)
    && (!eventRequiresTicket(event) || getEventActiveTicket(event) != null)
}

let unallowedEventEconomicNames = []
local unallowedEventEconomicNamesNeedUpdate = true

function getUnallowedEventEconomicNames() {
  if (!unallowedEventEconomicNamesNeedUpdate)
    return unallowedEventEconomicNames

  unallowedEventEconomicNames.clear()
  foreach (event in gameEvents)
    if (!isEventAllowed(event))
      u.appendOnce(getEventEconomicName(event), unallowedEventEconomicNames, true)
  unallowedEventEconomicNamesNeedUpdate = false
  return unallowedEventEconomicNames
}

addListenersWithoutEnv({
  [EVENTS_DATA_UPDATED] = @(_) unallowedEventEconomicNamesNeedUpdate = true,
  [INVENTORY_UPDATE] = @(_) unallowedEventEconomicNamesNeedUpdate = true
}, CONFIG_VALIDATION)

return {
  isEventAllowedByVrMode
  isEventAllowedByComaptibilityMode
  getUnallowedEventEconomicNames
}
