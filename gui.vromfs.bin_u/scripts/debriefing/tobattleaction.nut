let eSportTournamentModal = require("%scripts/events/eSportTournamentModal.nut")
let { getTourById, getTourParams, isTournamentWndAvailable, getSharedTourNameByEvent } = require("%scripts/events/eSport.nut")

let function openLastTournamentWnd(lastEvent) {
  ::gui_start_mainmenu()
  let tournament = getTourById(getSharedTourNameByEvent(lastEvent.economicName))
  if (!tournament)
    return

  let curTourParams = getTourParams(tournament)
  if (isTournamentWndAvailable(curTourParams.dayNum))
    eSportTournamentModal({ tournament, curTourParams, curEvent = lastEvent })
}

local goToBattleAction = function() {
  ::get_cur_gui_scene().performDelayed({}, function() {
    if (::g_squad_manager.isSquadMember() && !::g_squad_manager.isMeReady()) {
      ::g_squad_manager.setReadyFlag(true)
      return
    }

    let lastEvent = ::events.getEvent(::SessionLobby.lastEventName)
    let eventDisplayType = ::events.getEventDisplayType(lastEvent)
    let handlerClass = eventDisplayType.showInGamercardDrawer ? ::gui_handlers.MainMenu
      : !eventDisplayType.showInEventsWindow ? null
      : lastEvent?.chapter == "competitive" ? ::gui_handlers.ESportTournament
      : ::gui_handlers.EventsHandler

    if (!handlerClass)
      return

    local handler = ::handlersManager.findHandlerClassInScene(handlerClass)
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
