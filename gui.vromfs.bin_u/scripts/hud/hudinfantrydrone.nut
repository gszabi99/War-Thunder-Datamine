from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/hud/baseUnitHud.nut" import BaseUnitHud
from "%scripts/hud/hudActionBar.nut" import mkActionBarAir
from "%scripts/hud/hudDisplayTimers.nut" import hudDisplayTimersInit, hudDisplayTimersReInit
from "replays" import is_replay_playing
from "hudActionBar" import getActionBarUnitName
from "%scripts/respawn/tacticalMapHudTypeState.nut" import getCachedMapHudType, setCachedMapHudType
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%globalScripts/hudNativeConsts.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART
from "%scripts/hud/dargHudLayers.nut" import infantryKillFeedPlace

let { g_hud_vis_mode } = require("%scripts/hud/hudVisMode.nut")

let HudInfantryDrone = class(BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudInfantryDrone.blk"
  killFeedPlace = infantryKillFeedPlace
  hasMpScore = true

  function initScreen() {
    base.initScreen()
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_AIRCRAFT)
    let actionBar = mkActionBarAir(this.scene.findObject("hud_action_bar"))
    this.actionBarWeak = actionBar.weakref()

    this.updateTacticalMapVisibility()
  }

  function reinitScreen(_params = null) {
    hudDisplayTimersReInit()
    this.updateTacticalMapVisibility()
    this.actionBarWeak.reinit()
  }

  function updateTacticalMapVisibility() {
    let isVisible = !is_replay_playing() && g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
    showObjById("hud_small_tactical_map_bg", isVisible, this.scene)

    let unitName = getActionBarUnitName()
    if (unitName != "" && getCachedMapHudType(unitName) == null)
      setCachedMapHudType(unitName, HUD_TYPE_TANK)
  }
}
register_gui_handler("HudInfantryDrone", HudInfantryDrone)

return freeze({
  HudInfantryDrone
})
