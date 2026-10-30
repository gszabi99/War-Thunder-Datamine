from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "statsd" import send_counter
from "dagor.time" import get_time_msec
from "mission" import get_current_mission_name, get_game_mode
from "%scripts/dagui_library.nut" import *
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

const SEND_DELAY_SEC = 30

let spawnTime = mkHardPersistWatched("statsd.missionStats")("spawnTime", -1)

function onEventPlayerQuitMission(_) {
  if (spawnTime.get() >= 0 && (get_time_msec() - spawnTime.get() > 1000 * SEND_DELAY_SEC))
    return
  if (get_game_mode() != GM_DOMINATION)
    return
  if (!is_multiplayer())
    return

  send_counter("sq.early_session_leave", 1, { mission = get_current_mission_name() })
}

addListenersWithoutEnv({
  RoomJoined         = @(_) spawnTime.set(-1)
  PlayerSpawn        = @(_) spawnTime.set(get_time_msec())
  PlayerQuitMission  = onEventPlayerQuitMission
})
