from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_TYPE

let { g_hud_action_bar_type } = require("%scripts/hud/hudActionBarType.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let hudState = require("hudState")
let { getHitCameraAABB } = require("%scripts/hud/hudHitCamera.nut")
let { eventbus_subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { actionBarItems } = require("%scripts/hud/actionBarState.nut")
let { getActionBarObjId } = require("%scripts/hud/hudActionBar.nut")
let { getDaguiObjAabb } = require("%sqDagui/daguiUtil.nut")

function getAabbObjFromHud(hudFuncName) {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  if (handler == null || !(hudFuncName in handler))
    return null

  return getDaguiObjAabb(handler[hudFuncName]())
}

let dmPanelStatesAabb = mkWatched(persist, "dmPanelStatesAabb", {})

local prevHashAabbParams = ""

function getHashAabbParams(params) {
  let {pos = [0, 0], size = [0, 0], visible = false} = params
  return ";".concat(pos[0], pos[1], size[0], size[1], visible)
}

function update_damage_panel_state(params) {
  let hashAabbParams = getHashAabbParams(params)
  if(prevHashAabbParams == hashAabbParams)
    return
  prevHashAabbParams = hashAabbParams
  dmPanelStatesAabb(params)
}

function getDamagePannelAabb() {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  if (!handler)
    return null
  let hudType = handler.getHudType()
  return hudType == HUD_TYPE.SHIP || hudType == HUD_TYPE.TANK ? dmPanelStatesAabb.get()
    : getDaguiObjAabb(handler.getDamagePannelObj())
}

function getAircraftInstrumentsAabb() {
  let bbox = hudState.getHudAircraftInstrumentsBbox()
  if (bbox == null || bbox.x2 == 0 || bbox.y2 == 0)
    return null
  return {
    pos  = [ bbox.x1, bbox.y1 ]
    size = [ bbox.x2 - bbox.x1, bbox.y2 - bbox.y1 ]
    visible = true
  }
}

function getActionBarItemAabb(actionTypeName = null) {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.Hud)
  let actionBarObj = handler?.getHudActionBarObj()
  if (!actionBarObj?.isValid())
    return null

  if (actionTypeName == null)
    return getDaguiObjAabb(actionBarObj)

  let actionTypeCode = g_hud_action_bar_type?[actionTypeName].code ?? -1
  if (actionTypeCode == -1)
    return null

  let actionItemIdx = actionBarItems.value.findindex(@(a) a.type == actionTypeCode) ?? -1
  if (actionItemIdx == -1)
    return null

  let nestActionObj = actionBarObj.findObject(getActionBarObjId(actionItemIdx))
  if (!nestActionObj?.isValid())
    return null

  return getDaguiObjAabb(nestActionObj.findObject("itemContent"))
}

let aabbList = {
  map = @() getAabbObjFromHud("getTacticalMapObj")
  hitCamera = @() getHitCameraAABB()
  multiplayerScore = @() getAabbObjFromHud("getMultiplayerScoreObj")
  dmPanel = getDamagePannelAabb
  tankDebuffs = @() getAabbObjFromHud("getTankDebufsObj")
  aircraftInstruments = getAircraftInstrumentsAabb
  actionBarItem = getActionBarItemAabb
}

function getHudElementAabb(elemId) {
  let [name = null, params = null] = elemId?.split("|")
  return params == null
    ? aabbList?[name]()
    : aabbList?[name](params)
}

registerForNativeCall("get_ingame_map_aabb", function get_ingame_map_aabb() {
  return aabbList.map()
})

eventbus_subscribe("update_damage_panel_state", @(value) update_damage_panel_state(value))

return {
  getHudElementAabb
  dmPanelStatesAabb
}