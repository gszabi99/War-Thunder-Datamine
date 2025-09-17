from "%scripts/dagui_natives.nut" import is_mouse_available
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import AIR_MOUSE_USAGE, CONTROL_TYPE, AxisDirection, ConflictGroups

let { ControlHelpersMode } = require("globalEnv")
let { get_game_params } = require("gameparams")
let { get_option_multiplier, set_option_multiplier, get_option_int, set_option_int,
  OPTION_HELICOPTER_CYCLIC_ROLL_MULTIPLIER, OPTION_HELICOPTER_CYCLIC_PITCH_MULTIPLIER,
  OPTION_HELICOPTER_PEDALS_MULTIPLIER, OPTION_HELICOPTER_MOUSE_JOYSTICK_DEADZONE,
  OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENSIZE, OPTION_HELICOPTER_MOUSE_JOYSTICK_SENSITIVITY,
  OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENPLACE, OPTION_HELICOPTER_MOUSE_AILERON_AILERON_FACTOR,
  OPTION_HELICOPTER_MOUSE_AILERON_RUDDER_FACTOR, OPTION_AIM_TIME_NONLINEARITY_HELICOPTER,
  OPTION_AIM_ACCELERATION_DELAY_HELICOPTER, OPTION_MOUSE_Z_HELICOPTER_MULT,
  OPTION_HELICOPTER_MOUSE_JOYSTICK_MODE
} = require("gameOptions")
let controlsOperations = require("%scripts/controls/controlsOperations.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isPlatformSony, isPlatformXbox } = require("%scripts/clientState/platform.nut")
let { ActionGroup, hasXInputDevice, isXInputDevice } = require("controls")
let { getMouseUsageMask } = require("%scripts/controls/controlsUtils.nut")
let { USEROPT_MOUSE_USAGE, USEROPT_MOUSE_USAGE_NO_AIM, USEROPT_INSTRUCTOR_ENABLED,
  USEROPT_AUTOTRIM, USEROPT_ATGM_AIM_SENS_HELICOPTER, USEROPT_ATGM_AIM_ZOOM_SENS_HELICOPTER,
  USEROPT_INVERTY_HELICOPTER, USEROPT_INVERTY_HELICOPTER_GUNNER, USEROPT_INSTRUCTOR_GROUND_AVOIDANCE,
  USEROPT_INSTRUCTOR_GEAR_CONTROL, USEROPT_INSTRUCTOR_ENGINE_CONTROL, USEROPT_INSTRUCTOR_SIMPLE_JOY,
} = require("%scripts/options/optionsExtNames.nut")
let { hasMappedSecondaryWeaponSelector } = require("%scripts/controls/shortcutsUtils.nut")
let { commitControls } = require("%scripts/controls/controlsManager.nut")
let { set_option_mouse_joystick_square_helicopter,
 get_option_mouse_joystick_square_helicopter
} = require("controlsOptions")

return [
  {
    id = "ID_HELICOPTER_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitTypes = [ unitTypes.HELICOPTER ]
    isHelpersVisible = true
    needShowInHelp = true
  }

  {
    id = "ID_HELICOPTER_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() hasXInputDevice()
  }
  {
    id = "ID_HELICOPTER_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ActionGroup.HELICOPTER,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() hasXInputDevice()
  }
  {
    id = "ID_HELICOPTER_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON,
    onClick = @() controlsOperations.swapGamepadSticks(ActionGroup.HELICOPTER)
    showFunc = @() hasXInputDevice()
  }

  {
    id = "ID_HELICOPTER_MODE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "mouse_usage_helicopter"
    type = CONTROL_TYPE.SPINNER
    optionType = USEROPT_MOUSE_USAGE
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "mouse_usage_no_aim_helicopter"
    type = CONTROL_TYPE.SPINNER
    showFunc = @() hasFeature("SimulatorDifficulty") && (getMouseUsageMask() & AIR_MOUSE_USAGE.AIM)
    optionType = USEROPT_MOUSE_USAGE_NO_AIM
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "instructor_enabled_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_INSTRUCTOR_ENABLED
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "autotrim_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR]
    optionType = USEROPT_AUTOTRIM
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "ID_TOGGLE_INSTRUCTOR_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_CONTROL_MODE_HELICOPTER"
    filterShow = [ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR]
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_MOUSE_AIM_OVERRIDE_ROLL_HELICOPTER"
    filterShow = [ControlHelpersMode.EM_MOUSE_AIM]
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_MANEUVERABILITY_MODE_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_FBW_MODE_HELICOPTER"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }

  {
    id = "ID_HELICOPTER_AXES_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "helicopter_collective"
    type = CONTROL_TYPE.AXIS
    needShowInHelp = true
  }
  {
    id = "helicopter_holdThrottleForWEP"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(joyParams) joyParams.holdThrottleForWEP
    setValue = function(joyParams, objValue) {
      let old = joyParams.holdThrottleForWEP
      joyParams.holdThrottleForWEP = objValue
      if (objValue != old)
        commitControls()
    }
  }
  {
    id = "helicopter_buoyancy"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "helicopter_climb"
    type = CONTROL_TYPE.AXIS
    filterShow = [ ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR ]
  }
  {
    id = "helicopter_cyclic_roll"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    needShowInHelp = true
  }
  {
    id = "helicopter_cyclic_pitch"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "helicopter_pedals"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "helicopter_cyclic_roll_sens"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ ControlHelpersMode.EM_MOUSE_AIM ]
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_HELICOPTER_CYCLIC_ROLL_MULTIPLIER)
    setValue = @(_joyParams, objValue)
      set_option_multiplier(OPTION_HELICOPTER_CYCLIC_ROLL_MULTIPLIER, objValue / 100.0)
  }
  {
    id = "helicopter_cyclic_pitch_sens"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ ControlHelpersMode.EM_MOUSE_AIM ]
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_HELICOPTER_CYCLIC_PITCH_MULTIPLIER)
    setValue = @(_joyParams, objValue)
      set_option_multiplier(OPTION_HELICOPTER_CYCLIC_PITCH_MULTIPLIER, objValue / 100.0)
  }
  {
    id = "helicopter_pedals_sens"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ ControlHelpersMode.EM_MOUSE_AIM ]
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_HELICOPTER_PEDALS_MULTIPLIER)
    setValue = @(_joyParams, objValue)
      set_option_multiplier(OPTION_HELICOPTER_PEDALS_MULTIPLIER, objValue / 100.0)
  }

  {
    id = "ID_HELICOPTER_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_FIRE_MGUNS_HELICOPTER"
    conflictGroup = ConflictGroups.HELICOPTER_FIRE
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_CANNONS_HELICOPTER"
    conflictGroup = ConflictGroups.HELICOPTER_FIRE
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_ADDITIONAL_GUNS_HELICOPTER"
    conflictGroup = ConflictGroups.HELICOPTER_FIRE
    needShowInHelp = true
  }
  {
    id = "helicopter_fire"
    alternativeIds = [
      "ID_FIRE_MGUNS_HELICOPTER"
      "ID_FIRE_CANNONS_HELICOPTER"
      "ID_FIRE_ADDITIONAL_GUNS_HELICOPTER"
    ]
    type = CONTROL_TYPE.AXIS
  }
  {
    id = "ID_FIRE_PRIMARY_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_FIRE_SECONDARY_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_JETTISON_SECONDARY_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_BOMBS_HELICOPTER"
    needShowInHelp = true
    checkAssign = @() !hasMappedSecondaryWeaponSelector(unitTypes.HELICOPTER)
  }
  {
    id = "ID_BOMBS_SERIES_HELICOPTER"
    alternativeIds = [ "ID_BOMBS_HELICOPTER" ]
  }
  {
    id = "ID_ROCKETS_HELICOPTER"
    needShowInHelp = true
    checkAssign = @() !hasMappedSecondaryWeaponSelector(unitTypes.HELICOPTER)
  }
  {
    id = "ID_ROCKETS_SERIES_HELICOPTER"
    alternativeIds = [ "ID_ROCKETS_HELICOPTER" ]
  }
  {
    id = "ID_WEAPON_LOCK_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_AGM_LOCK_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_GUIDED_BOMBS_LOCK_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_EXIT_SHOOTING_CYCLE_MODE_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_SWITCH_SHOOTING_CYCLE_PRIMARY_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_SWITCH_SHOOTING_CYCLE_SECONDARY_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_RESIZE_SECONDARY_WEAPON_SERIES_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_BOMBS_AUTO_RELEASE_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SWITCH_SHOOTING_CYCLE_COUNTER_MEASURE_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_LASER_DESIGNATOR_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_AIR_RADAR_GUI_CONTROL_MODE_HELICOPTER"
    checkAssign = false
    needShowInHelp = false
  }
  {
    id = "ID_TOGGLE_AIR_RADAR_GUI_NAVIGATION_HELICOPTER"
    checkAssign = false
    needShowInHelp = false
    showFunc = @() hasXInputDevice()
  }
  {
    id = "ID_IRCM_SWITCH_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FLARES_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_COUNTERMEASURE_FLARES_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_COUNTERMEASURE_CHAFF_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_FLARES_SERIES_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_PERIODIC_FLARES_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_MLWS_FLARES_SLAVING_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_ATGM_HELICOPTER"
    needShowInHelp = true
    checkAssign = @() !hasMappedSecondaryWeaponSelector(unitTypes.HELICOPTER)
  }
  {
    id = "ID_AAM_HELICOPTER"
    needShowInHelp = true
    checkAssign = @() !hasMappedSecondaryWeaponSelector(unitTypes.HELICOPTER)
  }
  {
    id = "ID_GUIDED_BOMBS_HELICOPTER"
    needShowInHelp = true
    checkAssign = false
  }
  {
    id = "helicopter_atgm_aim_x"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.X
  }
  {
    id = "helicopter_atgm_aim_y"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "atgm_aim_sens_helicopter"
    optionType = USEROPT_ATGM_AIM_SENS_HELICOPTER
    type = CONTROL_TYPE.SLIDER
  }
  {
    id = "atgm_aim_zoom_sens_helicopter"
    optionType = USEROPT_ATGM_AIM_ZOOM_SENS_HELICOPTER
    type = CONTROL_TYPE.SLIDER
  }
  {
    id = "ID_CHANGE_SHOT_FREQ_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_CANNONS_AND_ROCKETS_BALLISTIC_COMPUTER_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_ROCKETS_BALLISTIC_COMPUTER_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_SWITCH_COCKPIT_SIGHT_MODE_HELICOPTER"
    checkAssign = false
  }

  {
    id = "ID_SENSORS_HELICOPTER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_SENSOR_SWITCH_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_TYPE_SWITCH_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_MODE_SWITCH_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_ACM_SWITCH_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_SCAN_PATTERN_SWITCH_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_STABILIZATION_SWITCH_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_DIRECTION_AXES_RESET_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_RANGE_SWITCH_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_TARGET_SWITCH_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_TARGET_LOCK_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "helicopter_sensor_cue_x"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "helicopter_sensor_cue_y"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "helicopter_sensor_cue_z"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }

  {
    id = "ID_HELICOPTER_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_TOGGLE_VIEW_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_LOCK_TARGETING_AT_POINT_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_UNLOCK_TARGETING_AT_POINT_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_FPS_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_TPS_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_VIRTUAL_FPS_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_CAMERA_VIRTUAL_TARGET_FPS_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_GUNNER_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_OPTICS_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_SEEKER_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TARGET_CAMERA_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_AIM_CAMERA_HELICOPTER"
    checkAssign = false
    condition = @() isPlatformSony || isPlatformXbox
  }
  {
    id = "helicopter_zoom"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "helicopter_camx"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    axisDirection = AxisDirection.X
  }
  {
    id = "helicopter_camy"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "invert_y_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_INVERTY_HELICOPTER
  }
  {
    id = "invert_y_helicopter_gunner"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_INVERTY_HELICOPTER_GUNNER
  }
  {
    id = "helicopter_mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    axisDirection = AxisDirection.X
  }
  {
    id = "helicopter_mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "aim_time_nonlinearity_helicopter"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_HELICOPTER)
    setValue = @(_joyParams, objValue)
      set_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_HELICOPTER, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_helicopter"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_HELICOPTER)
    setValue = @(_joyParams, objValue)
      set_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_HELICOPTER, objValue / 100.0)
  }
  {
    id = "mouse_z_helicopter"
    type = CONTROL_TYPE.MOUSE_AXIS
    axis_num = MouseAxis.MOUSE_SCROLL_HELICOPTER
    values = ["none", "helicopter_collective", "helicopter_climb", "helicopter_zoom"]
    onChangeValue = "onMouseWheel"
    showFunc = @() hasFeature("EnableMouse")
  }
  {
    id = "mouse_z_mult_helicopter"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_MOUSE_Z_HELICOPTER_MULT)
    setValue = @(_joyParams, objValue) set_option_multiplier(OPTION_MOUSE_Z_HELICOPTER_MULT, objValue / 100.0)
    showFunc = @() hasFeature("EnableMouse")
  }

  {
    id = "ID_HELICOPTER_INSTRUCTOR_HEADER"
    type = CONTROL_TYPE.SECTION
    filterShow = [ ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR ]
  }
  {
    id = "instructor_ground_avoidance_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR ]
    optionType = USEROPT_INSTRUCTOR_GROUND_AVOIDANCE
  }
  {
    id = "instructor_gear_control_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR ]
    optionType = USEROPT_INSTRUCTOR_GEAR_CONTROL
  }
  {
    id = "instructor_engine_control_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR ]
    optionType = USEROPT_INSTRUCTOR_ENGINE_CONTROL
  }
  {
    id = "instructor_simple_joy_helicopter"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ ControlHelpersMode.EM_INSTRUCTOR ]
    optionType = USEROPT_INSTRUCTOR_SIMPLE_JOY
  }

  {
    id = "ID_HELICOPTER_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_TOGGLE_ENGINE_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_EXTINGUISHER_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_GEAR_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FLAPS_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FLAPS_UP_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FLAPS_DOWN_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_AIR_BRAKE_HELICOPTER"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TOGGLE_COCKPIT_DOOR_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_COCKPIT_LIGHTS_HELICOPTER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_COLLIMATOR_HELICOPTER"
    checkAssign = false
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
  }
  {
    id = "ID_MFD_1_PAGE"
    checkAssign = false
  }
  {
    id = "ID_MFD_2_PAGE"
    checkAssign = false
  }
  {
    id = "ID_MFD_3_PAGE"
    checkAssign = false
  }
  {
    id = "ID_MFD_4_PAGE"
    checkAssign = false
  }
  {
    id = "ID_MFD_ZOOM"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_HMD_HELI"
    checkAssign = false
  }
  {
    id = "ID_INC_HMD_BRIGHTNESS_HELI"
    checkAssign = false
  }
  {
    id = "ID_DEC_HMD_BRIGHTNESS_HELI"
    checkAssign = false
  }
  {
    id = "ID_HELI_GUNNER_NIGHT_VISION"
    checkAssign = false
  }
  {
    id = "ID_HELICOPTER_KILLSTREAK_WHEEL_MENU"
    checkAssign = false
    showFunc = hasXInputDevice
  }
  {
    id = "ID_THERMAL_WHITE_IS_HOT_HELI"
    checkAssign = false
  }
  {
    id = "ID_REQUEST_DETECT_ALLY_HELI"
    checkAssign = false
  }
  {
    id = "helicopter_wheelmenu_x"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.X
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = @() (isPlatformSony || isPlatformXbox || isXInputDevice())
    checkAssign = @() isXInputDevice()
  }
  {
    id = "helicopter_wheelmenu_y"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.Y
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = @() (isPlatformSony || isPlatformXbox || isXInputDevice())
    checkAssign = @() isXInputDevice()
  }

  {
    id = "ID_HELICOPTER_JOYSTICK_HEADER"
    type = CONTROL_TYPE.SECTION
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
  }
  {
    id = "mouse_joystick_mode_helicopter"
    type = CONTROL_TYPE.SPINNER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    options = ["#options/mouse_joy_mode_simple", "#options/mouse_joy_mode_standard"]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(_joyParams) get_option_int(OPTION_HELICOPTER_MOUSE_JOYSTICK_MODE)
    setValue = @(_joyParams, objValue) set_option_int(OPTION_HELICOPTER_MOUSE_JOYSTICK_MODE, objValue)
  }
  {
    id = "mouse_joystick_sensitivity_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = function(_joyParams) {
      let gp = get_game_params()
      let minSens = gp?.minMouseJoystickSensitivity ?? 0.0
      let maxSens = gp?.maxMouseJoystickSensitivity  ?? 1.0
      return 100.0 * (get_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_SENSITIVITY) - minSens) / (maxSens - minSens)
    }
    setValue = function(_joyParams, objValue) {
      let gp = get_game_params()
      let minSens = gp?.minMouseJoystickSensitivity ?? 0.0
      let maxSens = gp?.maxMouseJoystickSensitivity  ?? 1.0
      set_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_SENSITIVITY, minSens + (objValue / 100.0) * (maxSens - minSens))
    }
  }
  {
    id = "mouse_joystick_deadzone_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = function(_joyParams) {
      let dz = get_game_params()?.maxMouseJoystickDeadZone ?? 1.0
      return 100.0 * get_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_DEADZONE) / dz
    }
    setValue = function(_joyParams, objValue) {
      let dz = get_game_params()?.maxMouseJoystickDeadZone ?? 1.0
      set_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_DEADZONE, (objValue / 100.0) * dz)
    }
  }

  {
    id = "mouse_joystick_screensize_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = function(_joyParams) {
      let gp = get_game_params()
      let minVal = gp?.minMouseJoystickScreenSize ?? 0.0
      let maxVal = gp?.maxMouseJoystickScreenSize ?? 1.0
      return 100.0 * (get_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENSIZE) - minVal) / (maxVal - minVal)
    }
    setValue = function(_joyParams, objValue) {
      let gp = get_game_params()
      let minVal = gp?.minMouseJoystickScreenSize ?? 0.0
      let maxVal = gp?.maxMouseJoystickScreenSize ?? 1.0
      set_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENSIZE, minVal + (objValue / 100.0) * (maxVal - minVal))
    }
  }
  {
    id = "mouse_joystick_screen_place_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENPLACE)
    setValue = @(_joyParams, objValue) set_option_multiplier(OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENPLACE, objValue / 100.0)
  }
  {
    id = "mouse_joystick_aileron_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
    value = function(_joyParams) {
      let maxVal = get_game_params()?.maxMouseJoystickAileron ?? 1.0
      return 100.0 * get_option_multiplier(OPTION_HELICOPTER_MOUSE_AILERON_AILERON_FACTOR) / maxVal
    }
    setValue = function(_joyParams, objValue) {
      let maxVal = get_game_params()?.maxMouseJoystickAileron ?? 1.0
      set_option_multiplier(OPTION_HELICOPTER_MOUSE_AILERON_AILERON_FACTOR, (objValue / 100.0) * maxVal)
    }
  }
  {
    id = "mouse_joystick_rudder_helicopter"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
    value = function(_joyParams) {
      let maxVal = get_game_params()?.maxMouseJoystickRudder ?? 1.0
      return 100.0 * get_option_multiplier(OPTION_HELICOPTER_MOUSE_AILERON_RUDDER_FACTOR) / maxVal
    }
    setValue = function(_joyParams, objValue) {
      let maxVal = get_game_params()?.maxMouseJoystickRudder ?? 1.0
      set_option_multiplier(OPTION_HELICOPTER_MOUSE_AILERON_RUDDER_FACTOR, (objValue / 100.0) * maxVal)
    }
  }
  {
    id = "helicopter_mouse_joystick_square"
    type = CONTROL_TYPE.SWITCH_BOX
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(_joyParams) get_option_mouse_joystick_square_helicopter()
    setValue = @(_joyParams, objValue) set_option_mouse_joystick_square_helicopter(objValue)
  }
  {
    id = "ID_HELICOPTER_CENTER_MOUSE_JOYSTICK"
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() is_mouse_available() && (getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK)
    checkAssign = false
  }

  {
    id = "ID_HELICOPTER_TRIM_CONTROL_HEADER"
    type = CONTROL_TYPE.SECTION
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
  }
  {
    id = "ID_HELICOPTER_TRIM"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_HELICOPTER_TRIM_RESET"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_HELICOPTER_TRIM_SAVE"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "helicopter_trim_elevator"
    type = CONTROL_TYPE.AXIS
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "helicopter_trim_ailerons"
    type = CONTROL_TYPE.AXIS
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "helicopter_trim_rudder"
    type = CONTROL_TYPE.AXIS
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  





]
