from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/slotbar/playerCurUnit.nut" import getPlayerCurUnit
from "%scripts/hud/hudActionBar.nut" import mkActionBarAir
from "%scripts/hud/hudWithWeaponSelector.nut" import HudWithWeaponSelector
from "%scripts/hud/hudDisplayTimers.nut" import hudDisplayTimersInit, hudDisplayTimersReInit
from "hudActionBar" import getOwnerUnitName
from "replays" import is_replay_playing
from "mission" import get_game_type
from "%globalScripts/gameTypeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let { g_hud_vis_mode } = require("%scripts/hud/hudVisMode.nut")

let HudAir = class (HudWithWeaponSelector) {
  sceneBlkName = "%gui/hud/hudAir.blk"
  killFeedPlace = { height = "0.2@shHud", gap = "0.02@shHud", aboveId = "hud_tactical_map_bg" }
  hasMpScore = true
  function initScreen() {
    base.initScreen()
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_AIRCRAFT)
    let actionBar = mkActionBarAir(this.scene.findObject("hud_action_bar"))
    this.actionBarWeak = actionBar.weakref()

    this.updateTacticalMapVisibility()
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

return freeze({
  HudAir
})
