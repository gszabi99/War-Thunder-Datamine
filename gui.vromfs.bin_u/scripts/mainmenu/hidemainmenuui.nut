import "%scripts/wndLib/emptySceneWithDarg.nut" as emptySceneWithDarg
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/mainmenu/guiStartMainmenu.nut" import gui_start_mainmenu
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

eventbus_subscribe("hideMainMenuUi", function(params) {
  if (!isInMenu.get())
    return

  if (params.hide)
    emptySceneWithDarg({ wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL })
  else
    gui_start_mainmenu()
})
