local { needUseHangarDof } = require("scripts/viewUtils/hangarDof.nut")

local class emptySceneWithDarg extends ::gui_handlers.BaseGuiHandlerWT {
  sceneBlkName = "gui/wndLib/emptySceneWithDarg.blk"
  shouldBlurSceneBgFn = needUseHangarDof
}

::gui_handlers.emptySceneWithDarg <- emptySceneWithDarg

return @(params) ::handlersManager.loadHandler(emptySceneWithDarg, params)

