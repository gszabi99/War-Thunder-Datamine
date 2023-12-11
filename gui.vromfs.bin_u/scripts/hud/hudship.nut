from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { ActionBar } = require("%scripts/hud/hudActionBar.nut")

let HudShip = class (gui_handlers.BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudShip.blk"
  widgetsList = [
    {
      widgetId = DargWidgets.SHIP_OBSTACLE_RF
      placeholderId = "ship_obstacle_rf"
    }
  ]

  function initScreen() {
    base.initScreen()
    ::hudEnemyDamage.init(this.scene)
    ::g_hud_display_timers.init(this.scene, ES_UNIT_TYPE_SHIP)
    ::hud_request_hud_ship_debuffs_state()
    this.actionBar = ActionBar(this.scene.findObject("hud_action_bar"))
    this.updatePosHudMultiplayerScore()
  }

  function reinitScreen(_params = {}) {
    this.actionBar.reinit()
    ::hudEnemyDamage.reinit()
    ::g_hud_display_timers.reinit()
    ::hud_request_hud_ship_debuffs_state()
  }
}

return {
  HudShip
}