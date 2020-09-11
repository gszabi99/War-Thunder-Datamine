local globalEnv = require_native("globalEnv")
local controlsOperations = require("scripts/controls/controlsOperations.nut")
local { unitClassType } = require("scripts/unit/unitClassType.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { isWheelmenuAxisConfigurable } = require("scripts/wheelmenu/multifuncmenuShared.nut")
local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")

local isMouseAimSelected = @() (::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.AIM)
local needFullGunnerSettings = @() isPlatformSony || isPlatformXboxOne || !isMouseAimSelected()

return [
  {
    id = "ID_PLANE_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitType = unitTypes.AIRCRAFT
    unitClassTypes = [
      unitClassType.FIGHTER
      unitClassType.BOMBER
      unitClassType.ASSAULT
    ]
    isHelpersVisible = true
    needShowInHelp = true
  }
//-------------------------------------------------------
  {
    id = "ID_PLANE_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() ::have_xinput_device()
  }
  {
    id = "ID_PLANE_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ctrlGroups.AIR,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() ::have_xinput_device()
  }
  {
    id = "ID_PLANE_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks( ctrlGroups.AIR )
    showFunc = @() ::have_xinput_device()
  }
//-------------------------------------------------------
  {
    id = "ID_PLANE_MODE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "mouse_usage"
    type = CONTROL_TYPE.SPINNER
    optionType = ::USEROPT_MOUSE_USAGE
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "mouse_usage_no_aim"
    type = CONTROL_TYPE.SPINNER
    showFunc = @() ::has_feature("SimulatorDifficulty") && isMouseAimSelected()
    optionType = ::USEROPT_MOUSE_USAGE_NO_AIM
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "instructor_enabled"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INSTRUCTOR_ENABLED
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "autotrim"
    type = CONTROL_TYPE.SWITCH_BOX
    filterHide = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
    optionType = ::USEROPT_AUTOTRIM
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "ID_TOGGLE_INSTRUCTOR"
    checkAssign = false
  }
  {
    id="ID_FBW_MODE"
    showFunc = @() ::has_feature("AirplaneFbw"),
    filterShow = [globalEnv.EM_FULL_REAL]
  }
//-------------------------------------------------------
  {
    id = "ID_PLANE_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_FIRE_MGUNS"
    conflictGroup = ConflictGroups.PLANE_FIRE
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_CANNONS"
    conflictGroup = ConflictGroups.PLANE_FIRE
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_ADDITIONAL_GUNS"
    conflictGroup = ConflictGroups.PLANE_FIRE
    needShowInHelp = true
  }
  {
    id = "fire"
    type = CONTROL_TYPE.AXIS
    alternativeIds = [
      "ID_FIRE_MGUNS"
      "ID_FIRE_CANNONS"
      "ID_FIRE_ADDITIONAL_GUNS"
    ]
  }
  {
    id = "ID_FIRE_PRIMARY"
    showFunc = @() ::has_feature("WeaponCycleTrigger")
    checkAssign = false
  }
  {
    id = "ID_FIRE_SECONDARY"
    showFunc = @() ::has_feature("WeaponCycleTrigger")
    checkAssign = false
  }
  {
    id = "ID_BAY_DOOR"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_BOMBS"
    needShowInHelp = true
  }
  {
    id = "ID_BOMBS_SERIES"
    alternativeIds = [ "ID_BOMBS" ]
  }
  {
    id = "ID_ROCKETS"
    needShowInHelp = true
  }
  {
    id = "ID_ROCKETS_SERIES"
    alternativeIds = [ "ID_ROCKETS" ]
  }
  {
    id = "ID_AGM"
    needShowInHelp = true
  }
  {
    id = "ID_AAM"
    needShowInHelp = true
  }
  {
    id = "ID_FUEL_TANKS"
    showFunc = @() ::has_feature("Payload")
    checkAssign = false
  }
  {
    id = "ID_AIR_DROP"
    showFunc = @() ::has_feature("Payload")
    checkAssign = false
  }
  {
    id = "ID_WEAPON_LOCK"
    checkAssign = false
  }
  {
    id = "ID_EXIT_SHOOTING_CYCLE_MODE"
    showFunc = @() ::has_feature("WeaponCycleTrigger")
    checkAssign = false
  }
  {
    id = "ID_SWITCH_SHOOTING_CYCLE_PRIMARY"
    showFunc = @() ::has_feature("WeaponCycleTrigger")
    checkAssign = false
  }
  {
    id = "ID_SWITCH_SHOOTING_CYCLE_SECONDARY"
    showFunc = @() ::has_feature("WeaponCycleTrigger")
    checkAssign = false
  }
  {
    id = "ID_FLARES"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_PERIODIC_FLARES"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_MLWS_FLARES_SLAVING"
    checkAssign = false
  }
  {
    id = "weapon_aim_heading"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "weapon_aim_pitch"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "ID_SENSOR_SWITCH"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_MODE_SWITCH"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_SCAN_PATTERN_SWITCH"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_RANGE_SWITCH"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_TARGET_SWITCH"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_TARGET_LOCK"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SCHRAEGE_MUSIK"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_RELOAD_GUNS"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TOGGLE_CANNONS_AND_ROCKETS_BALLISTIC_COMPUTER"
    checkAssign = false
    //showFunc = @() ::has_feature("ConstantlyComputedWeaponSight")
  }
  {
    id = "ID_SWITCH_COCKPIT_SIGHT_MODE"
    checkAssign = false
    showFunc = @() ::has_feature("ConstantlyComputedWeaponSight")
  }
  {
    id = "ID_SWITCH_REGISTERED_BOMB_TARGETING_POINT"
    checkAssign = false
    showFunc = @() ::has_feature("ConstantlyComputedWeaponSight")
  }
  {
    id = "ID_LOCK_TARGETING_AT_POINT"
    checkAssign = false
    needShowInHelp = true
    showFunc = @() ::has_feature("PointOfInterestDesignator")
  }
  {
    id = "ID_UNLOCK_TARGETING_AT_POINT"
    checkAssign = false
    needShowInHelp = true
    showFunc = @() ::has_feature("PointOfInterestDesignator")
  }
//-------------------------------------------------------
  {
    id = "ID_PLANE_AXES_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "mouse_z"
    type = CONTROL_TYPE.MOUSE_AXIS
    axis_num = MouseAxis.MOUSE_SCROLL
    values = ["none", "throttle", "zoom", /*"elevator",*/ "camy", /* "weapon"*/]
    onChangeValue = "onMouseWheel"
    showFunc = @() ::has_feature("EnableMouse")
  }
  {
    id = "mouse_z_mult"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_MOUSE_Z_MULT)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_Z_MULT, objValue / 100.0)
    showFunc = @() ::has_feature("EnableMouse")
  }
  {
    id = "throttle"
    type = CONTROL_TYPE.AXIS
    def_relative = true
    needShowInHelp = true
  }
  {
    id = "holdThrottleForWEP"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(joyParams) joyParams.holdThrottleForWEP
    setValue = function(joyParams, objValue)
    {
      local old  = joyParams.holdThrottleForWEP
      joyParams.holdThrottleForWEP = objValue
      if (objValue != old)
        ::set_controls_preset("")
    }
  }
  {
    id = "ailerons"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    needShowInHelp = true
  }
  {
    id = "elevator"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    needShowInHelp = true
  }
  {
    id = "rudder"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    needShowInHelp = true
  }
  {
    id = "roll_sens"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    optionType = ::USEROPT_AILERONS_MULTIPLIER
  }
  {
    id = "pitch_sens"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    optionType = ::USEROPT_ELEVATOR_MULTIPLIER
  }
  {
    id = "yaw_sens"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    optionType = ::USEROPT_RUDDER_MULTIPLIER
  }
  {
    id = "invert_y"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTY
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "invert_x"
    type = CONTROL_TYPE.SWITCH_BOX
    filterHide = [globalEnv.EM_INSTRUCTOR, globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL]
    optionType = ::USEROPT_INVERTX
    showFunc = @() ::g_controls_utils.checkOptionValue(::USEROPT_INVERTY, true)
  }
  {
    id = "joyFX"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_JOYFX
    showFunc = @() ::is_platform_pc
  }
  {
    id = "multiplier_force_gain"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    optionType = ::USEROPT_FORCE_GAIN
  }
