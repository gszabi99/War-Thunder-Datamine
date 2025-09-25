from "%scripts/dagui_library.nut" import *

let { defer } = require("dagor.workcycle")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let events = getGlobalModule("events")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let eSportTournamentModal = require("%scripts/events/eSportTournamentModal.nut")
let { getTourById, getTourParams, isTournamentWndAvailable, getSharedTourNameByEvent } = require("%scripts/events/eSport.nut")
let { hasAlredyActiveJoinProcess } = require("%scripts/events/eventJoinProcess.nut")
let { getEventDisplayType } = require("%scripts/events/eventInfo.nut")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { guiStartModalEvents } = require("%scripts/events/eventsHandler.nut")

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
    let handlerClass = eventDisplayType.showInGamercardDrawer ? gui_handlers.MainMenu
      : !eventDisplayType.showInEventsWindow ? null
      : lastEvent?.chapter == "competitive" ? gui_handlers.ESportTournament
      : gui_handlers.EventsHandler

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
        handler = handlersManager.findHandlerClassInScene(gui_handlers.EventsHandler)
        if (handler)
          handler.goToBattleFromDebriefing()
      })
    }
  })
}

return {
  openLastTournamentWnd
  goToBattleAction
}
