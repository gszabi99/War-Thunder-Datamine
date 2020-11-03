local time = require("scripts/time.nut")
local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")


::g_event_ticket_buy_offer <- {

  // Holds process to prevent it
  // from being garbage collected.
  currentProcess = null
}

g_event_ticket_buy_offer.offerTicket <- function offerTicket(event)
{
  ::dagor.assertf(currentProcess == null, "Attempt to use multiple event ticket but offer processes.");
  currentProcess = EventTicketBuyOfferProcess(event)
}

::EventTicketBuyOfferProcess <- class
{
  _event = null
  _tickets = null

  constructor (event)
  {
    _event = event
    _tickets = ::events.getEventTickets(event, true)
    foreach (ticket in _tickets)
      ::g_item_limits.enqueueItem(ticket.id)
    if (::g_item_limits.requestLimits(true))
      ::add_event_listener("ItemLimitsUpdated", onEventItemLimitsUpdated, this)
    else
      handleTickets()
  }

  function onEventItemLimitsUpdated(params)
  {
    subscriptions.removeEventListenersByEnv("ItemLimitsUpdated", this)
    handleTickets()
  }

  function handleTickets()
  {
    ::g_event_ticket_buy_offer.currentProcess = null

    // Array of tickets with valid limit data.
    local availableTickets = []
    foreach (ticket in _tickets)
      if (ticket.getLimitsCheckData().result)
        availableTickets.append(ticket)

    local activeTicket = ::events.getEventActiveTicket(_event)
    if (availableTickets.len() == 0)
    {
      local msgArr = [::loc("events/wait_for_sessions_to_finish/main")]
      if (activeTicket != null)
      {
        local tournamentData = activeTicket.getTicketTournamentData(::events.getEventEconomicName(_event))
        msgArr.append(::loc("events/wait_for_sessions_to_finish/optional", {
          timeleft = time.secondsToString(tournamentData.timeToWait)
        }))
      }
      ::scene_msg_box("cant_join", null,  ::g_string.implode(msgArr, "\n"), [["ok"]], "ok")
    }
    else
    {
      local windowParams = {
        event = _event
        tickets = availableTickets
        activeTicket = activeTicket
      }
      ::gui_start_modal_wnd(::gui_handlers.TicketBuyWindow, windowParams)
    }
  }
}
