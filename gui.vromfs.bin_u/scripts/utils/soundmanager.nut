from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

enum PLAYBACK_STATUS
{
  INVALID,
  DOWNLOADING,
  VALID
}

::g_sound <- {
  [PERSISTENT_DATA_PARAMS] = ["playbackStatus", "curPlaying"]

  playbackStatus = {}
  curPlaying = ""
}

::g_sound.onCachedMusicDowloaded <- function onCachedMusicDowloaded(playbackId, success)
{
  playbackStatus[playbackId] <- success? PLAYBACK_STATUS.VALID : PLAYBACK_STATUS.INVALID
  ::broadcastEvent("PlaybackDownloaded", {id = playbackId, success = success})
}

::g_sound.onCachedMusicPlayEnd <- function onCachedMusicPlayEnd(playbackId)
{
  curPlaying = ""
  ::broadcastEvent("FinishedPlayback", {id = playbackId})
}

::g_sound.preparePlayback <- function preparePlayback(url, playbackId)
{
  if (::u.isEmpty(url)
      || getPlaybackStatus(playbackId) != PLAYBACK_STATUS.INVALID)
    return

  playbackStatus[playbackId] <- PLAYBACK_STATUS.DOWNLOADING
  ::set_cached_music(CACHED_MUSIC_MISSION, url, playbackId)
}

::g_sound.play <- function play(playbackId = "")
{
  if (playbackId == "" && curPlaying == "")
    return

  if (getPlaybackStatus(playbackId) != PLAYBACK_STATUS.VALID)
    return

  if (::play_cached_music(playbackId))
    curPlaying = playbackId
}

::g_sound.stop <- function stop()
{
  ::play_cached_music("")
  curPlaying = ""
}

::g_sound.getPlaybackStatus <- function getPlaybackStatus(playbackId)
{
  return getTblValue(playbackId, playbackStatus, PLAYBACK_STATUS.INVALID)
}

::g_sound.canPlay <- function canPlay(playbackId)
{
  return getPlaybackStatus(playbackId) == PLAYBACK_STATUS.VALID
}

::g_sound.isPlaying <- function isPlaying(playbackId)
{
  return playbackId == curPlaying && curPlaying != ""
}

::g_sound.onEventGameLocalizationChanged <- function onEventGameLocalizationChanged(p)
{
  stop()
  playbackStatus.clear()
}

::g_script_reloader.registerPersistentDataFromRoot("g_sound")
::subscribe_handler(::g_sound, ::g_listener_priority.DEFAULT_HANDLER)

//C++ call
::on_cached_music_play_end <- ::g_sound.onCachedMusicPlayEnd.bindenv(::g_sound)
//C++ call
::on_cached_music_downloaded <- ::g_sound.onCachedMusicDowloaded.bindenv(::g_sound)