from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")

gui_handlers.HudFreeCam <- class(gui_handlers.BaseUnitHud) {
  sceneBlkName = "%gui/wndLib/emptySceneWithDarg.blk"
}

return {
  HudFreeCam = gui_handlers.HudFreeCam
}