local globalEnv = require_native("globalEnv")
local controlsOperations = require("scripts/controls/controlsOperations.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { isWheelmenuAxisConfigurable } = require("scripts/wheelmenu/multifuncmenuShared.nut")

return [
  {
    id = "ID_HELICOPTER_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitType = unitTypes.HELICOPTER
    isHelpersVisible = true
    needShowInHelp = true
  }
//-------------------------------------------------------
  {
    id = "ID_HELICOPTER_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() ::have_xinput_device()
  }
  {
    id = "ID_HELICOPTER_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ctrlGroups.HELICOPTER,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() ::have_xinput_device()
  }
  {
    id = "ID_HELICOPTER_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON,
    onClick = @() controlsOperations.swapGamepadSticks( ctrlGroups.HELICOPTER )
    showFunc = @() ::have_xinput_device()
  }
//-------------------------------------------------------
  {
    id = "ID_HELICOPTER_MODE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "mouse_usage_helicopter"
    type = CONTROL_TYPE.SPINNER
    optionType = ::USEROPT_MOUSE_USAGE
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "mouse_usage_no_aim_helicopter"
    type = CONTROL_TYPE.SPINNER
    showFunc = @() ::has_feature("SimulatorDifficulty") && (::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.AIM)
    optionType = ::USEROPT_MOUSE_USAGE_NO_AIM
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "instructor_enabled_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INSTRUCTOR_ENABLED
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "autotrim_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    filterHide = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
    optionType = ::USEROPT_AUTOTRIM
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "ID_TOGGLE_INSTRUCTOR_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_CONTROL_MODE_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_MOUSE_AIM_OVERRIDE_ROLL_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    filterShow = [globalEnv.EM_MOUSE_AIM]
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FBW_MODE_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_HELICOPTER_AXES_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "helicopter_collective"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HELICOPTER
    needShowInHelp = true
  }
  {
    id = "helicopter_holdThrottleForWEP"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(joyParams) joyParams.holdThrottleForWEP
    setValue = function(joyParams, objValue) {
      local old = joyParams.holdThrottleForWEP
      joyParams.holdThrottleForWEP = objValue
      if (objValue != old)
        ::set_controls_preset("")
    }
  }
  {
    id = "helicopter_climb"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HELICOPTER
    filterShow = [ globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR ]
  }
  {
    id = "helicopter_cyclic_roll"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HELICOPTER
    def_relative = false
    reqInMouseAim = false
    needShowInHelp = true
  }
  {
    id = "helicopter_cyclic_pitch"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HELICOPTER
    def_relative = false
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "helicopter_pedals"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HELICOPTER
    def_relative = false
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "helicopter_cyclic_roll_sens"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ globalEnv.EM_MOUSE_AIM ]
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_HELICOPTER_CYCLIC_ROLL_MULTIPLIER)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_HELICOPTER_CYCLIC_ROLL_MULTIPLIER, objValue / 100.0)
  }
  {
    id = "helicopter_cyclic_pitch_sens"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ globalEnv.EM_MOUSE_AIM ]
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_HELICOPTER_CYCLIC_PITCH_MULTIPLIER)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_HELICOPTER_CYCLIC_PITCH_MULTIPLIER, objValue / 100.0)
  }
  {
    id = "helicopter_pedals_sens"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ globalEnv.EM_MOUSE_AIM ]
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_HELICOPTER_PEDALS_MULTIPLIER)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_HELICOPTER_PEDALS_MULTIPLIER, objValue / 100.0)
  }