//-------------------------------------------------------
  {
    id = "ID_PLANE_MECHANIZATION_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_IGNITE_BOOSTERS"
    reqInMouseAim = false
    checkAssign = false
  }
  {
    id = "ID_FLAPS"
    reqInMouseAim = false
    alternativeIds = [ "ID_FLAPS_DOWN", "ID_FLAPS_UP" ]
  }
  {
    id = "ID_FLAPS_DOWN"
    reqInMouseAim = false
  }
  {
    id = "ID_FLAPS_UP"
    reqInMouseAim = false
  }
  {
    id = "ID_AIR_BRAKE"
    reqInMouseAim = false
  }
  {
    id = "ID_GEAR"
    needShowInHelp = true
  }
  {
    id = "brake_left"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    filterShow = [globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL]
  }
  {
    id = "brake_right"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    filterShow = [globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL]
  }
  {
    id = "ID_CHUTE"
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_PLANE_GUNNERS_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_TOGGLE_GUNNERS"
    checkAssign = false
  }
  {
    id = "turret_x"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    showFunc = needFullGunnerSettings
  }
  {
    id = "turret_y"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    showFunc = needFullGunnerSettings
  }
  {
    id = "gunner_view_sens"
    type = CONTROL_TYPE.SLIDER
    optionType = ::USEROPT_GUNNER_VIEW_SENSE
    showFunc = needFullGunnerSettings
  }
  {
    id = "gunner_view_zoom_sens"
    type = CONTROL_TYPE.SLIDER
    optionType = ::USEROPT_GUNNER_VIEW_ZOOM_SENS
    showFunc = @() needFullGunnerSettings() && ::have_per_vehicle_zoom_sens
  }
  {
    id = "gunner_joy_speed"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0*(::get_option_multiplier(::OPTION_CAMERA_SPEED) - min_camera_speed) / (max_camera_speed - min_camera_speed)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_CAMERA_SPEED, min_camera_speed + (objValue / 100.0) * (max_camera_speed - min_camera_speed))
    showFunc = needFullGunnerSettings
  }
  {
    id = "invert_y_gunner"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_GUNNER_INVERTY
  }
