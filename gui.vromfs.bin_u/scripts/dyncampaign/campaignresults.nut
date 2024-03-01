//-file:plus-string
from "%scripts/dagui_natives.nut" import get_session_warpoints
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { dynamicGetVisual } = require("dynamicMission")
let DataBlock = require("DataBlock")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { getDynamicResult } = require("%scripts/debriefing/debriefingFull.nut")

gui_handlers.CampaignResults <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/debriefingCamp.blk"

  loses = ["fighters", "bombers", "tanks", "infantry", "ships", "artillery"]

  function initScreen() {
    this.guiScene["campaign-status"].setValue(
        (getDynamicResult() == MISSION_STATUS_SUCCESS) ? loc("DYNAMIC_CAMPAIGN_SUCCESS") : loc("DYNAMIC_CAMPAIGN_FAIL")
      )
    this.guiScene["campaign-result"].setValue(
        (getDynamicResult() == MISSION_STATUS_SUCCESS) ? loc("missions/dynamic_success") : loc("missions/dynamic_fail")
      );

    let wpdata = get_session_warpoints()

    this.guiScene["info-dc-wins"].setValue(wpdata.dcWins.tostring())
    this.guiScene["info-dc-fails"].setValue(wpdata.dcFails.tostring())

    if (wpdata.nDCWp > 0) {
      this.guiScene["info-dc-text"].setValue(loc("debriefing/dc"))
      this.guiScene["info-dc-wp"].setValue(Cost(wpdata.nDCWp).toStringWithParams(
        { isWpAlwaysShown = true, isColored = false }))
    }

    let info = DataBlock()
    dynamicGetVisual(info)
    let stats = ["bombers", "fighters", "infantry", "tanks", "artillery", "ships"]
    let sides = ["ally", "enemy"]
    for (local i = 0; i < stats.len(); i++) {
      for (local j = 0; j < sides.len(); j++) {
        local value = info.getInt("loss_" + sides[j] + "_" + stats[i], 0)
        if (value > 10000)
          value = "" + ((value / 1000).tointeger()).tostring() + "K"
        this.guiScene["info-" + stats[i] + j.tostring()].text = value
      }
    }

  }
  function onSelect() {
    log("gui_handlers.CampaignResults onSelect")
    this.save()
  }
  function afterSave() {
    log("gui_handlers.CampaignResults afterSave")
    this.goForward(gui_start_mainmenu)
  }
  function onBack() {
    log("gui_handlers.CampaignResults goBack")
    this.goBack()
  }
}

return {
  guiStartDynamicResults = @() handlersManager.loadHandler(gui_handlers.CampaignResults)
}
