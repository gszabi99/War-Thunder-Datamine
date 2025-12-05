from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { ActionBar } = require("%scripts/hud/hudActionBar.nut")
let { hudDisplayTimersInit, hudDisplayTimersReInit } = require("%scripts/hud/hudDisplayTimers.nut")
let hudEnemyDamage = require("%scripts/hud/hudEnemyDamage.nut")
let { hud_request_hud_ship_debuffs_state, shouldShowSubmarineMinimap } = require("hudState")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { isInKillerCamera } = require("%scripts/hud/hudState.nut")
let { g_hud_vis_mode } =  require("%scripts/hud/hudVisMode.nut")

let HudShip = class (gui_handlers.BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudShip.blk"
  widgetsList = [
    {
      widgetId = DargWidgets.SHIP_OBSTACLE_RF
      placeholderId = "ship_obstacle_rf"
    }
  ]

  isTacticalMapVisibleBySubmarineDepth = true

  function initScreen() {
    base.initScreen()
    this.isTacticalMapVisibleBySubmarineDepth = shouldShowSubmarineMinimap()
    hudEnemyDamage.init(this.scene)
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_SHIP)
    hud_request_hud_ship_debuffs_state()
    let actionBar = ActionBar(this.scene.findObject("hud_action_bar"))
    this.actionBarWeak = actionBar.weakref()
    this.updatePosHudMultiplayerScore()
    g_hud_event_manager.subscribe("tacticalMapVisibility:bySubmarineDepth",
      @(eventData) this.updateTacticalMapVisibilityByDepth(eventData.shouldShow), this)
  }

  function reinitScreen(_params = {}) {
    this.actionBarWeak?.reinit()
    this.isTacticalMapVisibleBySubmarineDepth = shouldShowSubmarineMinimap()
    hudEnemyDamage.reinit()
    hudDisplayTimersReInit()
    hud_request_hud_ship_debuffs_state()
  }

  function updateTacticalMapVisibilityByDepth(shouldShow) {
    this.isTacticalMapVisibleBySubmarineDepth = shouldShow
    this.updateTacticalMapVisibility()
  }

  function updateTacticalMapVisibility() {
    let isTacticalMapVisible = this.isTacticalMapVisibleBySubmarineDepth
      && !isInKillerCamera.get()
      && g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)

    showObjById("hud_tactical_map_bg", isTacticalMapVisible, this.scene)
  }
}

return {
  HudShip
}