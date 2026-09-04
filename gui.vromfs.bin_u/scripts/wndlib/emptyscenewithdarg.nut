from "hangar" import hangar_enable_controls
from "%scripts/dagui_library.nut" import *

let { BaseGuiHandler } = require("%scripts/sqDagui/framework/baseGuiHandler.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
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
