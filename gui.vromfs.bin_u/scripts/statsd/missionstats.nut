from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

let { send_counter } = require("statsd")
let { get_time_msec } = require("dagor.time")
let { get_current_mission_name, get_game_mode } = require("mission")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

const SEND_DELAY_SEC = 30

let missionStatsState = persist("missionStatsState", @() { spawnTime = -1 })

function reset() {
  missionStatsState.spawnTime = -1
}

function onEventPlayerQuitMission(_) {
  if (missionStatsState.spawnTime >= 0 && (get_time_msec() - missionStatsState.spawnTime > 1000 * SEND_DELAY_SEC))
    return
  if (get_game_mode() != GM_DOMINATION)
    return
  if (!is_multiplayer())
    return

  send_counter("sq.early_session_leave", 1, { mission = get_current_mission_name() })
}

addListenersWithoutEnv({
  RoomJoined         = @(_) reset()
  PlayerSpawn        = @(_) missionStatsState.spawnTime = get_time_msec()
  PlayerQuitMission  = onEventPlayerQuitMission
})

reset()
