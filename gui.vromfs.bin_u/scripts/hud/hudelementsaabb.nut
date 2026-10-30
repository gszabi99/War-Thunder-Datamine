import "hudState" as hudState
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/hud/hudHitCamera.nut" import getHitCameraAABB
from "%scripts/hud/actionBarState.nut" import actionBarItems
from "%scripts/hud/hudActionBar.nut" import getActionBarObjId
from "%scripts/sqDagui/daguiUtil.nut" import getDaguiObjAabb
from "%appGlobals/hud/hudState.nut" import mpScoreBox
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

let { g_hud_action_bar_type } = require("%scripts/hud/hudActionBarType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

function getAabbObjFromHud(hudFuncName) {
  let handler = handlersManager.findHandlerClassInScene(get_gui_handler("Hud"))
  if (handler == null || !(hudFuncName in handler))
    return null

  return getDaguiObjAabb(handler[hudFuncName]())
}

let hardPersist = mkHardPersist("hud.hudElementsAabb")

let dmPanelStatesAabb = mkHardPersistWatched("hud.hudElementsAabb")("dmPanelStatesAabb", {})
let twsPanelStateAabb = hardPersist("twsPanelStateAabb", {})
let helicopterHudStatesAabb = hardPersist("helicopterHudStatesAabb", {})

let prevHashAabbParams = {}

function getHashAabbParams(params) {
  let { pos = [0, 0], size = [0, 0], visible = false } = params
  return ";".concat(pos[0], pos[1], size[0], size[1], visible)
}

function update_damage_panel_state(params) {
  let hashAabbParams = getHashAabbParams(params)
  if (prevHashAabbParams?["damage_panel"] == hashAabbParams)
    return
  prevHashAabbParams["damage_panel"] <- hashAabbParams
  dmPanelStatesAabb.set(params)
}

function updateTwsPanelState(params) {
  let hashAabbParams = getHashAabbParams(params)
  if (prevHashAabbParams?["tws_panel"] == hashAabbParams)
    return
  prevHashAabbParams["tws_panel"] <- hashAabbParams

  let { pos = [0, 0], size = [0, 0], visible = false } = params
  twsPanelStateAabb.pos <- pos
  twsPanelStateAabb.size <- size
  twsPanelStateAabb.visible <- visible
}

function updateHelicopterHudAabbState(params) {
  let { partName = "", pos = [0, 0], size = [0, 0], visible = false } = params

  if (partName == "")
    return
  let hashAabbParams = getHashAabbParams(params)
  if (prevHashAabbParams?[partName] == hashAabbParams)
    return

  prevHashAabbParams[partName] <- hashAabbParams
  helicopterHudStatesAabb[partName] <- { pos, size, visible }
}

function getHelicopterHudAabb(partName) {
  return helicopterHudStatesAabb?[partName].visible ? helicopterHudStatesAabb[partName] : null
}

function getTwsRadarAabb() {
  return twsPanelStateAabb?.visible ? twsPanelStateAabb : null
}

function getDamagePannelAabb() {
  let aabbState = dmPanelStatesAabb.get()
  return aabbState?.visible ? aabbState : null
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
  let handler = handlersManager.findHandlerClassInScene(get_gui_handler("Hud"))
  let actionBarObj = handler?.getHudActionBarObj()
  if (!actionBarObj?.isValid())
    return null

  if (actionTypeName == null)
    return getDaguiObjAabb(actionBarObj)

  let actionTypeCode = g_hud_action_bar_type?[actionTypeName].code ?? -1
  if (actionTypeCode == -1)
    return null

  let actionItemIdx = actionBarItems.get().findindex(@(a) a.type == actionTypeCode) ?? -1
  if (actionItemIdx == -1)
    return null

  let nestActionObj = actionBarObj.findObject(getActionBarObjId(actionItemIdx))
  if (!nestActionObj?.isValid())
    return null

  return getDaguiObjAabb(nestActionObj.findObject("itemContent"))
}

let aabbList = {
  map = @() getAabbObjFromHud("getTacticalMapObj")
  rwr = getTwsRadarAabb
  hitCamera = @() getHitCameraAABB()
  multiplayerScore = @() mpScoreBox.get()
  dmPanel = getDamagePannelAabb
  tankDebuffs = getDamagePannelAabb
  aircraftInstruments = getAircraftInstrumentsAabb
  actionBarItem = getActionBarItemAabb
  verticalSpeed = @() getHelicopterHudAabb("verticalSpeed")
  velocityVector = @() getHelicopterHudAabb("velocityVector")
  altimeter = @() getHelicopterHudAabb("altimeter")
  attitudeIndicator = @() getHelicopterHudAabb("attitudeIndicator")
  rotorPitch0 = @() getHelicopterHudAabb("rotorPitch0")
  rotorRpm = @() getHelicopterHudAabb("rotorRpm")
  speed = @() getHelicopterHudAabb("speed")
}

function getHudElementAabb(elemId) {
  let [name = null, params = null] = elemId?.split("|")
  return params == null
    ? aabbList?[name]()
    : aabbList?[name](params)
}

registerForNativeCall("get_ingame_map_aabb", @() aabbList.map())

eventbus_subscribe("update_damage_panel_state", @(value) update_damage_panel_state(value))


registerForNativeCall("get_rwr_radar_aabb", @() aabbList.rwr())
eventbus_subscribe("update_tws_panel_state", @(value) updateTwsPanelState(value))

eventbus_subscribe("update_helicopter_hud_aabb_state", @(params) updateHelicopterHudAabbState(params))

return freeze({
  getHudElementAabb
  dmPanelStatesAabb
})