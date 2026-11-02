import "%globalScripts/sharedWatched.nut" as sharedWatched


let spectatorSession = sharedWatched("spectatorSession", @() null)
let spectatorCameraTarget = sharedWatched("spectatorCameraTarget", @() null)
let isReplaySystemWindowOpened = sharedWatched("isReplaySystemWindowOpened", @() false)
let spectatorTeams = sharedWatched("spectatorTeams", @() null)

let spectatorAirHudOffsetX = sharedWatched("spectatorAirHudOffsetX", @() 0)

let spectatorToolbarShortcuts = freeze([
  "ID_FLIGHTMENU", "ID_MPSTATSCREEN", "ID_PREV_PLANE", "ID_NEXT_PLANE", "ID_CAMERA_DEFAULT",
  "ID_TOGGLE_FOLLOWING_CAMERA", "ID_REPLAY_CAMERA_OPERATOR", "ID_REPLAY_CAMERA_FLYBY", "ID_REPLAY_CAMERA_WING",
  "ID_REPLAY_CAMERA_GUN", "ID_REPLAY_CAMERA_RANDOMIZE", "ID_REPLAY_CAMERA_FREE", "ID_REPLAY_CAMERA_FREE_PARENTED",
  "ID_REPLAY_CAMERA_FREE_ATTACHED", "ID_REPLAY_CAMERA_HOVER", "ID_TOGGLE_FORCE_SPECTATOR_CAM_ROT",
  "ID_REPLAY_SHOW_MARKERS", "ID_REPLAY_TOGGLE_SENSOR_VIEW", "ID_REPLAY_SYSTEM_WINDOW", "ID_REPLAY_SLOWER",
  "ID_REPLAY_FASTER", "ID_REPLAY_BACKWARD", "ID_REPLAY_PAUSE", "ID_REPLAY_FORWARD",
])

return freeze({
  spectatorSession
  spectatorCameraTarget
  isReplaySystemWindowOpened
  spectatorTeams
  spectatorAirHudOffsetX
  spectatorToolbarShortcuts
})