//-------------------------------------------------------
  {
    id = "ID_PLANE_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_TOGGLE_VIEW"
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_FPS"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_TPS"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_VIRTUAL_FPS"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_DEFAULT"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_GUNNER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_BOMBVIEW"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_FOLLOW_OBJECT"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TARGET_CAMERA"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_AIM_CAMERA"
    checkAssign = false,
    condition = @() isPlatformSony || isPlatformXboxOne
  }
  {
    id = "target_camera"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    condition = @() isPlatformSony || isPlatformXboxOne
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
  }
  {
    id = "ID_CAMERA_VIEW_DOWN"
    checkAssign = false
  }
  {
    id = "ID_CAMERA_VIEW_BACK"
    checkAssign = false
  }
  {
    id = "invert_y_camera"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTCAMERAY
  }
  {
    id = "zoom"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "camx"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.X
  }
  {
    id = "camy"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "head_pos_x"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "head_pos_y"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    dontCheckDupes = true
  }
  {
    id = "head_pos_z"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    dontCheckDupes = true
  }
//-------------------------------------------------------
  {
    id = "ID_PLANE_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_AEROBATICS_SMOKE"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_COCKPIT_DOOR"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_COCKPIT_LIGHTS"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_COLLIMATOR"
    filterShow = [globalEnv.EM_FULL_REAL]
  }
  {
    id = "wheelmenu_x"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.X
    checkGroup = ctrlGroups.AIR
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = @() (isPlatformSony || isPlatformXboxOne || ::is_xinput_device()) && isWheelmenuAxisConfigurable()
    checkAssign = @() ::is_xinput_device() && isWheelmenuAxisConfigurable()
  }
  {
    id = "wheelmenu_y"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.Y
    checkGroup = ctrlGroups.AIR
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = @() (isPlatformSony || isPlatformXboxOne || ::is_xinput_device()) && isWheelmenuAxisConfigurable()
    checkAssign = @() ::is_xinput_device() && isWheelmenuAxisConfigurable()
  }
//-------------------------------------------------------
  {
    id = "ID_INSTRUCTOR_HEADER"
    type = CONTROL_TYPE.SECTION
    filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
  }
  {
    id = "instructor_ground_avoidance"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
    optionType = ::USEROPT_INSTRUCTOR_GROUND_AVOIDANCE
  }
  {
    id = "instructor_gear_control"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
    optionType = ::USEROPT_INSTRUCTOR_GEAR_CONTROL
  }
  {
    id = "instructor_flaps_control"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
    optionType = ::USEROPT_INSTRUCTOR_FLAPS_CONTROL
  }
  {
    id = "instructor_engine_control"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
    optionType = ::USEROPT_INSTRUCTOR_ENGINE_CONTROL
  }
  {
    id = "instructor_simple_joy"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [globalEnv.EM_INSTRUCTOR]
    optionType = ::USEROPT_INSTRUCTOR_SIMPLE_JOY
  }
//-------------------------------------------------------
  {
    id = "ID_PLANE_MOUSE_AIM_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    filterHide = [globalEnv.EM_INSTRUCTOR, globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL]
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
  }
  {
    id = "mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    filterHide = [globalEnv.EM_INSTRUCTOR, globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL]
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
  }
  {
    id = "aim_time_nonlinearity_air"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_AIR)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_AIR, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_air"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_AIR)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_AIR, objValue / 100.0)
  }
