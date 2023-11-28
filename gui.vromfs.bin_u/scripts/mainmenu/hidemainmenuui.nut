from "%scripts/dagui_library.nut" import *

let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { subscribe } = require("eventbus")
let emptySceneWithDarg = require("%scripts/wndLib/emptySceneWithDarg.nut")

subscribe("hideMainMenuUi", function(params) {
  if (!isInMenu())
    return

  if (params.hide)
    emptySceneWithDarg({ wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL })
  else
    ::gui_start_mainmenu()
})
