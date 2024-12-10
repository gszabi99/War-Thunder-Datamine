from "%scripts/dagui_natives.nut" import is_player_can_bailout, is_camera_not_flight
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

let { is_benchmark_game_mode, is_restart_option_hidden, get_game_mode, get_game_type } = require("mission")
let { get_mission_restore_type, get_mission_status } = require("guiMission")

function canRestart() {
  return !is_multiplayer()
    && ![ GM_DYNAMIC, GM_BENCHMARK ].contains(get_game_mode())
    && !is_benchmark_game_mode()
    && (get_game_type() & GT_COOPERATIVE) == 0
    && get_mission_status() != MISSION_STATUS_SUCCESS
    && !is_restart_option_hidden()
}

function canBailout() {
  let gm = get_game_mode()
  return (get_mission_restore_type() != ERT_MANUAL || gm == GM_TEST_FLIGHT)
    && !is_benchmark_game_mode()
    && !is_camera_not_flight()
    && is_player_can_bailout()
    && get_mission_status() == MISSION_STATUS_RUNNING
}

return {
  canRestart = canRestart
  canBailout = canBailout
}
