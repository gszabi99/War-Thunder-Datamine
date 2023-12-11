from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART, HUD_TYPE

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { send } = require("eventbus")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getOwnerUnitName } = require("hudActionBar")
let { is_replay_playing } = require("replays")
let { get_game_type } = require("mission")
let { ActionBar } = require("%scripts/hud/hudActionBar.nut")

let HudAir = class (gui_handlers.BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudAir.blk"

  function initScreen() {
    base.initScreen()
    ::g_hud_display_timers.init(this.scene, ES_UNIT_TYPE_AIRCRAFT)
    this.actionBar = ActionBar(this.scene.findObject("hud_action_bar"))

    this.updateTacticalMapVisibility()
    this.updateDmgIndicatorSize()
    this.updateShowHintsNest()
    this.updatePosHudMultiplayerScore()

    ::g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(_ed) { this.updateDmgIndicatorSize() },
      this)
  }

  function reinitScreen(_params = {}) {
    ::g_hud_display_timers.reinit()
    this.updateTacticalMapVisibility()
    this.updateDmgIndicatorSize()
    this.updateShowHintsNest()
    this.actionBar.reinit()
  }

  function updateTacticalMapVisibility() {
    let shouldShowMapForAircraft = (get_game_type() & GT_RACE) != 0 // Race mission
      || (getPlayerCurUnit()?.tags ?? []).contains("type_strike_ucav") // Strike UCAV in Tanks mission
      || (hasFeature("uavMiniMap") && (getAircraftByName(getOwnerUnitName())?.isTank() ?? false)) // Scout UCAV in Tanks mission
    let isVisible = shouldShowMapForAircraft && !is_replay_playing()
      && ::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
    this.showSceneBtn("hud_air_tactical_map", isVisible)
  }

  function updateDmgIndicatorSize() {
    let obj = this.scene.findObject("xray_render_dmg_indicator")
    if (obj?.isValid())
      send("updateDmgIndicatorStates", { size = obj.getSize() })
  }

  function updateShowHintsNest() {
    this.showSceneBtn("actionbar_hints_nest", false)
  }
}

return {
  HudAir
}