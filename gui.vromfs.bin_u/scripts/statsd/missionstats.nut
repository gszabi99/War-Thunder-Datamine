from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let statsd = require("statsd")
let { get_time_msec } = require("dagor.time")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

::MissionStats <- {
  [PERSISTENT_DATA_PARAMS] = ["sendDelaySec", "_spawnTime"]

  sendDelaySec = 30

  _spawnTime = -1
}

::MissionStats.init <- function init()
{
  ::subscribe_handler(this)
  this.reset()
}

::MissionStats.reset <- function reset()
{
  this._spawnTime = -1
}

::MissionStats.onEventRoomJoined <- function onEventRoomJoined(_p)
{
  this.reset()
}

::MissionStats.onEventPlayerSpawn <- function onEventPlayerSpawn(_p)
{
  this._spawnTime = get_time_msec()
}

::MissionStats.onEventPlayerQuitMission <- function onEventPlayerQuitMission(_p)
{
  if (this._spawnTime >= 0 && (get_time_msec() - this._spawnTime > 1000 * this.sendDelaySec))
    return
  if (::get_game_mode() != GM_DOMINATION)
    return
  if (!::is_multiplayer())
    return

  statsd.send_counter("sq.early_session_leave", 1, {mission = ::get_current_mission_name()})
}

//!!must be atthe end of the file
::MissionStats.init()
::g_script_reloader.registerPersistentDataFromRoot("MissionStats")