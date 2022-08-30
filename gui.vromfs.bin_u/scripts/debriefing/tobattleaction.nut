let eSportTournamentModal = require("%scripts/events/eSportTournamentModal.nut")
let { getTourById, getTourParams, isTournamentWndAvailable, getSharedTourNameByEvent } = require("%scripts/events/eSport.nut")

let function openLastTournamentWnd(lastEvent) {
  let tournament = getTourById(getSharedTourNameByEvent(lastEvent.economicName))
  if (!tournament)
    return

  let curTourParams = getTourParams(tournament)
  if (isTournamentWndAvailable(curTourParams.dayNum)) {
    ::gui_start_mainmenu()
    eSportTournamentModal({ tournament, curTourParams, curEvent = lastEvent })
  }
}

local goToBattleAction = function() {
  ::get_cur_gui_scene().performDelayed({}, function() {
    if (::g_squad_manager.isSquadMember() && !::g_squad_manager.isMeReady()) {
      ::g_squad_manager.setReadyFlag(true)
      return
    }

    local handler
    let lastEvent = ::events.getEvent(::SessionLobby.lastEventName)
    if (lastEvent?.chapter == "competitive") {
      let tournament = getTourById(getSharedTourNameByEvent(lastEvent.economicName))
      if (!tournament)
        return

      let curTourParams = getTourParams(tournament)
      if (isTournamentWndAvailable(curTourParams.dayNum)) {
        ::gui_start_mainmenu()
        eSportTournamentModal({ tournament, curTourParams, curEvent = lastEvent })
          ?.goToBattleFromDebriefing()
      }
      return
    }
    let eventDisplayType = ::events.getEventDisplayType(lastEvent)
    let handlerClass = eventDisplayType.showInGamercardDrawer ? ::gui_handlers.MainMenu
      : eventDisplayType.showInEventsWindow ? ::gui_handlers.EventsHandler
      : null
    if (!handlerClass)
      return

    handler = ::handlersManager.findHandlerClassInScene(handlerClass)
    if (handler) {
      handler.goToBattleFromDebriefing()
      return
    }

    if (!handler && eventDisplayType.showInEventsWindow) {
      ::gui_start_modal_events()
      ::get_cur_gui_scene().performDelayed(::getroottable(), function() {
        handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.EventsHandler)
        if (handler)
          handler.goToBattleFromDebriefing()
      })
    }
  })
}

return {
  openLastTournamentWnd
  getGoToBattleAction = @() goToBattleAction
  overrideGoToBattleAction = @(func) goToBattleAction = func
}
