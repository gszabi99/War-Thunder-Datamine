from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer
from "gameplayBinding" import isCameraNotFlight, isPlayerCanBailout

let { is_benchmark_game_mode, is_restart_option_hidden, get_game_mode, get_game_type } = require("mission")
let { ERT_MANUAL, MISSION_STATUS_RUNNING, MISSION_STATUS_SUCCESS, get_mission_restore_type,
  get_mission_status } = require("guiMission")

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
    && !isCameraNotFlight()
    && isPlayerCanBailout()
    && get_mission_status() == MISSION_STATUS_RUNNING
}

return {
  canRestart = canRestart
  canBailout = canBailout
}
