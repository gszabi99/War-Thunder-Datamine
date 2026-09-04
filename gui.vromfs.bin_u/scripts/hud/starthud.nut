from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "eventbus" import eventbus_subscribe
from "guiMission" import leave_mp_session, quit_to_debriefing, interrupt_multiplayer
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer
from "app" import pauseGame
from "gameplayBinding" import inFlightMenu

let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/sqDagui/framework/baseGuiHandlerManager.nut")

function gui_start_hud(_ = null) {
  handlersManager.loadHandler(get_gui_handler("Hud"))
}

function gui_start_hud_no_chat(_) {
  
  
  gui_start_hud()
}

function gui_start_spectator(_) {
  handlersManager.loadHandler(get_gui_handler("Hud"), { spectatorMode = true })
}

function quitMission() {
  inFlightMenu(false)
  pauseGame(false)
  gui_start_hud()
  broadcastEvent("PlayerQuitMission")

  if (is_multiplayer())
    return leave_mp_session()

  quit_to_debriefing()
  interrupt_multiplayer(true)
}

eventbus_subscribe("gui_start_hud", gui_start_hud)
eventbus_subscribe("gui_start_hud_no_chat", gui_start_hud_no_chat)
eventbus_subscribe("gui_start_spectator", gui_start_spectator)

return {
  quitMission
}