//-------------------------------------------------------
  {
    id = "ID_PLANE_JOYSTICK_HEADER"
    type = CONTROL_TYPE.SECTION
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
  }
  {
    id = "mouse_joystick_mode"
    type = CONTROL_TYPE.SPINNER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    options = ["#options/mouse_joy_mode_simple", "#options/mouse_joy_mode_standard"]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams) ::get_option_int(::OPTION_MOUSE_JOYSTICK_MODE)
    setValue = @(joyParams, objValue) ::set_option_int(::OPTION_MOUSE_JOYSTICK_MODE, objValue)
  }
  {
    id = "mouse_joystick_sensitivity"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams)
      100.0*(::get_option_multiplier(::OPTION_MOUSE_JOYSTICK_SENSITIVITY) - ::minMouseJoystickSensitivity) /
        (::maxMouseJoystickSensitivity - ::minMouseJoystickSensitivity)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SENSITIVITY, ::minMouseJoystickSensitivity + (objValue / 100.0) *
        (::maxMouseJoystickSensitivity - ::minMouseJoystickSensitivity))
  }
  {
    id = "mouse_joystick_deadzone"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_MOUSE_JOYSTICK_DEADZONE) / ::maxMouseJoystickDeadZone
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_DEADZONE,
      (objValue / 100.0) * ::maxMouseJoystickDeadZone)
  }
  {
    id = "mouse_joystick_screensize"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams)
      100.0*(::get_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENSIZE) - ::minMouseJoystickScreenSize) /
        (::maxMouseJoystickScreenSize - ::minMouseJoystickScreenSize)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENSIZE, ::minMouseJoystickScreenSize + (objValue / 100.0) *
        (::maxMouseJoystickScreenSize - ::minMouseJoystickScreenSize))
  }
  {
    id = "mouse_joystick_screen_place"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENPLACE)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENPLACE, objValue / 100.0)
  }
  {
    id = "mouse_joystick_aileron"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
    value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_MOUSE_AILERON_AILERON_FACTOR) / ::maxMouseJoystickAileron
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_AILERON_AILERON_FACTOR,
      (objValue / 100.0) * ::maxMouseJoystickAileron)
  }
  {
    id = "mouse_joystick_rudder"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
    value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_MOUSE_AILERON_RUDDER_FACTOR) / ::maxMouseJoystickRudder
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_AILERON_RUDDER_FACTOR,
      (objValue / 100.0) * ::maxMouseJoystickRudder)
  }
  {
    id = "mouse_joystick_square"
    type = CONTROL_TYPE.SWITCH_BOX
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(joyParams) ::get_option_mouse_joystick_square()
    setValue = @(joyParams, objValue) ::set_option_mouse_joystick_square(objValue)
  }
  {
    id = "ID_CENTER_MOUSE_JOYSTICK"
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() ::is_mouse_available() && (::g_controls_utils.getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK)
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_TRIM_CONTROL_HEADER"
    type = CONTROL_TYPE.SECTION
    filterShow = [globalEnv.EM_FULL_REAL]
  }
  {
    id = "ID_TRIM"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TRIM_RESET"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TRIM_SAVE"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "trim_elevator"
    type = CONTROL_TYPE.AXIS
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "trim_ailerons"
    type = CONTROL_TYPE.AXIS
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "trim_rudder"
    type = CONTROL_TYPE.AXIS
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_MANUAL_ENGINE_CONTROL_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_COMPLEX_ENGINE"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_ENGINE"
    checkAssign = false
  }
  {
    id = "mixture"
    type = CONTROL_TYPE.AXIS
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "prop_pitch"
    type = CONTROL_TYPE.AXIS
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_PROP_PITCH_AUTO"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "radiator"
    type = CONTROL_TYPE.AXIS
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "oil_radiator"
    type = CONTROL_TYPE.AXIS
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_RADIATOR_AUTO"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "turbo_charger"
    type = CONTROL_TYPE.AXIS
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_AUTO_TURBO_CHARGER"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_SUPERCHARGER"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_MAGNETO_INCREASE"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_MAGNETO_DECREASE"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_PROP_FEATHERING"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_EXTINGUISHER"
    filterShow = [globalEnv.EM_FULL_REAL]
    showFunc = @() ::has_feature("AircraftExtinguisher")
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_1_ENGINE_CONTROL"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_2_ENGINE_CONTROL"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_3_ENGINE_CONTROL"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_4_ENGINE_CONTROL"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_5_ENGINE_CONTROL"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_6_ENGINE_CONTROL"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_ENABLE_ALL_ENGINE_CONTROL"
    filterShow = [globalEnv.EM_FULL_REAL]
    checkAssign = false
  }
]
