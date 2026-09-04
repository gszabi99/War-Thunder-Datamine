from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "%scripts/dagui_library.nut" import *

let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { Hud } = require("%scripts/hud/hud.nut")
let backToMainScene = require("%scripts/mainmenu/backToMainScene.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
local lastBaseHandlerStartData = null

function updateBackSceneObj(handler) {
  handler.backSceneParams = lastBaseHandlerStartData?.handlerLocId
    ? lastBaseHandlerStartData?.startParams : backToMainScene()
  let handlerLocId = lastBaseHandlerStartData?.handlerLocId ?? "mainmenu/hangar"
  let backSceneObj = handler.scene.findObject("back_scene_name")
  if (!backSceneObj?.isValid())
    return

  backSceneObj.setValue(loc(handlerLocId))
}

function setBreadcrumbGoBackParams(handler) {
  if (!handler.isValid())
    return

  if (!lastBaseHandlerStartData)
    lastBaseHandlerStartData = clone handlersManager.findLastBaseHandlerStartData(handler.guiScene)
  updateBackSceneObj(handler)
}

function setModalBreadcrumbGoBackParams(handler) {
  if (!handler.isValid())
    return

  let activeHandler = handlersManager.getActiveBaseHandler()
  if (!activeHandler.isValid())
    return

  lastBaseHandlerStartData = clone handlersManager.findLastBaseHandlerStartData(
    activeHandler.guiScene)
  updateBackSceneObj(handler)
}

add_event_listener("SwitchedBaseHandler", function(_p) {
  let handlerClass = handlersManager.getActiveBaseHandler()?.getclass()
  if (handlerClass == get_gui_handler("MainMenu") || handlerClass == Hud)
    lastBaseHandlerStartData = null
}, this)

return {
  setBreadcrumbGoBackParams
  setModalBreadcrumbGoBackParams
}