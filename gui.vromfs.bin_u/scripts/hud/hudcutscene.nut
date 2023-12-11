let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")

let HudCutscene = class (gui_handlers.BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudCutscene.blk"
}

return {
  HudCutscene
}