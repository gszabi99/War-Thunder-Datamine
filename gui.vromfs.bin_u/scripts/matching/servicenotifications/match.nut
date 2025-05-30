from "%scripts/dagui_natives.nut" import is_online_available, get_forced_network_mission
from "%scripts/dagui_library.nut" import *

let { rnd } = require("dagor.random")
let crossplayModule = require("%scripts/social/crossplay.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { broadcastEvent } = subscriptions
let { register_command } = require("console")
let { matchingApiFunc, matchingRpcSubscribe } = require("%scripts/matching/api.nut")
let { isInFlight } = require("gameplayBinding")
let { addDelayedAction } = require("%scripts/utils/delayedActions.nut")

let changedGameModes = persist("changedGameModes", @() [])

let clearChangedGameModesParams = @() changedGameModes.clear()

function notifyGameModesChanged(params) {
  if (!is_online_available()) {
    clearChangedGameModesParams()
    return
  }

  if (isInFlight()) { 
    log("is_in_flight need notify_game_modes_changed after battle")
    changedGameModes.append(params)
    return
  }

  log("notify_game_modes_changed")
  broadcastEvent("NotifyGameModesChanged", params)
}

function onClustersChanged(params) {
  log("notify_clusters_changed")
  broadcastEvent("ClustersChanged", params)
}

function onGameModesChangedRndDelay(params) {
  let maxFetchDelaySec = 60
  let rndDelaySec = rnd() % maxFetchDelaySec
  log($"notify_game_modes_changed_rnd_delay {rndDelaySec}")
  addDelayedAction(@() notifyGameModesChanged(params), rndDelaySec * 1000)
}

function onQueueInfoUpdated(params) {
  broadcastEvent("QueueInfoRecived", { queue_info = params })
}

function fetchClustersList(params, cb) {
  matchingApiFunc("wtmm_static.fetch_clusters_list", cb, params)
}

function fetchGameModesInfo(params, cb) {
  matchingApiFunc("match.fetch_game_modes_info", cb, params)
}

function fetchGameModesDigest(params, cb) {
  matchingApiFunc("wtmm_static.fetch_game_modes_digest", cb, params)
}

let debug_mm = persist("debug_mm", @() {
  enable = null
})

register_command(@(enable) debug_mm.enable = enable, "matchmacking.set_debug_mm")

function enqueueInSession(params, cb) {
  let missionName = get_forced_network_mission()
  if (missionName.len() > 0)
    params["forced_network_mission"] <- missionName

  if (!crossplayModule.isCrossPlayEnabled())
    params["crossplay_restricted"] <- true
  if (debug_mm.enable != null)
    params["debug_mm"] <- debug_mm.enable

  matchingApiFunc("match.enqueue", cb, params)
}

matchingRpcSubscribe("match.notify_clusters_changed", onClustersChanged)
matchingRpcSubscribe("match.notify_game_modes_changed", onGameModesChangedRndDelay)
matchingRpcSubscribe("match.update_queue_info", onQueueInfoUpdated)

subscriptions.addListenersWithoutEnv({
  SignOut = @(_) clearChangedGameModesParams()
  BattleEnded = function(_) {
    if (isInFlight() || changedGameModes.len() == 0)
      return

    foreach (params in changedGameModes)
      notifyGameModesChanged(params)

    clearChangedGameModesParams()
  }
})

return {
  enqueueInSession
  fetchGameModesDigest
  fetchGameModesInfo
  fetchClustersList
}
