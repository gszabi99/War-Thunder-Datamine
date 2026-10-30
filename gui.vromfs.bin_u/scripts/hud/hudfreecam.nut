from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/hud/baseUnitHud.nut" import BaseUnitHud
from "%scripts/dagui_library.nut" import *

let HudFreeCam = class(BaseUnitHud) {
  sceneBlkName = "%gui/wndLib/emptySceneWithDarg.blk"
}
register_gui_handler("HudFreeCam", HudFreeCam)

return freeze({
  HudFreeCam
})