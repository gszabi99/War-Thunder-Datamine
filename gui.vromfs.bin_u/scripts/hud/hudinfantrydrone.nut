from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART
let { g_hud_vis_mode } =  require("%scripts/hud/hudVisMode.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { mkActionBarAir } = require("%scripts/hud/hudActionBar.nut")
let { hudDisplayTimersInit, hudDisplayTimersReInit } = require("%scripts/hud/hudDisplayTimers.nut")
let { setForcedHudType } = require("guiTacticalMap")
let { is_replay_playing } = require("replays")

gui_handlers.HudInfantryDrone <- class(gui_handlers.BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudInfantryDrone.blk"

  function initScreen() {
    base.initScreen()
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_AIRCRAFT)
    let actionBar = mkActionBarAir(this.scene.findObject("hud_action_bar"))
    this.actionBarWeak = actionBar.weakref()

    this.updateTacticalMapVisibility()
    this.updatePosHudMultiplayerScore()
  }

  function reinitScreen(_params = null) {
    hudDisplayTimersReInit()
    this.updateTacticalMapVisibility()
    this.actionBarWeak.reinit()
  }

  function updateTacticalMapVisibility() {
    let isVisible = !is_replay_playing() && g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
    showObjById("hud_small_tactical_map_bg", isVisible, this.scene)
    setForcedHudType(HUD_TYPE_INFANTRY)
  }
}

return {
  HudInfantryDrone = gui_handlers.HudInfantryDrone
}