//-------------------------------------------------------
  {
    id = "ID_HELICOPTER_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_FIRE_MGUNS_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    conflictGroup = ConflictGroups.HELICOPTER_FIRE
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_CANNONS_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    conflictGroup = ConflictGroups.HELICOPTER_FIRE
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_ADDITIONAL_GUNS_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    conflictGroup = ConflictGroups.HELICOPTER_FIRE
    needShowInHelp = true
  }
  {
    id = "helicopter_fire"
    checkGroup = ctrlGroups.HELICOPTER
    alternativeIds = [
      "ID_FIRE_MGUNS_HELICOPTER"
      "ID_FIRE_CANNONS_HELICOPTER"
      "ID_FIRE_ADDITIONAL_GUNS_HELICOPTER"
    ]
    type = CONTROL_TYPE.AXIS
  }
  {
    id = "ID_BOMBS_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    needShowInHelp = true
  }
  {
    id = "ID_BOMBS_SERIES_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    alternativeIds = [ "ID_BOMBS_HELICOPTER" ]
  }
  {
    id = "ID_ROCKETS_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    needShowInHelp = true
  }
  {
    id = "ID_ROCKETS_SERIES_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    alternativeIds = [ "ID_ROCKETS_HELICOPTER" ]
  }
  {
    id = "ID_WEAPON_LOCK_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_AGM_LOCK_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_LASER_DESIGNATOR_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_SENSOR_SWITCH_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_MODE_SWITCH_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_SENSOR_SCAN_PATTERN_SWITCH_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_SENSOR_RANGE_SWITCH_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_SENSOR_TARGET_SWITCH_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_TARGET_LOCK_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FLARES_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_FLARES_SERIES_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_PERIODIC_FLARES_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_MLWS_FLARES_SLAVING_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_ATGM_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    needShowInHelp = true
  }
  {
    id = "ID_AAM_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    needShowInHelp = true
  }
  {
    id = "helicopter_atgm_aim_x"
    checkGroup = ctrlGroups.HELICOPTER
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.X
  }
  {
    id = "helicopter_atgm_aim_y"
    checkGroup = ctrlGroups.HELICOPTER
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "atgm_aim_sens_helicopter"
    optionType = ::USEROPT_ATGM_AIM_SENS_HELICOPTER
    type = CONTROL_TYPE.SLIDER
  }
  {
    id = "atgm_aim_zoom_sens_helicopter"
    optionType = ::USEROPT_ATGM_AIM_ZOOM_SENS_HELICOPTER
    type = CONTROL_TYPE.SLIDER
    showFunc = @() ::have_per_vehicle_zoom_sens
  }
  {
    id = "ID_CHANGE_SHOT_FREQ_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_HELICOPTER_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_TOGGLE_VIEW_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_LOCK_TARGETING_AT_POINT_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_UNLOCK_TARGETING_AT_POINT_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_FPS_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_TPS_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_VIRTUAL_FPS_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_CAMERA_VIRTUAL_TARGET_FPS_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_GUNNER_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TARGET_CAMERA_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_AIM_CAMERA_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    condition = @() ::is_ps4_or_xbox
  }
  {
    id = "target_camera_helicopter"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    condition = @() ::is_ps4_or_xbox
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
  }
  {
    id = "helicopter_zoom"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "helicopter_camx"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    axisDirection = AxisDirection.X
  }
  {
    id = "helicopter_camy"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "invert_y_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTY_HELICOPTER
  }
  {
    id = "invert_y_helicopter_gunner"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTY_HELICOPTER_GUNNER
  }
  {
    id = "helicopter_mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    axisDirection = AxisDirection.X
  }
  {
    id = "helicopter_mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "aim_time_nonlinearity_helicopter"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_HELICOPTER)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_HELICOPTER, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_helicopter"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_HELICOPTER)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_HELICOPTER, objValue / 100.0)
  }
  {
    id = "mouse_z_helicopter"
    type = CONTROL_TYPE.MOUSE_AXIS
    axis_num = MouseAxis.MOUSE_SCROLL_HELICOPTER
    values = ["none", "helicopter_collective", "helicopter_climb", "helicopter_zoom"]
    onChangeValue = "onMouseWheel"
    showFunc = @() ::has_feature("EnableMouse")
  }
  {
    id = "mouse_z_mult_helicopter"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_MOUSE_Z_HELICOPTER_MULT)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_Z_HELICOPTER_MULT, objValue / 100.0)
    showFunc = @() ::has_feature("EnableMouse")
  }
//-------------------------------------------------------
  {
    id = "ID_HELICOPTER_INSTRUCTOR_HEADER"
    type = CONTROL_TYPE.SECTION
    filterShow = [ globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR ]
  }
  {
    id = "instructor_ground_avoidance_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR ]
    optionType = ::USEROPT_INSTRUCTOR_GROUND_AVOIDANCE
  }
  {
    id = "instructor_gear_control_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR ]
    optionType = ::USEROPT_INSTRUCTOR_GEAR_CONTROL
  }
  {
    id = "instructor_engine_control_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR ]
    optionType = ::USEROPT_INSTRUCTOR_ENGINE_CONTROL
  }
  {
    id = "instructor_simple_joy_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ globalEnv.EM_INSTRUCTOR ]
    optionType = ::USEROPT_INSTRUCTOR_SIMPLE_JOY
  }
