from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let function canRestart()
{
  return !::is_multiplayer()
    && ![ GM_DYNAMIC, GM_BENCHMARK ].contains(::get_game_mode())
    && (::get_game_type() & GT_COOPERATIVE) == 0
    && ::get_mission_status() != MISSION_STATUS_SUCCESS
}

let function canBailout()
{
  let gm = ::get_game_mode()
  return (::get_mission_restore_type() != ERT_MANUAL || gm == GM_TEST_FLIGHT)
    && gm != GM_BENCHMARK
    && !::is_camera_not_flight()
    && ::is_player_can_bailout()
    && ::get_mission_status() == MISSION_STATUS_RUNNING
}

return {
  canRestart = canRestart
  canBailout = canBailout
}
