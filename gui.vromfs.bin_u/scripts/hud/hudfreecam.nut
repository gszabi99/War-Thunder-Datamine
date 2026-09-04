from "%scripts/dagui_library.nut" import *
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseUnitHud } = require("%scripts/hud/baseUnitHud.nut")

let HudFreeCam = class(BaseUnitHud) {
  sceneBlkName = "%gui/wndLib/emptySceneWithDarg.blk"
}
register_gui_handler("HudFreeCam", HudFreeCam)

return {
  HudFreeCam
}