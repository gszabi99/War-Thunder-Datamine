from "gameplayBinding" import isShowTankMinimap
from "replays" import is_replay_playing
from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let { g_hud_vis_mode } = require("%scripts/hud/hudVisMode.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { mkActionBarAir } = require("%scripts/hud/hudActionBar.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { HudWithWeaponSelector } = require("%scripts/hud/hudWithWeaponSelector.nut")
let hudEnemyDamage = require("%scripts/hud/hudEnemyDamage.nut")

let HudHeli = class (HudWithWeaponSelector) {
  sceneBlkName = "%gui/hud/hudHelicopter.blk"

  function initScreen() {
    base.initScreen()
    hudEnemyDamage.init(this.scene)
    let actionBar = mkActionBarAir(this.scene.findObject("hud_action_bar"))
    this.actionBarWeak = actionBar.weakref()
    this.updatePosHudMultiplayerScore()
    this.updateTacticalMapVisibility()
    this.createAirWeaponSelector(getPlayerCurUnit())
  }

  function reinitScreen(_params = null) {
    base.reinitScreen()
    this.actionBarWeak?.reinit()
    this.updateTacticalMapVisibility()
    hudEnemyDamage.reinit()
  }

  function updateTacticalMapVisibility() {
    let shouldShowMapForHelicopter = isShowTankMinimap()
    let isVisible = shouldShowMapForHelicopter && !is_replay_playing()
      && g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
    showObjById("hud_tactical_map_bg", isVisible, this.scene)
  }
}
register_gui_handler("HudHeli", HudHeli)

return {
  HudHeli
}