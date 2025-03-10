from "%scripts/dagui_natives.nut" import pause_game, in_flight_menu
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

let { eventbus_subscribe } = require("eventbus")
let { leave_mp_session, quit_to_debriefing, interrupt_multiplayer
} = require("guiMission")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

function gui_start_hud(_ = null) {
  handlersManager.loadHandler(gui_handlers.Hud)
}

function gui_start_hud_no_chat(_) {
  
  
  gui_start_hud()
}

function gui_start_spectator(_) {
  handlersManager.loadHandler(gui_handlers.Hud, { spectatorMode = true })
}

function quitMission() {
  in_flight_menu(false)
  pause_game(false)
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