//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")

let class emptySceneWithDarg extends ::BaseGuiHandler {
  sceneBlkName = "%gui/wndLib/emptySceneWithDarg.blk"
  shouldBlurSceneBgFn = needUseHangarDof
  widgetId = null

  function initScreen() {
    ::enableHangarControls(false, true)
  }

  getWidgetsList = @() this.widgetId == null ? [] : [{ widgetId = this.widgetId }]
}

::gui_handlers.emptySceneWithDarg <- emptySceneWithDarg

return @(params) ::handlersManager.loadHandler(emptySceneWithDarg, params)

