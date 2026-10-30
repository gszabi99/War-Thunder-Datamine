from "%scripts/hud/baseUnitHud.nut" import BaseUnitHud
from "%scripts/hud/hudActionBar.nut" import ActionBar
from "%scripts/hud/hudDisplayTimers.nut" import hudDisplayTimersInit, hudDisplayTimersReInit
from "%scripts/hud/hudState.nut" import isInKillerCamera
from "%appGlobals/hud/hudState.nut" import isCarrierMenuActive
from "hudState" import hud_request_hud_ship_debuffs_state, shouldShowSubmarineMinimap
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let hudEnemyDamage = require("%scripts/hud/hudEnemyDamage.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { g_hud_vis_mode } = require("%scripts/hud/hudVisMode.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let HudShip = class (BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudShip.blk"
  killFeedPlace = { height = "0.2@shHud", gap = "0.02@shHud", aboveId = "hud_tactical_map_bg" }
  hasMpScore = true

  widgetsList = [
    {
      widgetId = DargWidgets.SHIP_OBSTACLE_RF
      placeholderId = "ship_obstacle_rf"
    }
  ]

  isTacticalMapVisibleBySubmarineDepth = true
  onCarrierMenuActiveChange = null

  function initScreen() {
    base.initScreen()
    this.isTacticalMapVisibleBySubmarineDepth = shouldShowSubmarineMinimap()
    hudEnemyDamage.init(this.scene)
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_SHIP)
    hud_request_hud_ship_debuffs_state()
    let actionBar = ActionBar(this.scene.findObject("hud_action_bar"))
    this.actionBarWeak = actionBar.weakref()
    g_hud_event_manager.subscribe("tacticalMapVisibility:bySubmarineDepth",
      @(eventData) this.updateTacticalMapVisibilityByDepth(eventData.shouldShow), this)
    this.onCarrierMenuActiveChange = (@(_) this?.updateTacticalMapVisibility()).bindenv(this)
    isCarrierMenuActive.subscribe(this.onCarrierMenuActiveChange)
  }

  function onDestroy() {
    isCarrierMenuActive.unsubscribe(this.onCarrierMenuActiveChange)
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
      && !isCarrierMenuActive.get()
      && g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)

    showObjById("hud_tactical_map_bg", isTacticalMapVisible, this.scene)
    this.guiScene.applyPendingChanges(false)
    handlersManager.updateWidgets()
  }
}

return freeze({
  HudShip
})
