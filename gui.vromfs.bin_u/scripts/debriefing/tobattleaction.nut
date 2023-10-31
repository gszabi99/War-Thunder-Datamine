//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let eSportTournamentModal = require("%scripts/events/eSportTournamentModal.nut")
let { getTourById, getTourParams, isTournamentWndAvailable, getSharedTourNameByEvent } = require("%scripts/events/eSport.nut")
let { hasAlredyActiveJoinProcess } = require("%scripts/events/eventJoinProcess.nut")
let { getEventDisplayType } = require("%scripts/events/eventInfo.nut")

let function openLastTournamentWnd(lastEvent) {
  ::gui_start_mainmenu()
  let tournament = getTourById(getSharedTourNameByEvent(lastEvent.economicName))
  if (!tournament)
    return

  let curTourParams = getTourParams(tournament)
  if (isTournamentWndAvailable(curTourParams.dayNum))
    eSportTournamentModal({ tournament, curTourParams, curEvent = lastEvent })
}

local function goToBattleAction(lastEvent) {
  if (lastEvent == null) {
    log($"Debriefing: not found event for goToBattleAction")
    return
  }

  get_cur_gui_scene().performDelayed({}, function() {
    if (hasAlredyActiveJoinProcess())
      return
    if (::g_squad_manager.isSquadMember() && !::g_squad_manager.isMeReady()) {
      ::g_squad_manager.setReadyFlag(true)
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
      ::gui_start_modal_events()
      get_cur_gui_scene().performDelayed(getroottable(), function() {
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
