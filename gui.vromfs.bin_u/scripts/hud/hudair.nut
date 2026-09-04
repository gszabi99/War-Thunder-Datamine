from "hudActionBar" import getOwnerUnitName
from "replays" import is_replay_playing
from "mission" import get_game_type
from "%globalScripts/gameTypeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let { g_hud_vis_mode } = require("%scripts/hud/hudVisMode.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { mkActionBarAir } = require("%scripts/hud/hudActionBar.nut")
let { HudWithWeaponSelector } = require("%scripts/hud/hudWithWeaponSelector.nut")
let { hudDisplayTimersInit, hudDisplayTimersReInit } = require("%scripts/hud/hudDisplayTimers.nut")

let HudAir = class (HudWithWeaponSelector) {
  sceneBlkName = "%gui/hud/hudAir.blk"
  function initScreen() {
    base.initScreen()
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_AIRCRAFT)
    let actionBar = mkActionBarAir(this.scene.findObject("hud_action_bar"))
    this.actionBarWeak = actionBar.weakref()

    this.updateTacticalMapVisibility()
    this.updatePosHudMultiplayerScore()
    this.createAirWeaponSelector(getPlayerCurUnit())
  }

  function reinitScreen(_params = null) {
    base.reinitScreen()
    hudDisplayTimersReInit()
    this.updateTacticalMapVisibility()
    this.actionBarWeak?.reinit()
  }

  function updateTacticalMapVisibility() {
    let ownerUnit = getAircraftByName(getOwnerUnitName())
    let shouldShowMapForAircraft = (get_game_type() & GT_RACE) != 0 
      || (getPlayerCurUnit()?.tags ?? []).contains("type_strike_ucav") 
      || ( 
        hasFeature("uavMiniMap") && ((ownerUnit?.isTank() ?? false)
        || (ownerUnit?.isShip() ?? false))
      )
    let isVisible = shouldShowMapForAircraft && !is_replay_playing()
      && g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
    showObjById("hud_tactical_map_bg", isVisible, this.scene)
  }
}
register_gui_handler("HudAir", HudAir)

return {
  HudAir
}
