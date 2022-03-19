local backToMainScene = require("scripts/mainmenu/backToMainScene.nut")
local lastBaseHandlerStartData = null

local function setBreadcrumbGoBackParams(handler)
{
  if (!handler.isValid())
    return

  if (!lastBaseHandlerStartData)
    lastBaseHandlerStartData = clone ::handlersManager.findLastBaseHandlerStartData(handler.guiScene)
  handler.backSceneFunc = lastBaseHandlerStartData?.handlerLocId
    ? lastBaseHandlerStartData?.startFunc : backToMainScene
  local handlerLocId = lastBaseHandlerStartData?.handlerLocId ?? "mainmenu/hangar"
  local backSceneObj = handler.scene.findObject("back_scene_name")
  if (!backSceneObj?.isValid())
    return

  backSceneObj.setValue(::loc(handlerLocId))
}

::add_event_listener("SwitchedBaseHandler", function(p) {
  local handlerClass = ::handlersManager.getActiveBaseHandler()?.getclass()
  if(handlerClass == ::gui_handlers.MainMenu || handlerClass == ::gui_handlers.Hud)
    lastBaseHandlerStartData = null
}, this)

return {
  setBreadcrumbGoBackParams = setBreadcrumbGoBackParams
}