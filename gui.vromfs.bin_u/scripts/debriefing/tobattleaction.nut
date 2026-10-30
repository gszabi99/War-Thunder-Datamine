import "%scripts/events/eSportTournamentModal.nut" as eSportTournamentModal
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/events/eventsManager.nut" import events
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/mainmenu/mainMenuHandler.nut" import MainMenu
from "%scripts/events/eventsHandler.nut" import EventsHandler, guiStartModalEvents
from "%scripts/events/eSport.nut" import getTourById, getTourParams, isTournamentWndAvailable, getSharedTourNameByEvent
from "%scripts/events/eventJoinProcess.nut" import hasAlredyActiveJoinProcess
from "%scripts/events/eventInfo.nut" import getEventDisplayType
from "%scripts/mainmenu/guiStartMainmenu.nut" import gui_start_mainmenu
from "dagor.workcycle" import defer
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

function openLastTournamentWnd(eventParams) {
  gui_start_mainmenu()
  let { economicName } = eventParams
  let lastEvent = events.getEventByEconomicName(economicName)
  let tournament = getTourById(getSharedTourNameByEvent(economicName))
  if (!tournament)
    return

  let curTourParams = getTourParams(tournament)
  if (isTournamentWndAvailable(curTourParams.dayNum))
    eSportTournamentModal({ tournament, curTourParams, curEvent = lastEvent })
}

function goToBattleAction(eventParams) {
  let lastEvent = events.getEventByEconomicName(eventParams?.economicName)
  if (lastEvent == null) {
    log($"Debriefing: not found event for goToBattleAction")
    return
  }

  get_cur_gui_scene().performDelayed({}, function() {
    if (hasAlredyActiveJoinProcess())
      return
    if (g_squad_manager.isSquadMember() && !g_squad_manager.isMeReady()) {
      g_squad_manager.setReadyFlag(true)
      return
    }

    let eventDisplayType = getEventDisplayType(lastEvent)
    let handlerClass = eventDisplayType.showInGamercardDrawer ? MainMenu
      : !eventDisplayType.showInEventsWindow ? null
      : lastEvent?.chapter == "competitive" ? get_gui_handler("ESportTournament")
      : EventsHandler

    if (!handlerClass)
      return

    local handler = handlersManager.findHandlerClassInScene(handlerClass)
    if (handler) {
      handler.goToBattleFromDebriefing()
      return
    }

    if (!handler && eventDisplayType.showInEventsWindow) {
      guiStartModalEvents()
      defer(function() {
        if (hasAlredyActiveJoinProcess())
          return
        handler = handlersManager.findHandlerClassInScene(EventsHandler)
        if (handler)
          handler.goToBattleFromDebriefing()
      })
    }
  })
}

return freeze({
  openLastTournamentWnd
  goToBattleAction
})
