from "%scripts/dagui_library.nut" import *

let { is_player_unit_alive } = require("unit")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { eventbus_subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getHudGuiState, HudGuiState } = require("hudState")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")

let isInKillerCam = @() getHudGuiState() == HudGuiState.GUI_STATE_KILLER_CAMERA

let isInKillerCamera = Watched(isInKillerCam())
let isPlayerAlive = Watched(is_player_unit_alive())

isInKillerCamera.subscribe(function(_) {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  if (handler == null)
    return
  handler.doWhenActiveOnce("updateHudVisModeForce")
})

eventbus_subscribe("hud_gui_state_changed",
  @(_) isInKillerCamera(isInKillerCam()))

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