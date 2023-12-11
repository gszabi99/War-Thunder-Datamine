from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { send } = require("eventbus")
let { showHudTankMovementStates } = require("%scripts/hud/hudTankStates.nut")
let { mpTankHudBlkPath } = require("%scripts/hud/hudBlkPath.nut")
let { isDmgIndicatorVisible } = require("gameplayBinding")
let { initIconedHints } = require("%scripts/hud/iconedHints.nut")
let { ActionBar } = require("%scripts/hud/hudActionBar.nut")

let HudTank = class (gui_handlers.BaseUnitHud) {
  sceneBlkName = mpTankHudBlkPath.value

  function initScreen() {
    base.initScreen()
    ::g_hud_display_timers.init(this.scene, ES_UNIT_TYPE_TANK)
    initIconedHints(this.scene, ES_UNIT_TYPE_TANK)
    ::g_hud_tank_debuffs.init(this.scene)
    ::g_hud_crew_state.init(this.scene)
    showHudTankMovementStates(this.scene)
    ::hudEnemyDamage.init(this.scene)
    this.actionBar = ActionBar(this.scene.findObject("hud_action_bar"))
    this.updateShowHintsNest()
    this.updatePosHudMultiplayerScore()

    ::g_hud_event_manager.subscribe("DamageIndicatorToggleVisbility",
      @(_eventData) this.updateDamageIndicatorBackground(),
      this)
    ::g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(_ed) { this.updateDmgIndicatorState() },
      this)
  }

  function reinitScreen(_params = {}) {
    this.actionBar.reinit()
    ::hudEnemyDamage.reinit()
    ::g_hud_display_timers.reinit()
    ::g_hud_tank_debuffs.reinit()
    ::g_hud_crew_state.reinit()
    this.updateShowHintsNest()
  }

  function updateDamageIndicatorBackground() {
    let visMode = ::g_hud_vis_mode.getCurMode()
    let isDmgPanelVisible = isDmgIndicatorVisible() && visMode.isPartVisible(HUD_VIS_PART.DMG_PANEL)
    showObjById("tank_background", isDmgPanelVisible, this.scene)
  }

  function updateShowHintsNest() {
    this.showSceneBtn("actionbar_hints_nest", true)
  }

  function updateDmgIndicatorState() {
    let obj = this.scene.findObject("hud_tank_damage_indicator")
    if (obj?.isValid())
      send("updateDmgIndicatorStates", {
        size = obj.getSize()
        pos = obj.getPos()
      })
  }
}

return {
  HudTank
}