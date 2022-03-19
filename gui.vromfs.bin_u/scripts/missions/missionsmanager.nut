::g_missions_manager <- {
  isRemoteMission = false
}

g_missions_manager.fastStartSkirmishMission <- function fastStartSkirmishMission(mission)
{
  local params = {
    canSwitchMisListType = false
    showAllCampaigns = false
    mission = mission
    wndGameMode = ::GM_SKIRMISH
  }

  ::prepare_start_skirmish()
  isRemoteMission = true
  ::handlersManager.loadHandler(::gui_handlers.RemoteMissionModalHandler, params)
}

g_missions_manager.startRemoteMission <- function startRemoteMission(params)
{
  local url = params.url
  local name = params.name || "remote_mission"

  if (!::isInMenu() || ::handlersManager.isAnyModalHandlerActive())
    return

  local urlMission = UrlMission(name, url)
  local mission = {
    id = urlMission.name
    isHeader = false
    isCampaign = false
    isUnlocked = true
    campaign = ""
    chapter = ""
  }
  mission.urlMission <- urlMission

  local callback = function(success, mis) {
                     if (!success)
                       return

                     mis.blk <- urlMission.getMetaInfo()
                     ::g_missions_manager.fastStartSkirmishMission(mis)
                   }

  ::scene_msg_box("start_mission_from_live_confirmation",
                  null,
                  ::loc("urlMissions/live/loadAndStartConfirmation", params),
                  [["yes", function() { ::g_url_missions.loadBlk(mission, callback) }],
                   ["no", function() {} ]],
                  "yes", { cancel_fn = function() {}}
                )
}

::on_start_remote_mission <- function on_start_remote_mission(params)
{
  ::g_missions_manager.startRemoteMission(params)
}

web_rpc.register_handler("start_remote_mission", on_start_remote_mission)