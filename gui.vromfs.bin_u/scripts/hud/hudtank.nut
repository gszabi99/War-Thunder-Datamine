from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let { getUAVCameraEnabled, getShowUAVCameraToggle } = require("hudTankStates")
let { g_hud_vis_mode } =  require("%scripts/hud/hudVisMode.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { eventbus_send } = require("eventbus")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { showHudTankMovementStates } = require("%scripts/hud/hudTankStates.nut")
let { isDmgIndicatorVisible } = require("gameplayBinding")
let { initIconedHints } = require("%scripts/hud/iconedHints.nut")
let { ActionBar } = require("%scripts/hud/hudActionBar.nut")
let { g_hud_tank_debuffs } = require("%scripts/hud/hudTankDebuffs.nut")
let { g_hud_crew_state } = require("%scripts/hud/hudCrewState.nut")
let { hudDisplayTimersInit, hudDisplayTimersReInit } = require("%scripts/hud/hudDisplayTimers.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")

function updateTacticalMapSwitchingObj(obj, value) {
  obj.findObject("map_btn").toggled = value ? "no" : "yes"
  obj.findObject("uav_btn").toggled = value ? "yes" : "no"
}

let switchTacticalMapView = @() toggleShortcut("ID_TOGGLE_UAV_CAMERA")

let HudTank = class (gui_handlers.BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudTank.blk"

  function initScreen() {
    base.initScreen()
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_TANK)
    initIconedHints(this.scene, ES_UNIT_TYPE_TANK)
    g_hud_tank_debuffs.init(this.scene)
    g_hud_crew_state.init(this.scene)
    showHudTankMovementStates(this.scene)
    ::hudEnemyDamage.init(this.scene)
    this.actionBar = ActionBar(this.scene.findObject("hud_action_bar"))
    this.updateShowHintsNest()
    this.updatePosHudMultiplayerScore()
    this.updateTacticalMapSwitching()

    g_hud_event_manager.subscribe("DamageIndicatorToggleVisbility",
      @(_eventData) this.updateDamageIndicatorBackground(),
      this)
    g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(_ed) { this.updateDmgIndicatorState() },
      this)
  }

  function reinitScreen(_params = {}) {
    this.actionBar.reinit()
    ::hudEnemyDamage.reinit()
    hudDisplayTimersReInit()
    g_hud_tank_debuffs.reinit()
    g_hud_crew_state.reinit()
    this.updateShowHintsNest()
    this.updateTacticalMapSwitching()
  }

  function updateDamageIndicatorBackground() {
    let visMode = g_hud_vis_mode.getCurMode()
    let isDmgPanelVisible = isDmgIndicatorVisible() && visMode.isPartVisible(HUD_VIS_PART.DMG_PANEL)
    showObjById("tank_background", isDmgPanelVisible, this.scene)
  }

  function updateShowHintsNest() {
    showObjById("actionbar_hints_nest", true, this.scene)
  }

  function updateDmgIndicatorState() {
    let obj = this.scene.findObject("hud_tank_damage_indicator")
    if (obj?.isValid())
      eventbus_send("updateDmgIndicatorStates", {
        size = obj.getSize()
        pos = obj.getPos()
      })
  }

  function updateTacticalMapSwitching() {
    let objMap = this.scene.findObject("tactical_map_switching")
    if (!objMap?.isValid())
      return

    objMap.setValue(stashBhvValueConfig([
      {
        watch = getShowUAVCameraToggle()
        updateFunc = @(obj, value) obj.show(value)
      },
      {
        watch = getUAVCameraEnabled()
        updateFunc = updateTacticalMapSwitchingObj
      }
    ]))
  }

  function onSwitchToTacticalMap(_) {
    if (!getUAVCameraEnabled().get())
      return
    switchTacticalMapView()
  }

  function onSwitchToUAVCamera(_) {
    if (getUAVCameraEnabled().get())
      return
    switchTacticalMapView()
  }
}

return {
  HudTank
}