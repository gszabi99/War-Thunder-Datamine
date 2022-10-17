from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

::gui_start_dynamic_results <- function gui_start_dynamic_results()
{
  ::handlersManager.loadHandler(::gui_handlers.CampaignResults)
}

let { getDynamicResult } = require("%scripts/debriefing/debriefingFull.nut")

::gui_handlers.CampaignResults <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/debriefingCamp.blk"

  loses = ["fighters", "bombers", "tanks", "infantry", "ships", "artillery"]

  function initScreen()
  {
    guiScene["campaign-status"].setValue(
        (getDynamicResult() == MISSION_STATUS_SUCCESS) ? loc("DYNAMIC_CAMPAIGN_SUCCESS") : loc("DYNAMIC_CAMPAIGN_FAIL")
      )
    guiScene["campaign-result"].setValue(
        (getDynamicResult() == MISSION_STATUS_SUCCESS) ? loc("missions/dynamic_success") : loc("missions/dynamic_fail")
      );

    let wpdata = ::get_session_warpoints()

    guiScene["info-dc-wins"].setValue(wpdata.dcWins.tostring())
    guiScene["info-dc-fails"].setValue(wpdata.dcFails.tostring())

    if (wpdata.nDCWp>0)
    {
      guiScene["info-dc-text"].setValue(loc("debriefing/dc"))
      guiScene["info-dc-wp"].setValue(::Cost(wpdata.nDCWp).toStringWithParams(
        {isWpAlwaysShown = true, isColored = false}))
    }

    let info = ::DataBlock()
    ::dynamic_get_visual(info)
    let stats = ["bombers", "fighters", "infantry", "tanks", "artillery","ships"]
    let sides = ["ally","enemy"]
    for (local i = 0; i < stats.len(); i++)
    {
      for (local j = 0; j < sides.len(); j++)
      {
        local value = info.getInt("loss_"+sides[j]+"_"+stats[i], 0)
        if (value > 10000)
          value = "" + ((value/1000).tointeger()).tostring() + "K"
        guiScene["info-"+stats[i]+j.tostring()].text = value
      }
    }

  }
  function onSelect()
  {
    log("::gui_handlers.CampaignResults onSelect")
    save()
  }
  function afterSave()
  {
    log("::gui_handlers.CampaignResults afterSave")
    goForward(::gui_start_mainmenu)
  }
  function onBack()
  {
    log("::gui_handlers.CampaignResults goBack")
    goBack()
  }
}