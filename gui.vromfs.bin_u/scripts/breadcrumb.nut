let backToMainScene = require("%scripts/mainmenu/backToMainScene.nut")
local lastBaseHandlerStartData = null

let function setBreadcrumbGoBackParams(handler)
{
  if (!handler.isValid())
    return

  if (!lastBaseHandlerStartData)
    lastBaseHandlerStartData = clone ::handlersManager.findLastBaseHandlerStartData(handler.guiScene)
  handler.backSceneFunc = lastBaseHandlerStartData?.handlerLocId
    ? lastBaseHandlerStartData?.startFunc : backToMainScene
  let handlerLocId = lastBaseHandlerStartData?.handlerLocId ?? "mainmenu/hangar"
  let backSceneObj = handler.scene.findObject("back_scene_name")
  if (!backSceneObj?.isValid())
    return

  backSceneObj.setValue(::loc(handlerLocId))
}

::add_event_listener("SwitchedBaseHandler", function(p) {
  let handlerClass = ::handlersManager.getActiveBaseHandler()?.getclass()
  if(handlerClass == ::gui_handlers.MainMenu || handlerClass == ::gui_handlers.Hud)
    lastBaseHandlerStartData = null
}, this)

return {
  setBreadcrumbGoBackParams = setBreadcrumbGoBackParams
}