//-------------------------------------------------------
  {
    id = "ID_HELICOPTER_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_TOGGLE_ENGINE_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_GEAR_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FLAPS_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FLAPS_UP_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FLAPS_DOWN_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TOGGLE_COCKPIT_DOOR_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_COCKPIT_LIGHTS_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_COLLIMATOR_HELICOPTER"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
    filterShow = [globalEnv.EM_FULL_REAL]
  }
  {
    id = "ID_MFD_1_PAGE"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_MFD_2_PAGE"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_MFD_3_PAGE"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_MFD_ZOOM"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_HELI_GUNNER_NIGHT_VISION"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_THERMAL_WHITE_IS_HOT_HELI"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_CANNONS_AND_ROCKETS_BALLISTIC_COMPUTER_HELICOPTER"
    checkAssign = false
    showFunc = @() ::has_feature("ConstantlyComputedWeaponSight")
  }
  {
    id = "ID_SWITCH_COCKPIT_SIGHT_MODE_HELICOPTER"
    checkAssign = false
    showFunc = @() ::has_feature("ConstantlyComputedWeaponSight")
  }
  {
    id = "ID_REQUEST_DETECT_ALLY_HELI"
    checkGroup = ctrlGroups.HELICOPTER
    checkAssign = false
  }
  {
    id = "helicopter_wheelmenu_x"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.X
    checkGroup = ctrlGroups.HELICOPTER
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = @() (::is_ps4_or_xbox || ::is_xinput_device()) && isWheelmenuAxisConfigurable()
    checkAssign = @() ::is_xinput_device() && isWheelmenuAxisConfigurable()
  }
  {
    id = "helicopter_wheelmenu_y"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.Y
    checkGroup = ctrlGroups.HELICOPTER
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = @() (::is_ps4_or_xbox || ::is_xinput_device()) && isWheelmenuAxisConfigurable()
    checkAssign = @() ::is_xinput_device() && isWheelmenuAxisConfigurable()
  }
//-------------------------------------------------------
  {
    id = "ID_HELICOPTER_JOYSTICK_HEADER"
    type = CONTROL_TYPE.SECTION
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
  }
  {
    id = "mouse_joystick_mode_helicopter"
    type = CONTROL_TYPE.SPINNER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    options = ["#options/mouse_joy_mode_simple", "#options/mouse_joy_mode_standard"]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams) ::get_option_int(::OPTION_HELICOPTER_MOUSE_JOYSTICK_MODE)
    setValue = @(joyParams, objValue) ::set_option_int(::OPTION_HELICOPTER_MOUSE_JOYSTICK_MODE, objValue)
  }
  {
    id = "mouse_joystick_sensitivity_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams)
      100.0*(::get_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SENSITIVITY) - ::minMouseJoystickSensitivity) /
        (::maxMouseJoystickSensitivity - ::minMouseJoystickSensitivity)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SENSITIVITY, ::minMouseJoystickSensitivity + (objValue / 100.0) *
        (::maxMouseJoystickSensitivity - ::minMouseJoystickSensitivity))
  }
  {
    id = "mouse_joystick_deadzone_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_DEADZONE) / ::maxMouseJoystickDeadZone
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_DEADZONE,
      (objValue / 100.0) * ::maxMouseJoystickDeadZone)
  }
  {
    id = "mouse_joystick_screensize_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams)
      100.0*(::get_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENSIZE) - ::minMouseJoystickScreenSize) /
        (::maxMouseJoystickScreenSize - ::minMouseJoystickScreenSize)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENSIZE, ::minMouseJoystickScreenSize + (objValue / 100.0) *
        (::maxMouseJoystickScreenSize - ::minMouseJoystickScreenSize))
  }
  {
    id = "mouse_joystick_screen_place_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENPLACE)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENPLACE, objValue / 100.0)
  }
  {
    id = "mouse_joystick_aileron_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
    value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_HELICOPTER_MOUSE_AILERON_AILERON_FACTOR) / ::maxMouseJoystickAileron
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_AILERON_AILERON_FACTOR,
      (objValue / 100.0) * ::maxMouseJoystickAileron)
  }
  {
    id = "mouse_joystick_rudder_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
    value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_HELICOPTER_MOUSE_AILERON_RUDDER_FACTOR) / ::maxMouseJoystickRudder
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_AILERON_RUDDER_FACTOR,
      (objValue / 100.0) * ::maxMouseJoystickRudder)
  }
  {
    id = "helicopter_mouse_joystick_square"
    type = CONTROL_TYPE.SWITCH_BOX
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams) ::get_option_mouse_joystick_square()
    setValue = @(joyParams, objValue) ::set_option_mouse_joystick_square(objValue)
  }
  {
    id = "ID_HELICOPTER_CENTER_MOUSE_JOYSTICK"
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::is_mouse_available() && (::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK)
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_HELICOPTER_TRIM_CONTROL_HEADER"
    type = CONTROL_TYPE.SECTION
    filterShow = [globalEnv.EM_FULL_REAL]
  }
  {
    id = "ID_HELICOPTER_TRIM"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_HELICOPTER_TRIM_RESET"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_HELICOPTER_TRIM_SAVE"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "helicopter_trim_elevator"
    type = CONTROL_TYPE.AXIS
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "helicopter_trim_ailerons"
    type = CONTROL_TYPE.AXIS
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "helicopter_trim_rudder"
    type = CONTROL_TYPE.AXIS
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
]
