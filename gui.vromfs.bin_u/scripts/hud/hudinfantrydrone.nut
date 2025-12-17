from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART
let { g_hud_vis_mode } =  require("%scripts/hud/hudVisMode.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { mkActionBarAir } = require("%scripts/hud/hudActionBar.nut")
let { hudDisplayTimersInit, hudDisplayTimersReInit } = require("%scripts/hud/hudDisplayTimers.nut")
let { setForcedHudType } = require("guiTacticalMap")
let { is_replay_playing } = require("replays")
let { eventbus_send } = require("eventbus")

gui_handlers.HudInfantryDrone <- class(gui_handlers.BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudInfantryDrone.blk"

  function initScreen() {
    base.initScreen()
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_AIRCRAFT)
    let actionBar = mkActionBarAir(this.scene.findObject("hud_action_bar"))
    this.actionBarWeak = actionBar.weakref()

    this.updateTacticalMapVisibility()
    this.updateDmgIndicatorSize()
    this.updateShowHintsNest()
    this.updatePosHudMultiplayerScore()

    g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(_ed) { this.updateDmgIndicatorSize() },
      this)
  }

  function reinitScreen(_params = null) {
    hudDisplayTimersReInit()
    this.updateTacticalMapVisibility()
    this.updateDmgIndicatorSize()
    this.updateShowHintsNest()
    this.actionBarWeak.reinit()
  }

  function updateTacticalMapVisibility() {
    let isVisible = !is_replay_playing() && g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
    showObjById("hud_small_tactical_map_bg", isVisible, this.scene)
    setForcedHudType(HUD_TYPE_INFANTRY)
  }

  function updateDmgIndicatorSize() {
    let obj = this.scene.findObject("xray_render_dmg_indicator")
    if (obj?.isValid())
      eventbus_send("updateDmgIndicatorStates", { size = obj.getSize() })
  }

  function updateShowHintsNest() {
    showObjById("actionbar_hints_nest", false, this.scene)
  }
}

return {
  HudInfantryDrone = gui_handlers.HudInfantryDrone
}