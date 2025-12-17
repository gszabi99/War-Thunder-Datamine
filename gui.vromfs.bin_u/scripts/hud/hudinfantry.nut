from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { initIconedHints } = require("%scripts/hud/iconedHints.nut")
let { ActionBar } = require("%scripts/hud/hudActionBar.nut")
let { hudDisplayTimersInit, hudDisplayTimersReInit } = require("%scripts/hud/hudDisplayTimers.nut")
let { hudSquadBlockCollapsed } = require("%appGlobals/hudSquadMembers.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { gui_modal_help } = require("%scripts/help/helpWnd.nut")
let { register_command } = require("console")

const LOCAL_SQUAD_COLLAPSED_STATE_ID = "savedCollapsedHudSquad"
hudSquadBlockCollapsed.subscribe(@(v) saveLocalAccountSettings(LOCAL_SQUAD_COLLAPSED_STATE_ID, v))

const SEEN_HELP_ID = "seenInfantryHelpOnFirstGame"

let HudInfantry = class (gui_handlers.BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudInfantry.blk"

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
    this.updatePosHudMultiplayerScore()

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
    showObjById("actionbar_hints_nest", true, this.scene)
    showObjById("infantry_crosshair_hints_nest", true, this.scene)
  }
}

register_command(@() saveLocalAccountSettings(SEEN_HELP_ID, false), "debug.resetSeenInfantryHelp")

return {
  HudInfantry
}