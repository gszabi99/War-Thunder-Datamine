import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/events/eventInfo.nut" import getEventDisplayType, hasEventFeature, isVrModeAllowedInEvent, isEventAllowedByPackage, getEventEconomicName
from "%scripts/events/eventTickets.nut" import eventRequiresTicket, getEventActiveTicket
from "%scripts/options/systemOptions.nut" import isCompatibilityMode, isVrModeEnable
from "%scripts/crossModuleEvents.nut" import EVENTS_DATA_UPDATED, INVENTORY_UPDATE, CONSOLE_PACKS_READY_CHANGED
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, CONFIG_VALIDATION

let { g_event_display_type } = require("%scripts/events/eventDisplayType.nut")
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
  [INVENTORY_UPDATE] = @(_) unallowedEventEconomicNamesNeedUpdate = true,
  [CONSOLE_PACKS_READY_CHANGED] = @(_) unallowedEventEconomicNamesNeedUpdate = true
}, CONFIG_VALIDATION)

return freeze({
  isEventAllowedByVrMode
  isEventAllowedByComaptibilityMode
  getUnallowedEventEconomicNames
})
