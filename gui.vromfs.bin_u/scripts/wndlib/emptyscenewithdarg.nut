local class emptySceneWithDarg extends ::gui_handlers.BaseGuiHandlerWT {
  sceneBlkName = "gui/wndLib/emptySceneWithDarg.blk"
}

::gui_handlers.emptySceneWithDarg <- emptySceneWithDarg

return @(params) ::handlersManager.loadHandler(emptySceneWithDarg, params)

