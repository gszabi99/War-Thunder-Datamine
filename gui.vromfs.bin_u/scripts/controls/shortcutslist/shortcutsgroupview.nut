local { isPlatformSony } = require("scripts/clientState/platform.nut")

return [
//-------------------------------------------------------
  {
    id = "ID_VIEW_CONTROL_HEADER"
    type = CONTROL_TYPE.SECTION
    needShowInHelp = true
  }
  {
    id = "ID_ZOOM_TOGGLE"
    checkGroup = ctrlGroups.NO_GROUP
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_NEUTRAL"
    checkGroup = ctrlGroups.NO_GROUP
    checkAssign = false
    showFunc = @() ::has_feature("EnableMouse")
    needShowInHelp = true
  }
  {
    id = "ID_FIX_GUN_IN_MOUSE_LOOK"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_FIX_GUN_IN_MOUSE_LOOK
  }
  {
    id = "use_touchpad_for_aim"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(joyParams) joyParams.useTouchpadAiming
    setValue = function(joyParams, objValue) {
      local old = joyParams.useTouchpadAiming
      joyParams.useTouchpadAiming = objValue
      if (objValue != old)
        ::set_controls_preset("")
    }
    showFunc = @() ::has_feature("EnableMouse") && isPlatformSony
  }
  {
    id = "mouse_smooth"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_MOUSE_SMOOTH
    showFunc = @() ::has_feature("EnableMouse")
  }
  {
    id = "mouse_sensitivity"
    type = CONTROL_TYPE.SLIDER
    optionType = ::USEROPT_MOUSE_SENSE
  }
  {
    id = "joy_camera_sensitivity"
    type = CONTROL_TYPE.SLIDER
    optionType = ::USEROPT_MOUSE_AIM_SENSE
  }
  {
    id = "camera_mouse_speed"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0*(::get_option_multiplier(::OPTION_CAMERA_MOUSE_SPEED) - min_camera_speed) / (max_camera_speed - min_camera_speed)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_CAMERA_MOUSE_SPEED, min_camera_speed + (objValue / 100.0) * (max_camera_speed - min_camera_speed))
    showFunc = @() ::has_feature("EnableMouse")
  }
  {
    id = "camera_smooth"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_CAMERA_SMOOTH) / max_camera_smooth
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_CAMERA_SMOOTH, (objValue / 100.0) * max_camera_smooth)
  }
  {
    id = "zoom_sens"
    type = CONTROL_TYPE.SLIDER
    optionType = ::USEROPT_ZOOM_SENSE
  }
  {
    id = "invert_y_spectator"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTY_SPECTATOR
  }
  {
    id = "hangar_camera_x"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HANGAR
    checkAssign = false
  }
  {
    id = "hangar_camera_y"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HANGAR
    checkAssign = false
  }
  {
    id = "hangar_camera_zoom"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HANGAR
    checkAssign = false
  }
]
