//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let hudState = require("hudState")
let { getHitCameraAABB } = require("%scripts/hud/hudHitCamera.nut")
let { subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let function getAabbObjFromHud(hudFuncName) {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  if (handler == null || !(hudFuncName in handler))
    return null

  return ::get_dagui_obj_aabb(handler[hudFuncName]())
}

let dmPanelStatesAabb = persist("dmPanelStatesAabb", @() Watched({}))

local prevHashAabbParams = ""

let function getHashAabbParams(params) {
  let {pos = [0, 0], size = [0, 0], visible = false} = params
  return ";".concat(pos[0], pos[1], size[0], size[1], visible)
}

let function update_damage_panel_state(params) {
  let hashAabbParams = getHashAabbParams(params)
  if(prevHashAabbParams == hashAabbParams)
    return
  prevHashAabbParams = hashAabbParams
  dmPanelStatesAabb(params)
}

let function getDamagePannelAabb() {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  if (!handler)
    return null
  let hudType = handler.getHudType()
  return hudType == HUD_TYPE.SHIP || hudType == HUD_TYPE.TANK ? dmPanelStatesAabb.value
    : ::get_dagui_obj_aabb(handler.getDamagePannelObj())
}

let function getAircraftInstrumentsAabb() {
  let bbox = hudState.getHudAircraftInstrumentsBbox()
  if (bbox == null || bbox.x2 == 0 || bbox.y2 == 0)
    return null
  return {
    pos  = [ bbox.x1, bbox.y1 ]
    size = [ bbox.x2 - bbox.x1, bbox.y2 - bbox.y1 ]
    visible = true
  }
}

let aabbList = {
  map = @() getAabbObjFromHud("getTacticalMapObj")
  hitCamera = @() getHitCameraAABB()
  multiplayerScore = @() getAabbObjFromHud("getMultiplayerScoreObj")
  dmPanel = getDamagePannelAabb
  tankDebuffs = @() getAabbObjFromHud("getTankDebufsObj")
  aircraftInstruments = getAircraftInstrumentsAabb
}

::get_ingame_map_aabb <- function get_ingame_map_aabb() { return aabbList.map() }  //this function used in native code

subscribe("update_damage_panel_state", @(value) update_damage_panel_state(value))

return {
  getHudElementAabb = @(name) aabbList?[name]()
  dmPanelStatesAabb
}