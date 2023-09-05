//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { hangar_enable_controls } = require("hangar")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let class emptySceneWithDarg extends ::BaseGuiHandler {
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

gui_handlers.emptySceneWithDarg <- emptySceneWithDarg

return @(params) handlersManager.loadHandler(emptySceneWithDarg, params)

