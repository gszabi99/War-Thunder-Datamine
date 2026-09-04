from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "eventbus" import eventbus_send
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { clearActivePenetrationGraphRequest } = require("%scripts/weaponry/penetrationGraphDataRequest.nut")

const PENETRATION_GRAPH_NEST_ID = "graph_nest"

local penetrationGraphHandler = null
local activeObj = null
local pendingObj = null
local pendingHandler = null

function setPenetrationGraphWidget(handler, show) {
  
  
  if (penetrationGraphHandler?.isValid())
    penetrationGraphHandler.widgetsList = (penetrationGraphHandler.widgetsList ?? [])
      .filter(@(w) w.placeholderId != PENETRATION_GRAPH_NEST_ID)
  penetrationGraphHandler = null

  if (show && handler?.isValid()) {
    handler.widgetsList = (handler.widgetsList ?? [])
      .filter(@(w) w.placeholderId != PENETRATION_GRAPH_NEST_ID)
    handler.widgetsList.append({
      widgetId = DargWidgets.BULLETS_PENETRATION
      placeholderId = PENETRATION_GRAPH_NEST_ID
    })
    penetrationGraphHandler = handler
  }
  handlersManager.updateWidgets()
}

function updatePendingPenetrationGraph(obj, handler) {
  if (!obj?.isValid())
    return

  let graphObj = obj.findObject(PENETRATION_GRAPH_NEST_ID)
  activeObj = obj
  
  
  eventbus_send("update_bullets_penetration_graph_state", {
    graphData = { graphSize = graphObj.getSize() }
  })

  activeObj.getScene().applyPendingChanges(false)
  setPenetrationGraphWidget(handler, true)
}

function clearPenetrationGraphWidget() {
  activeObj = null
  setPenetrationGraphWidget(null, false)
  clearActivePenetrationGraphRequest()
  eventbus_send("update_bullets_penetration_graph_state", {
    graphData = { graphParams = [], graphSize = [0, 0] }
  })
}

function setPendingPenetrationGraph(obj, handler) {
  pendingObj = obj
  pendingHandler = handler
}

addListenersWithoutEnv({
  
  ModalInfoPositioned = function(p) {
    if (!pendingObj?.isValid() || !pendingObj.isEqual(p.infoWnd))
      return
    let obj = pendingObj
    let handler = pendingHandler
    pendingObj = null
    pendingHandler = null
    updatePendingPenetrationGraph(obj, handler)
  }

  RemoveOpenedModalInfo = function(p) {
    if (activeObj == null)
      return
    let isClosed = (p?.objs ?? [])
      .findindex(@(o) o?.isValid() && activeObj.isValid() && o.isEqual(activeObj)) != null
    if (!isClosed)
      return
    clearPenetrationGraphWidget()
  }
})

return {
  setPendingPenetrationGraph
  clearPenetrationGraphWidget
}
