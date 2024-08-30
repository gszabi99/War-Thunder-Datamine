from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { eventbus_subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getHudGuiState, HudGuiState } = require("hudState")

let isInKillerCam = @() getHudGuiState() == HudGuiState.GUI_STATE_KILLER_CAMERA

let isInKillerCamera = Watched(isInKillerCam())

isInKillerCamera.subscribe(function(_) {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  if (handler == null)
    return
  handler.doWhenActiveOnce("updateHudVisModeForce")
})

eventbus_subscribe("hud_gui_state_changed",
  @(_) isInKillerCamera(isInKillerCam()))

return {
  isInKillerCamera
}