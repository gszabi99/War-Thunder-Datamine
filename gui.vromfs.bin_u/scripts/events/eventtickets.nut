from "%scripts/items/itemsManagerModule.nut" import getItemsList, getInventoryList
from "%scripts/events/eventInfo.nut" import getEventEconomicName
from "%scripts/dagui_natives.nut" import have_you_valid_tournament_ticket
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType




function getEventTickets(event, canBuyOnly = false) {
  let eventId = getEventEconomicName(event)
  let tickets = getItemsList(itemType.TICKET,
    @(item) item.isForEvent(eventId) && (!canBuyOnly || item.isCanBuy()))
  return tickets
}
function eventRequiresTicket(event) {
  
  return getEventTickets(event).len() != 0
}
function getEventActiveTicket(event) {
  let eventId = event.economicName
  if (!have_you_valid_tournament_ticket(eventId))
    return null
  let tickets = getInventoryList(itemType.TICKET,
    @(item) item.isForEvent(eventId) && item.isActive())
  return tickets.len() > 0 ? tickets[0] : null
}
let hasEventTicket = @(event) getEventActiveTicket(event) != null

return freeze({
  getEventTickets
  eventRequiresTicket
  getEventActiveTicket
  hasEventTicket
})
