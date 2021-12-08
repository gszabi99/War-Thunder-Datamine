local { needUseHangarDof } = require("scripts/viewUtils/hangarDof.nut")

local class emptySceneWithDarg extends ::BaseGuiHandler {
  sceneBlkName = "gui/wndLib/emptySceneWithDarg.blk"
  shouldBlurSceneBgFn = needUseHangarDof
  widgetId = null

  getWidgetsList = @() widgetId == null ? null : [{ widgetId = widgetId }]
}

::gui_handlers.emptySceneWithDarg <- emptySceneWithDarg

return @(params) ::handlersManager.loadHandler(emptySceneWithDarg, params)

