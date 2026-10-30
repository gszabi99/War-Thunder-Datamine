import "%scripts/mainmenu/backToMainScene.nut" as backToMainScene
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/hud/hud.nut" import Hud
from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
local lastBaseHandlerStartData = null

let getBackSceneName = @() loc(lastBaseHandlerStartData?.handlerLocId ?? "mainmenu/hangar")

function updateBackSceneObj(handler) {
  handler.backSceneParams = lastBaseHandlerStartData?.handlerLocId
    ? lastBaseHandlerStartData?.startParams : backToMainScene()
  let backSceneObj = handler.scene.findObject("back_scene_name")
  if (!backSceneObj?.isValid())
    return

  backSceneObj.setValue(getBackSceneName())
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

return freeze({
  setBreadcrumbGoBackParams
  setModalBreadcrumbGoBackParams
  getBackSceneName
})