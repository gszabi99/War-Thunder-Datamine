import "DataBlock" as DataBlock
from "dynamicMission" import dynamicGetVisual
from "%scripts/dagui_natives.nut" import get_session_warpoints
from "%scripts/dagui_library.nut" import *
from "guiMission" import MISSION_STATUS_SUCCESS

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { Cost } = require("%scripts/money.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { getDynamicResult } = require("%scripts/debriefing/debriefingFull.nut")

let CampaignResults = class (BaseGuiHandlerWT) {
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
        local value = info?["".concat("loss_", sides[j], "_", stats[i])] ?? 0
        if (value > 10000)
          value = "".concat(((value / 1000).tointeger()).tostring(), "K")
        this.guiScene["".concat("info-", stats[i], j)].text = value
      }
    }

  }
  function onSelect() {
    log("CampaignResults onSelect")
    this.save()
  }
  function afterSave() {
    log("CampaignResults afterSave")
    this.goForward(gui_start_mainmenu)
  }
  function onBack() {
    log("CampaignResults goBack")
    this.goBack()
  }
}
register_gui_handler("CampaignResults", CampaignResults)

return {
  guiStartDynamicResults = @() handlersManager.loadHandler(CampaignResults)
}
