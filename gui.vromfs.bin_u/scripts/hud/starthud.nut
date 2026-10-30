from "%scripts/sqDagui/framework/baseGuiHandlerManager.nut" import isHandlerInScene
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "eventbus" import eventbus_subscribe
from "guiMission" import leave_mp_session, quit_to_debriefing, interrupt_multiplayer
from "mission" import get_current_mission_name
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer
from "app" import pauseGame
from "gameplayBinding" import inFlightMenu
from "%scripts/clientState/clientStates.nut" import isInBattleState
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler

let { handlersManager } = require("%scripts/sqDagui/framework/baseGuiHandlerManager.nut")

local lastLoadedMissionName = null

function gui_start_hud(_ = null) {
  handlersManager.loadHandler(get_gui_handler("Hud"))
  lastLoadedMissionName = get_current_mission_name()
}

function isHudLoadedForCurrentMission() {
  return lastLoadedMissionName != null && lastLoadedMissionName == get_current_mission_name()
    && isHandlerInScene(get_gui_handler("Hud"))
}

isInBattleState.subscribe(@(inBattle) lastLoadedMissionName = inBattle ? lastLoadedMissionName : null)

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
eventbus_subscribe("gui_start_spectator", gui_start_spectator)

return freeze({
  quitMission
  isHudLoadedForCurrentMission
})