from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { MAX_CAMERA_SPEED, MAX_CAMERA_SMOOTH, MIN_CAMERA_SPEED } = require("%scripts/controls/controlsConsts.nut")

return [
//-------------------------------------------------------
  {
    id = "ID_VIEW_CONTROL_HEADER"
    type = CONTROL_TYPE.SECTION
    needShowInHelp = true
  }
  {
    id = "ID_ZOOM_TOGGLE"
    checkGroup = ctrlGroups.COMMON
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_NEUTRAL"
    checkGroup = ctrlGroups.NO_GROUP
    checkAssign = false
    showFunc = @() hasFeature("EnableMouse")
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
      let old = joyParams.useTouchpadAiming
      joyParams.useTouchpadAiming = objValue
      if (objValue != old)
        ::set_controls_preset("")
    }
    showFunc = @() hasFeature("EnableMouse") && isPlatformSony
  }
  {
    id = "mouse_smooth"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_MOUSE_SMOOTH
    showFunc = @() hasFeature("EnableMouse")
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
    value = @(_joyParams) 100.0*(::get_option_multiplier(OPTION_CAMERA_MOUSE_SPEED) - MIN_CAMERA_SPEED) / (MAX_CAMERA_SPEED - MIN_CAMERA_SPEED)
    setValue = @(_joyParams, objValue) ::set_option_multiplier(OPTION_CAMERA_MOUSE_SPEED, MIN_CAMERA_SPEED + (objValue / 100.0) * (MAX_CAMERA_SPEED - MIN_CAMERA_SPEED))
    showFunc = @() hasFeature("EnableMouse")
  }
  {
    id = "camera_smooth"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0*::get_option_multiplier(OPTION_CAMERA_SMOOTH) / MAX_CAMERA_SMOOTH
    setValue = @(_joyParams, objValue) ::set_option_multiplier(OPTION_CAMERA_SMOOTH, (objValue / 100.0) * MAX_CAMERA_SMOOTH)
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
