from "%scripts/hud/baseUnitHud.nut" import BaseUnitHud
from "%scripts/hud/iconedHints.nut" import initIconedHints
from "%scripts/hud/hudActionBar.nut" import ActionBar
from "%scripts/hud/hudDisplayTimers.nut" import hudDisplayTimersInit, hudDisplayTimersReInit
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/help/helpWnd.nut" import gui_modal_help
from "%appGlobals/hudSquadMembers.nut" import hudSquadBlockCollapsed
from "console" import register_command
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/controls/controlsConsts.nut" import HELP_CONTENT_SET
from "%scripts/hud/dargHudLayers.nut" import infantryKillFeedPlace

const LOCAL_SQUAD_COLLAPSED_STATE_ID = "savedCollapsedHudSquad"
hudSquadBlockCollapsed.subscribe(@(v) saveLocalAccountSettings(LOCAL_SQUAD_COLLAPSED_STATE_ID, v))

const SEEN_HELP_ID = "seenInfantryHelpOnFirstGame"

let HudInfantry = class (BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudInfantry.blk"
  killFeedPlace = infantryKillFeedPlace
  hasMpScore = true

  function initScreen() {
    base.initScreen()
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_HUMAN)
    initIconedHints(this.scene, ES_UNIT_TYPE_HUMAN)
    let actionBar = ActionBar(
      this.scene.findObject("hud_action_bar_infantry"),
      "%gui/hud/actionBarItemInfantry.blk",
      "actionBarItemInfantryDiv",
      "%gui/hud/actionBarSecondItemsInfantry.tpl"
    )
    this.actionBarWeak = actionBar.weakref()
    this.updateShowHintsNest()

    let isCollapsed = loadLocalAccountSettings(LOCAL_SQUAD_COLLAPSED_STATE_ID, false)
    hudSquadBlockCollapsed.set(isCollapsed)

    if (!loadLocalAccountSettings(SEEN_HELP_ID, false)) {
      saveLocalAccountSettings(SEEN_HELP_ID, true)
      gui_modal_help(false, HELP_CONTENT_SET.CONTROLS)
    }
  }

  function reinitScreen(_params = {}) {
    this.actionBarWeak?.reinit()
    hudDisplayTimersReInit()
    this.updateShowHintsNest()
  }

  function updateShowHintsNest() {
    showObjById("infantry_crosshair_hints_nest", true, this.scene)
  }
}

register_command(@() saveLocalAccountSettings(SEEN_HELP_ID, false), "debug.resetSeenInfantryHelp")

return freeze({
  HudInfantry
})
