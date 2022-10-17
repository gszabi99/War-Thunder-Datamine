from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")

let class emptySceneWithDarg extends ::BaseGuiHandler {
  sceneBlkName = "%gui/wndLib/emptySceneWithDarg.blk"
  shouldBlurSceneBgFn = needUseHangarDof
  widgetId = null

  function initScreen() {
    ::enableHangarControls(false, true)
  }

  getWidgetsList = @() widgetId == null ? null : [{ widgetId = widgetId }]
}

::gui_handlers.emptySceneWithDarg <- emptySceneWithDarg

return @(params) ::handlersManager.loadHandler(emptySceneWithDarg, params)

