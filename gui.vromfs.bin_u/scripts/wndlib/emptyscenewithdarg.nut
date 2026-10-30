from "%scripts/sqDagui/framework/baseGuiHandler.nut" import BaseGuiHandler
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/viewUtils/hangarDof.nut" import needUseHangarDof
from "hangar" import hangar_enable_controls
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

class emptySceneWithDarg (BaseGuiHandler) {
  sceneBlkName = "%gui/wndLib/emptySceneWithDarg.blk"
  shouldBlurSceneBgFn = needUseHangarDof
  wndControlsAllowMask = null
  widgetId = null

  function initScreen() {
    hangar_enable_controls(false)
  }

  getWidgetsList = @() this.widgetId == null ? [] : [{ widgetId = this.widgetId }]

  getControlsAllowMask = @() this.wndControlsAllowMask
}

register_gui_handler("emptySceneWithDarg", emptySceneWithDarg)

return @(params) handlersManager.loadHandler(emptySceneWithDarg, params)
