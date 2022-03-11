let statsd = require("statsd")

::MissionStats <- {
  [PERSISTENT_DATA_PARAMS] = ["sendDelaySec", "_spawnTime"]

  sendDelaySec = 30

  _spawnTime = -1
}

MissionStats.init <- function init()
{
  ::subscribe_handler(this)
  reset()
}

MissionStats.reset <- function reset()
{
  _spawnTime = -1
}

MissionStats.onEventRoomJoined <- function onEventRoomJoined(p)
{
  reset()
}

MissionStats.onEventPlayerSpawn <- function onEventPlayerSpawn(p)
{
  _spawnTime = ::dagor.getCurTime()
}

MissionStats.onEventPlayerQuitMission <- function onEventPlayerQuitMission(p)
{
  if (_spawnTime >= 0 && (::dagor.getCurTime() - _spawnTime > 1000 * sendDelaySec))
    return
  if (::get_game_mode() != ::GM_DOMINATION)
    return
  if (!::is_multiplayer())
    return

  statsd.send_counter("sq.early_session_leave", 1, {mission = get_current_mission_name()})
}

//!!must be atthe end of the file
::MissionStats.init()
::g_script_reloader.registerPersistentDataFromRoot("MissionStats")