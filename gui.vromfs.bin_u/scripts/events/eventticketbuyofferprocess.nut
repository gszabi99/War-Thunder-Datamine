from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let time = require("%scripts/time.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")


::g_event_ticket_buy_offer <- {

  // Holds process to prevent it
  // from being garbage collected.
  currentProcess = null
}

::g_event_ticket_buy_offer.offerTicket <- function offerTicket(event)
{
  assert(this.currentProcess == null, "Attempt to use multiple event ticket but offer processes.");
  this.currentProcess = ::EventTicketBuyOfferProcess(event)
}

::EventTicketBuyOfferProcess <- class
{
  _event = null
  _tickets = null

  constructor (event)
  {
    this._event = event
    this._tickets = ::events.getEventTickets(event, true)
    foreach (ticket in this._tickets)
      ::g_item_limits.enqueueItem(ticket.id)
    if (::g_item_limits.requestLimits(true))
      ::add_event_listener("ItemLimitsUpdated", this.onEventItemLimitsUpdated, this)
    else
      this.handleTickets()
  }

  function onEventItemLimitsUpdated(_params)
  {
    subscriptions.removeEventListenersByEnv("ItemLimitsUpdated", this)
    this.handleTickets()
  }

  function handleTickets()
  {
    ::g_event_ticket_buy_offer.currentProcess = null

    // Array of tickets with valid limit data.
    let availableTickets = []
    foreach (ticket in this._tickets)
      if (ticket.getLimitsCheckData().result)
        availableTickets.append(ticket)

    let activeTicket = ::events.getEventActiveTicket(this._event)
    if (availableTickets.len() == 0)
    {
      let msgArr = [loc("events/wait_for_sessions_to_finish/main")]
      if (activeTicket != null)
      {
        let tournamentData = activeTicket.getTicketTournamentData(::events.getEventEconomicName(this._event))
        msgArr.append(loc("events/wait_for_sessions_to_finish/optional", {
          timeleft = time.secondsToString(tournamentData.timeToWait)
        }))
      }
      ::scene_msg_box("cant_join", null,  ::g_string.implode(msgArr, "\n"), [["ok"]], "ok")
    }
    else
    {
      let windowParams = {
        event = this._event
        tickets = availableTickets
        activeTicket = activeTicket
      }
      ::gui_start_modal_wnd(::gui_handlers.TicketBuyWindow, windowParams)
    }
  }
}
