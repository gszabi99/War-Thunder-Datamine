from "replays" import is_replay_playing
from "hudActionBar" import getActionBarUnitName
from "%scripts/respawn/tacticalMapHudTypeState.nut" import getCachedMapHudType, setCachedMapHudType
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%globalScripts/hudNativeConsts.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let { g_hud_vis_mode } = require("%scripts/hud/hudVisMode.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseUnitHud } = require("%scripts/hud/baseUnitHud.nut")
let { mkActionBarAir } = require("%scripts/hud/hudActionBar.nut")
let { hudDisplayTimersInit, hudDisplayTimersReInit } = require("%scripts/hud/hudDisplayTimers.nut")

let HudInfantryDrone = class(BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudInfantryDrone.blk"

  function initScreen() {
    base.initScreen()
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_AIRCRAFT)
    let actionBar = mkActionBarAir(this.scene.findObject("hud_action_bar"))
    this.actionBarWeak = actionBar.weakref()

    this.updateTacticalMapVisibility()
    this.updatePosHudMultiplayerScore()
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

return {
  HudInfantryDrone
}
