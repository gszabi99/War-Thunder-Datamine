return [
//-------------------------------------------------------
  {
    id = "ID_COMMON_TRACKER_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() !::is_platform_xboxone || ::ps4_headtrack_is_attached() || ::is_tracker_joystick()
  }
  {
    id = "headtrack_enable"
    type = CONTROL_TYPE.SWITCH_BOX
    showFunc = @() ::ps4_headtrack_is_attached()
    optionType = ::USEROPT_HEADTRACK_ENABLE
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "ID_TRACKER_RESET_POSITION"
    showFunc = @() !::is_platform_xboxone || ::g_controls_utils.checkOptionValue(::USEROPT_HEADTRACK_ENABLE, true)
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "tracker_camx"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
    showFunc = @() ::is_tracker_joystick()
  }
  {
    id = "tracker_camy"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
    showFunc = @() ::is_tracker_joystick()
  }
  {
    id = "trackIrZoom"
    type = CONTROL_TYPE.SWITCH_BOX
    showFunc = @() !::is_platform_xboxone || ::g_controls_utils.checkOptionValue(::USEROPT_HEADTRACK_ENABLE, true)
    value = @(joyParams) joyParams.trackIrZoom
    setValue = function(joyParams, objValue) {
      local prev = joyParams.trackIrZoom
      joyParams.trackIrZoom = objValue
      if (prev != objValue)
        ::set_controls_preset("")
    }
  }
  {
    id = "trackIrForLateralMovement"
    type = CONTROL_TYPE.SWITCH_BOX
    showFunc = @() !::is_platform_xboxone
    value = @(joyParams) joyParams.trackIrForLateralMovement
    setValue = function(joyParams, objValue) {
      local prev = joyParams.trackIrForLateralMovement
      joyParams.trackIrForLateralMovement = objValue
      if (prev != objValue)
        ::set_controls_preset("")
    }
  }
  {
    id = "trackIrAsHeadInTPS"
    type = CONTROL_TYPE.SWITCH_BOX
    showFunc = @() !::is_platform_xboxone || ::g_controls_utils.checkOptionValue(::USEROPT_HEADTRACK_ENABLE, true)
    value = @(joyParams) joyParams.trackIrAsHeadInTPS
    setValue = function(joyParams, objValue) {
      local prev = joyParams.trackIrAsHeadInTPS
      joyParams.trackIrAsHeadInTPS = objValue
      if (joyParams.trackIrAsHeadInTPS != prev)
        ::set_controls_preset("")
    }
  }
  {
    id = "headtrack_scale_x"
    type = CONTROL_TYPE.SLIDER
    showFunc = @() ::g_controls_utils.checkOptionValue(::USEROPT_HEADTRACK_ENABLE, true)
    optionType = ::USEROPT_HEADTRACK_SCALE_X
  }
  {
    id = "headtrack_scale_y"
    type = CONTROL_TYPE.SLIDER
    showFunc = @() ::g_controls_utils.checkOptionValue(::USEROPT_HEADTRACK_ENABLE, true)
    optionType = ::USEROPT_HEADTRACK_SCALE_Y
  }
]
