from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART, HUD_TYPE

let { g_hud_vis_mode } =  require("%scripts/hud/hudVisMode.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { eventbus_send } = require("eventbus")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getOwnerUnitName } = require("hudActionBar")
let { is_replay_playing } = require("replays")
let { get_game_type } = require("mission")
let { ActionBar } = require("%scripts/hud/hudActionBar.nut")
let { HudWithWeaponSelector } = require("%scripts/hud/hudWithWeaponSelector.nut")

gui_handlers.HudAir <- class (HudWithWeaponSelector) {
  sceneBlkName = "%gui/hud/hudAir.blk"
  function initScreen() {
    base.initScreen()
    ::g_hud_display_timers.init(this.scene, ES_UNIT_TYPE_AIRCRAFT)
    this.actionBar = ActionBar(this.scene.findObject("hud_action_bar"))

    this.updateTacticalMapVisibility()
    this.updateDmgIndicatorSize()
    this.updateShowHintsNest()
    this.updatePosHudMultiplayerScore()
    this.createAirWeaponSelector(getPlayerCurUnit())

    g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(_ed) { this.updateDmgIndicatorSize() },
      this)
  }

  function reinitScreen(_params = null) {
    base.reinitScreen()
    ::g_hud_display_timers.reinit()
    this.updateTacticalMapVisibility()
    this.updateDmgIndicatorSize()
    this.updateShowHintsNest()
    this.actionBar.reinit()
  }

  function updateTacticalMapVisibility() {
    let ownerUnit = getAircraftByName(getOwnerUnitName())
    let shouldShowMapForAircraft = (get_game_type() & GT_RACE) != 0 // Race mission
      || (getPlayerCurUnit()?.tags ?? []).contains("type_strike_ucav") // Strike UCAV in Tanks mission
      || (hasFeature("uavMiniMap") && ((ownerUnit?.isTank() ?? false)
                                   || (ownerUnit?.isShip() ?? false))) // Scout UCAV in Tanks/Ships mission
    let isVisible = shouldShowMapForAircraft && !is_replay_playing()
      && g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
    showObjById("hud_air_tactical_map", isVisible, this.scene)
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
  HudAir = gui_handlers.HudAir
}