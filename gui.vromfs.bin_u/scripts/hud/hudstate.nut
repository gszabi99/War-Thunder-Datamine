from "unit" import is_player_unit_alive
from "eventbus" import eventbus_subscribe
from "hudState" import getHudGuiState, HudGuiState
from "%scripts/dagui_library.nut" import *

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")

let isInKillerCam = @() getHudGuiState() == HudGuiState.GUI_STATE_KILLER_CAMERA

let isInKillerCamera = Watched(isInKillerCam())
let isPlayerAlive = Watched(is_player_unit_alive())

eventbus_subscribe("hud_gui_state_changed",
  @(_) isInKillerCamera.set(isInKillerCam()))

function updateHudStatesSubscribes() {
  g_hud_event_manager.subscribe("LocalPlayerDead", @(_) isPlayerAlive.set(false))
  g_hud_event_manager.subscribe("LocalPlayerAlive", @(_) isPlayerAlive.set(true))
  isPlayerAlive.set(is_player_unit_alive())
}

return {
  isInKillerCamera
  isPlayerAlive
  updateHudStatesSubscribes
}