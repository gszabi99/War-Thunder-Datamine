from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/weaponry/weaponryPresetsWndState.nut" import isPresetsWndReserved
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "gameplayBinding" import isInFlight
from "dagor.workcycle" import defer
from "%scripts/dagui_library.nut" import *

return function guiStartWeaponryPresets(params) {
  if (isPresetsWndReserved.get())
    return
  isPresetsWndReserved.set(true)
  broadcastEvent("BeforeOpenWeaponryPresetsWnd")
  let handlerClass = isInFlight() ? get_gui_handler("weaponryPresetsModal")
    : get_gui_handler("weaponryPresetsWnd")
  if (get_cur_gui_scene().isInAct()) {
    defer(@() loadHandler(handlerClass, params))
    return
  }
  loadHandler(handlerClass, params)
}