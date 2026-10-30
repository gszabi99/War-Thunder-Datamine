from "%scripts/hud/baseUnitHud.nut" import BaseUnitHud

let HudCutscene = class (BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudCutscene.blk"
}

return freeze({
  HudCutscene
})