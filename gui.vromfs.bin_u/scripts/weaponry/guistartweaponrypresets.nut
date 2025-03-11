from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isInFlight } = require("gameplayBinding")
let { defer } = require("dagor.workcycle")

return function guiStartWeaponryPresets(params) {
  broadcastEvent("BeforeOpenWeaponryPresetsWnd")
  let handlerClass = isInFlight() ? gui_handlers.weaponryPresetsModal
    : gui_handlers.weaponryPresetsWnd
  if (get_cur_gui_scene().isInAct()) {
    defer(@() loadHandler(handlerClass, params))
    return
  }
  loadHandler(handlerClass, params)
}