from "%scripts/dagui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")







const TOOLTIP_TRIGGER_OBJ_ID = "scoreboard_tooltip_overlay"
const TOOLTIP_TRIGGER_MARKUP = @"tdiv {
  id:t='{0}'
  position:t='root'
  order-popup:t='yes'
  tooltip:t=''
}".subst(TOOLTIP_TRIGGER_OBJ_ID)

function getTooltipTriggerObj(handler) {
  let obj = handler.scene.findObject(TOOLTIP_TRIGGER_OBJ_ID)
  return obj?.isValid() ? obj : null
}

function createTooltipTriggerObj(handler) {
  handler.guiScene.appendWithBlk(handler.scene, TOOLTIP_TRIGGER_MARKUP, null)
  let obj = handler.scene.findObject(TOOLTIP_TRIGGER_OBJ_ID)
  return obj?.isValid() ? obj : null
}

eventbus_subscribe("scoreboardTooltipUpdate", function(params) {
  let handler = handlersManager.getActiveBaseHandler()
  if (!handler?.isValid())
    return

  let { guiScene } = handler
  let existingTriggerObj = getTooltipTriggerObj(handler)
  let { show, text = "" } = params

  if (show && text != "") {
    if (existingTriggerObj) {
      existingTriggerObj.tooltip = text
      guiScene.updateTooltip(existingTriggerObj)
      return
    }

    let { dargCompAABB = null } = params
    if (!dargCompAABB)
      return
    let triggerObj = createTooltipTriggerObj(handler)
    if (triggerObj == null)
      return

    let { r, l, t, b } = dargCompAABB
    triggerObj["size"] = $"{r - l}, {b - t}"
    triggerObj["pos"] = $"{l}, {t}"
    triggerObj.tooltip = text

    return
  }

  if (existingTriggerObj)
    guiScene.destroyElement(existingTriggerObj)
})