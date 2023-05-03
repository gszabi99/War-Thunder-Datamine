//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let isExperimentalCameraTrack = @() ::get_settings_blk()?.debug?.experimentalCameraTrack ?? false

return [
  {
    id = "ID_REPLAY_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    showFunc = @() hasFeature("ClientReplay") || hasFeature("ServerReplay") || hasFeature("Spectator")
  }
  {
    id = "ID_TOGGLE_FOLLOWING_CAMERA"
    checkAssign = false
  }
  {
    id = "ID_PREV_PLANE"
    checkAssign = false
  }
  {
    id = "ID_NEXT_PLANE"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_GUN"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_WING"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_FLYBY"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_OPERATOR"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_FREE"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_RANDOMIZE"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_FREE_PARENTED"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_FREE_ATTACHED"
    checkAssign = false
  }
  {
    id = "free_camera_inertia"
    type = CONTROL_TYPE.SLIDER
    optionType = ::USEROPT_FREE_CAMERA_INERTIA
  }
  {
    id = "replay_camera_wiggle"
    type = CONTROL_TYPE.SLIDER
    optionType = ::USEROPT_REPLAY_CAMERA_WIGGLE
  }
  {
    id = "ID_REPLAY_CAMERA_HOVER"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_ZOOM_IN"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_ZOOM_OUT"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_SLOWER"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_FASTER"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_PAUSE"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_AVI_WRITER"
    checkAssign = false
    showFunc = @() platformId != "macosx" && hasFeature("ClientReplay")
  }
  {
    id = "ID_REPLAY_SHOW_MARKERS"
    checkAssign = false
  }
  {
    id = "ID_SPECTATOR_SHOW_CURSOR"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_CONTOURS"
    checkAssign = false
  }
  {
    id = "cam_fwd"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "cam_strafe"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "cam_vert"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "cam_roll"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_REPLAY_RESET_CAMERA_ROLL"
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_REPLAY_TOGGLE_PLAYER_VISIBILITY"
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_REPLAY_TOGGLE_DOF"
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_SPECTATOR_CAMERA_ROTATION"
    checkAssign = false
  }
  {
    id = "ID_REPLAY_TRACK_ADD_KEYFRAME"
    checkAssign = false
    dontCheckDupes = true
    showFunc = isExperimentalCameraTrack
  }
  {
    id = "ID_REPLAY_TRACK_REMOVE_KEYFRAME"
    checkAssign = false
    dontCheckDupes = true
    showFunc = isExperimentalCameraTrack
  }
  {
    id = "ID_REPLAY_TRACK_PLAY_STOP"
    checkAssign = false
    dontCheckDupes = true
    showFunc = isExperimentalCameraTrack
  }
  {
    id = "ID_REPLAY_TRACK_CLEAR_ALL"
    checkAssign = false
    dontCheckDupes = true
    showFunc = isExperimentalCameraTrack
  }
  {
    id = "ID_REPLAY_TOGGLE_LERP"
    checkAssign = false
    dontCheckDupes = true
    showFunc = isExperimentalCameraTrack
  }
  {
    id = "ID_REPLAY_TOGGLE_DETACHED_MOVE_DIR"
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "free_camera_zoom_speed"
    type = CONTROL_TYPE.SLIDER
    optionType = ::USEROPT_FREE_CAMERA_ZOOM_SPEED
  }
  {
    id = "ID_REPLAY_CAMERA_TWO_PLANES"
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_REPLAY_CAMERA_NEXT_PLANE"
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_REPLAY_CAMERA_HORIZONTAL_LOCK"
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_REPLAY_CAMERA_LOCK_SPEED"
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_REPLAY_CAMERA_LOCK_SPEED_TO_PLANE"
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_REPLAY_CAMERA_WIGGLE"
    checkAssign = false
    dontCheckDupes = true
  }
]