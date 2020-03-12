local isExperimentalCameraTrack = @() ::get_settings_blk()?.debug?.experimentalCameraTrack ?? false

return [
  {
    id = "ID_REPLAY_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    showFunc = @() ::has_feature("Replays") || ::has_feature("Spectator")
  }
  {
    id = "ID_TOGGLE_FOLLOWING_CAMERA"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_PREV_PLANE"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_NEXT_PLANE"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_GUN"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_WING"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_FLYBY"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_OPERATOR"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_FREE"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_RANDOMIZE"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_FREE_PARENTED"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_FREE_ATTACHED"
    checkGroup = ctrlGroups.REPLAY
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
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_ZOOM_IN"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_CAMERA_ZOOM_OUT"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_SLOWER"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_FASTER"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_PAUSE"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_AVI_WRITER"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
    showFunc = @() ::has_feature("Replays")
  }
  {
    id = "ID_REPLAY_SHOW_MARKERS"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_SPECTATOR_SHOW_CURSOR"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_CONTOURS"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "cam_fwd"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "cam_strafe"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "cam_vert"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "cam_roll"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_REPLAY_RESET_CAMERA_ROLL"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_REPLAY_TOGGLE_PLAYER_VISIBILITY"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_REPLAY_TOGGLE_DOF"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "ID_SPECTATOR_CAMERA_ROTATION"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
  }
  {
    id = "ID_REPLAY_TRACK_ADD_KEYFRAME"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
    dontCheckDupes = true
    showFunc = isExperimentalCameraTrack
  }
  {
    id = "ID_REPLAY_TRACK_REMOVE_KEYFRAME"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
    dontCheckDupes = true
    showFunc = isExperimentalCameraTrack
  }
  {
    id = "ID_REPLAY_TRACK_PLAY_STOP"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
    dontCheckDupes = true
    showFunc = isExperimentalCameraTrack
  }
  {
    id = "ID_REPLAY_TRACK_CLEAR_ALL"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
    dontCheckDupes = true
    showFunc = isExperimentalCameraTrack
  }
  {
    id = "ID_REPLAY_TOGGLE_LERP"
    checkGroup = ctrlGroups.REPLAY
    checkAssign = false
    dontCheckDupes = true
    showFunc = isExperimentalCameraTrack
  }
]