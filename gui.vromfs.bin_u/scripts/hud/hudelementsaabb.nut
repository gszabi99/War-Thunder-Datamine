let hudState = require("hudState")

let function getAabbObjFromHud(hudFuncName) {
  let handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.Hud)
  if (handler == null || !(hudFuncName in handler))
    return null

  return ::get_dagui_obj_aabb(handler[hudFuncName]())
}

let dmPanelStates = {
  aabb = null
}

let function update_damage_panel_state(params) {
  dmPanelStates.aabb <- params
}

::cross_call_api.update_damage_panel_state <- update_damage_panel_state
::g_script_reloader.registerPersistentData("dmPanelState", dmPanelStates, [ "aabb" ])

let function getDamagePannelAabb() {
  let handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.Hud)
  if (!handler)
    return null
  let hudType = handler.getHudType()
  return hudType == HUD_TYPE.SHIP || hudType == HUD_TYPE.TANK ? dmPanelStates.aabb
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
  hitCamera = @() ::g_hud_hitcamera.getAABB()
  multiplayerScore = @() getAabbObjFromHud("getMultiplayerScoreObj")
  dmPanel = getDamagePannelAabb
  tankDebuffs = @() getAabbObjFromHud("getTankDebufsObj")
  aircraftInstruments = getAircraftInstrumentsAabb
}

::get_ingame_map_aabb <- function get_ingame_map_aabb() { return aabbList.map() }  //this function used in native code
::get_damage_pannel_aabb <- function get_damage_pannel_aabb() { return aabbList.dmPanel() } //this function used in native code

return @(name) aabbList?[name]()