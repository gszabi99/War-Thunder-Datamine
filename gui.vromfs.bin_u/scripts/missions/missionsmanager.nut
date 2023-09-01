//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { web_rpc } = require("%scripts/webRPC.nut")

::g_missions_manager <- {
  isRemoteMission = false
}

::g_missions_manager.fastStartSkirmishMission <- function fastStartSkirmishMission(mission) {
  let params = {
    canSwitchMisListType = false
    showAllCampaigns = false
    mission = mission
    wndGameMode = GM_SKIRMISH
  }

  ::prepare_start_skirmish()
  this.isRemoteMission = true
  handlersManager.loadHandler(gui_handlers.RemoteMissionModalHandler, params)
}

::g_missions_manager.startRemoteMission <- function startRemoteMission(params) {
  let url = params.url
  let name = params.name || "remote_mission"

  if (!::isInMenu() || handlersManager.isAnyModalHandlerActive())
    return

  let urlMission = ::UrlMission(name, url)
  let mission = {
    id = urlMission.name
    isHeader = false
    isCampaign = false
    isUnlocked = true
    campaign = ""
    chapter = ""
  }
  mission.urlMission <- urlMission

  let callback = function(success, mis) {
                     if (!success)
                       return

                     mis.blk <- urlMission.getMetaInfo()
                     ::g_missions_manager.fastStartSkirmishMission(mis)
                   }

  ::scene_msg_box("start_mission_from_live_confirmation",
                  null,
                  loc("urlMissions/live/loadAndStartConfirmation", params),
                  [["yes", function() { ::g_url_missions.loadBlk(mission, callback) }],
                   ["no", function() {} ]],
                  "yes", { cancel_fn = function() {} }
                )
}

::on_start_remote_mission <- function on_start_remote_mission(params) {
  ::g_missions_manager.startRemoteMission(params)
}

web_rpc.register_handler("start_remote_mission", ::on_start_remote_mission)