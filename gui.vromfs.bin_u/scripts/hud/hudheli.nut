from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let { g_hud_vis_mode } =  require("%scripts/hud/hudVisMode.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { eventbus_send } = require("eventbus")
let { isShowTankMinimap } = require("gameplayBinding")
let { is_replay_playing } = require("replays")

let { ActionBar } = require("%scripts/hud/hudActionBar.nut")

let HudHeli = class (gui_handlers.BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudHelicopter.blk"

  function initScreen() {
    base.initScreen()
    ::hudEnemyDamage.init(this.scene)
    this.actionBar = ActionBar(this.scene.findObject("hud_action_bar"))
    this.updatePosHudMultiplayerScore()
    this.updateTacticalMapVisibility()

    g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      @(_) this.updateDmgIndicatorState(), this)
  }

  function reinitScreen(_params = {}) {
    this.actionBar.reinit()
    this.updateTacticalMapVisibility()
    ::hudEnemyDamage.reinit()
    this.updateDmgIndicatorState()
  }

  function updateDmgIndicatorState() {
    let obj = this.scene.findObject("xray_render_dmg_indicator")
    if (obj?.isValid())
      eventbus_send("updateDmgIndicatorStates", {
        size = obj.getSize()
        pos = obj.getPos()
      })
  }

  function updateTacticalMapVisibility() {
    let shouldShowMapForHelicopter = isShowTankMinimap()
    let isVisible = shouldShowMapForHelicopter && !is_replay_playing()
      && g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
    showObjById("hud_air_tactical_map", isVisible, this.scene)
  }
}

return {
  HudHeli
}