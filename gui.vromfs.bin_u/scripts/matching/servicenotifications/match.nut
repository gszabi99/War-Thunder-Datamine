from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this


let crossplayModule = require("%scripts/social/crossplay.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { register_command } = require("console")

local debug_mm = null

register_command(function(enable) {debug_mm = enable}, "matchmacking.set_debug_mm")

::notify_clusters_changed <- function notify_clusters_changed(params)
{
  log("notify_clusters_changed")
  ::g_clusters.onClustersChanged(params)
}

let changedGameModes = {
  paramsArray = []
}
::g_script_reloader.registerPersistentData("changedGameModes", changedGameModes, [ "paramsArray" ])

let clearChangedGameModesParams = @() changedGameModes.paramsArray.clear()

::notify_game_modes_changed <- function notify_game_modes_changed(params)
{
  if (!::is_online_available())
  {
    clearChangedGameModesParams()
    return
  }

  if (::is_in_flight()) // do not handle while session is active
  {
    log("is_in_flight need notify_game_modes_changed after battle")
    changedGameModes.paramsArray.append(params)
    return
  }

  log("notify_game_modes_changed")
  ::g_matching_game_modes.onGameModesChangedNotify(getTblValue("added", params, null),
                                                 getTblValue("removed", params, null),
                                                 getTblValue("changed", params, null))
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) clearChangedGameModesParams()
  BattleEnded = function(_p) {
    if (::is_in_flight() || changedGameModes.paramsArray.len() == 0)
      return

    foreach (params in changedGameModes.paramsArray)
      ::notify_game_modes_changed(params)
    clearChangedGameModesParams()
  }
})

::notify_game_modes_changed_rnd_delay <- function notify_game_modes_changed_rnd_delay(params)
{
  let maxFetchDelaySec = 60
  let rndDelaySec = ::math.rnd() % maxFetchDelaySec
  log("notify_game_modes_changed_rnd_delay " + rndDelaySec)
  ::g_delayed_actions.add((@(params) function() { ::notify_game_modes_changed(params) })(params),
                        rndDelaySec * 1000)
}

::on_queue_info_updated <- function on_queue_info_updated(params)
{
  ::broadcastEvent("QueueInfoRecived", {queue_info = params})
}

::notify_queue_join <- function notify_queue_join(params)
{
  let queue = ::queues.createQueue(params)
  ::queues.afterJoinQueue(queue)
}

::notify_queue_leave <- function notify_queue_leave(params)
{
  ::queues.afterLeaveQueues(params)
}

::fetch_clusters_list <- function fetch_clusters_list(params, cb)
{
  ::matching_api_func("wtmm_static.fetch_clusters_list", cb, params)
}

::fetch_game_modes_info <- function fetch_game_modes_info(params, cb)
{
  ::matching_api_func("match.fetch_game_modes_info", cb, params)
}

::fetch_game_modes_digest <- function fetch_game_modes_digest(params, cb)
{
  ::matching_api_func("wtmm_static.fetch_game_modes_digest", cb, params)
}

::leave_session_queue <- function leave_session_queue(params, cb)
{
  ::matching_api_func("match.leave_queue", cb, params)
}

::enqueue_in_session <- function enqueue_in_session(params, cb)
{
  let missionName = ::get_forced_network_mission()
  if (missionName.len() > 0)
    params["forced_network_mission"] <- missionName

  if (!crossplayModule.isCrossPlayEnabled())
    params["crossplay_restricted"] <- true
  if (debug_mm != null)
    params["debug_mm"] <- debug_mm

  ::matching_api_func("match.enqueue", cb, params)
}

foreach (notificationName, callback in
          {
            ["match.notify_clusters_changed"] = ::notify_clusters_changed,

            ["match.notify_game_modes_changed"] = ::notify_game_modes_changed_rnd_delay,

            ["match.update_queue_info"] = ::on_queue_info_updated,

            ["match.notify_queue_join"] = ::notify_queue_join,

            ["match.notify_queue_leave"] = ::notify_queue_leave
          }
        )
  ::matching_rpc_subscribe(notificationName, callback)
