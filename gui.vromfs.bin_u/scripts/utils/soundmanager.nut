//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let { registerPersistentDataFromRoot, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

enum PLAYBACK_STATUS {
  INVALID,
  DOWNLOADING,
  VALID
}

::g_sound <- {
  [PERSISTENT_DATA_PARAMS] = ["playbackStatus", "curPlaying"]

  playbackStatus = {}
  curPlaying = ""
}

::g_sound.onCachedMusicDowloaded <- function onCachedMusicDowloaded(playbackId, success) {
  this.playbackStatus[playbackId] <- success ? PLAYBACK_STATUS.VALID : PLAYBACK_STATUS.INVALID
  broadcastEvent("PlaybackDownloaded", { id = playbackId, success = success })
}

::g_sound.onCachedMusicPlayEnd <- function onCachedMusicPlayEnd(playbackId) {
  this.curPlaying = ""
  broadcastEvent("FinishedPlayback", { id = playbackId })
}

::g_sound.preparePlayback <- function preparePlayback(url, playbackId) {
  if (u.isEmpty(url)
      || this.getPlaybackStatus(playbackId) != PLAYBACK_STATUS.INVALID)
    return

  this.playbackStatus[playbackId] <- PLAYBACK_STATUS.DOWNLOADING
  ::set_cached_music(CACHED_MUSIC_MISSION, url, playbackId)
}

::g_sound.play <- function play(playbackId = "") {
  if (playbackId == "" && this.curPlaying == "")
    return

  if (this.getPlaybackStatus(playbackId) != PLAYBACK_STATUS.VALID)
    return

  if (::play_cached_music(playbackId))
    this.curPlaying = playbackId
}

::g_sound.stop <- function stop() {
  ::play_cached_music("")
  this.curPlaying = ""
}

::g_sound.getPlaybackStatus <- function getPlaybackStatus(playbackId) {
  return getTblValue(playbackId, this.playbackStatus, PLAYBACK_STATUS.INVALID)
}

::g_sound.canPlay <- function canPlay(playbackId) {
  return this.getPlaybackStatus(playbackId) == PLAYBACK_STATUS.VALID
}

::g_sound.isPlaying <- function isPlaying(playbackId) {
  return playbackId == this.curPlaying && this.curPlaying != ""
}

::g_sound.onEventGameLocalizationChanged <- function onEventGameLocalizationChanged(_p) {
  this.stop()
  this.playbackStatus.clear()
}

registerPersistentDataFromRoot("g_sound")
subscribe_handler(::g_sound, ::g_listener_priority.DEFAULT_HANDLER)

//C++ call
::on_cached_music_play_end <- ::g_sound.onCachedMusicPlayEnd.bindenv(::g_sound)
//C++ call
::on_cached_music_downloaded <- ::g_sound.onCachedMusicDowloaded.bindenv(::g_sound)