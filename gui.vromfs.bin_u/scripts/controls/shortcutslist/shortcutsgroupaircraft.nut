from "%scripts/dagui_natives.nut" import is_mouse_available
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import AIR_MOUSE_USAGE, MAX_CAMERA_SPEED, MIN_CAMERA_SPEED, CONTROL_TYPE, AxisDirection, ConflictGroups

let { isPC } = require("%sqstd/platform.nut")
let { ControlHelpersMode } = require("globalEnv")
let { get_game_params } = require("gameparams")
let { get_option_multiplier, set_option_multiplier, get_option_int, set_option_int,
  OPTION_MOUSE_JOYSTICK_DEADZONE, OPTION_MOUSE_JOYSTICK_SCREENSIZE,
  OPTION_MOUSE_JOYSTICK_SENSITIVITY, OPTION_MOUSE_JOYSTICK_SCREENPLACE,
  OPTION_MOUSE_AILERON_AILERON_FACTOR, OPTION_MOUSE_AILERON_RUDDER_FACTOR,
  OPTION_CAMERA_SPEED, OPTION_AIM_TIME_NONLINEARITY_AIR,
  OPTION_AIM_ACCELERATION_DELAY_AIR, OPTION_MOUSE_Z_MULT,
  OPTION_MOUSE_JOYSTICK_MODE
} = require("gameOptions")
let controlsOperations = require("%scripts/controls/controlsOperations.nut")
let { unitClassType } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isPlatformSony, isPlatformXbox, isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")
let { ActionGroup, hasXInputDevice, isXInputDevice } = require("controls")
let { getMouseUsageMask, checkOptionValue } = require("%scripts/controls/controlsUtils.nut")
let { USEROPT_MOUSE_USAGE, USEROPT_MOUSE_USAGE_NO_AIM, USEROPT_INSTRUCTOR_ENABLED,
  USEROPT_AUTOTRIM, USEROPT_AILERONS_MULTIPLIER, USEROPT_ELEVATOR_MULTIPLIER,
  USEROPT_RUDDER_MULTIPLIER, USEROPT_INVERTX, USEROPT_INVERTY, USEROPT_JOYFX, USEROPT_FORCE_GAIN,
  USEROPT_GUNNER_VIEW_SENSE, USEROPT_GUNNER_VIEW_ZOOM_SENS, USEROPT_GUNNER_INVERTY,
  USEROPT_INVERTCAMERAY, USEROPT_INSTRUCTOR_GROUND_AVOIDANCE, USEROPT_INSTRUCTOR_GEAR_CONTROL,
  USEROPT_INSTRUCTOR_FLAPS_CONTROL, USEROPT_INSTRUCTOR_ENGINE_CONTROL, USEROPT_INSTRUCTOR_SIMPLE_JOY
} = require("%scripts/options/optionsExtNames.nut")
let { hasMappedSecondaryWeaponSelector } = require("%scripts/controls/shortcutsUtils.nut")
let { commitControls } = require("%scripts/controls/controlsManager.nut")
let { set_option_mouse_joystick_square, get_option_mouse_joystick_square } = require("controlsOptions")

let isMouseAimSelected = @() (getMouseUsageMask() & AIR_MOUSE_USAGE.AIM) != 0
let needFullGunnerSettings = @() isPlatformSony || isPlatformXbox
  || isPlatformSteamDeck || !isMouseAimSelected()

return [
  {
    id = "ID_PLANE_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitTypes = [ unitTypes.AIRCRAFT ]
    unitClassTypes = [
      unitClassType.FIGHTER
      unitClassType.BOMBER
      unitClassType.ASSAULT
    ]
    isHelpersVisible = true
    needShowInHelp = true
  }

  {
    id = "ID_PLANE_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() hasXInputDevice()
  }
  {
    id = "ID_PLANE_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ActionGroup.AIRPLANE,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() hasXInputDevice()
  }
  {
    id = "ID_PLANE_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(ActionGroup.AIRPLANE)
    showFunc = @() hasXInputDevice()
  }

  {
    id = "ID_PLANE_MODE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "mouse_usage"
    type = CONTROL_TYPE.SPINNER
    optionType = USEROPT_MOUSE_USAGE
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "mouse_usage_no_aim"
    type = CONTROL_TYPE.SPINNER
    showFunc = @() hasFeature("SimulatorDifficulty") && isMouseAimSelected()
    optionType = USEROPT_MOUSE_USAGE_NO_AIM
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "instructor_enabled"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_INSTRUCTOR_ENABLED
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "autotrim"
    type = CONTROL_TYPE.SWITCH_BOX
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR]
    optionType = USEROPT_AUTOTRIM
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "ID_TOGGLE_INSTRUCTOR"
    checkAssign = false
  }
  {
    id = "ID_CONTROL_MODE"
    filterShow = [ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR]
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_MANEUVERABILITY_MODE"
    checkAssign = false
  }
  {
    id = "ID_FBW_MODE"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
  }

  {
    id = "ID_PLANE_AXES_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "mouse_z"
    type = CONTROL_TYPE.MOUSE_AXIS
    axis_num = MouseAxis.MOUSE_SCROLL
    values = ["none", "throttle", "zoom",  "camy",  ]
    onChangeValue = "onMouseWheel"
    showFunc = @() hasFeature("EnableMouse")
  }
  {
    id = "mouse_z_mult"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_MOUSE_Z_MULT)
    setValue = @(_joyParams, objValue) set_option_multiplier(OPTION_MOUSE_Z_MULT, objValue / 100.0)
    showFunc = @() hasFeature("EnableMouse")
  }
  {
    id = "throttle"
    type = CONTROL_TYPE.AXIS
    needShowInHelp = true
  }
  {
    id = "holdThrottleForWEP"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(joyParams) joyParams.holdThrottleForWEP
    setValue = function(joyParams, objValue) {
      let old  = joyParams.holdThrottleForWEP
      joyParams.holdThrottleForWEP = objValue
      if (objValue != old)
        commitControls()
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
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    optionType = USEROPT_AILERONS_MULTIPLIER
  }
  {
    id = "pitch_sens"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    optionType = USEROPT_ELEVATOR_MULTIPLIER
  }
  {
    id = "yaw_sens"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    optionType = USEROPT_RUDDER_MULTIPLIER
  }
  {
    id = "vtol"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "buoyancy"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "climb"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "invert_y"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_INVERTY
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "invert_x"
    type = CONTROL_TYPE.SWITCH_BOX
    filterHide = [ControlHelpersMode.EM_INSTRUCTOR, ControlHelpersMode.EM_REALISTIC, ControlHelpersMode.EM_FULL_REAL]
    optionType = USEROPT_INVERTX
    showFunc = @() checkOptionValue(USEROPT_INVERTY, true)
  }
  {
    id = "joyFX"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_JOYFX
    showFunc = @() isPC
  }
  {
    id = "multiplier_force_gain"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    optionType = USEROPT_FORCE_GAIN
  }

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
    id = "sweep"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "ID_SWEEP_MODE"
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
    id = "ID_AIR_REVERSE"
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
    filterShow = [ControlHelpersMode.EM_REALISTIC, ControlHelpersMode.EM_FULL_REAL]
  }
  {
    id = "brake_right"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    filterShow = [ControlHelpersMode.EM_REALISTIC, ControlHelpersMode.EM_FULL_REAL]
  }
  {
    id = "ID_CHUTE"
    checkAssign = false
  }

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
    conflictGroup = ConflictGroups.PLANE_FIRE
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_SECONDARY"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_OPEN_VISUAL_WEAPON_SELECTOR"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_JETTISON_SECONDARY"
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
    checkAssign = @() !hasMappedSecondaryWeaponSelector(unitTypes.AIRCRAFT)
  }
  {
    id = "ID_BOMBS_SERIES"
    alternativeIds = [ "ID_BOMBS" ]
  }
  {
    id = "ID_ROCKETS"
    needShowInHelp = true
    checkAssign = @() !hasMappedSecondaryWeaponSelector(unitTypes.AIRCRAFT)
  }
  {
    id = "ID_ROCKETS_SERIES"
    alternativeIds = [ "ID_ROCKETS" ]
  }
  {
    id = "ID_AGM"
    needShowInHelp = true
    checkAssign = @() !hasMappedSecondaryWeaponSelector(unitTypes.AIRCRAFT)
  }
  {
    id = "ID_AAM"
    needShowInHelp = true
    checkAssign = @() !hasMappedSecondaryWeaponSelector(unitTypes.AIRCRAFT)
  }
  {
    id = "ID_GUIDED_BOMBS"
    needShowInHelp = true
    checkAssign = @() !hasMappedSecondaryWeaponSelector(unitTypes.AIRCRAFT)
  }
  {
    id = "ID_FUEL_TANKS"
    checkAssign = false
  }
  {
    id = "ID_AIR_DROP"
    showFunc = @() hasFeature("Payload")
    checkAssign = false
  }
  {
    id = "ID_WEAPON_LOCK"
    checkAssign = false
  }
  {
    id = "ID_AGM_LOCK"
    checkAssign = false
  }
  {
    id = "ID_GUIDED_BOMBS_LOCK"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_EXIT_SHOOTING_CYCLE_MODE"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SWITCH_SHOOTING_CYCLE_PRIMARY"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SWITCH_SHOOTING_CYCLE_SECONDARY"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_RESIZE_SECONDARY_WEAPON_SERIES"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TOGGLE_BOMBS_AUTO_RELEASE"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SWITCH_SHOOTING_CYCLE_COUNTER_MEASURE"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_IRCM_SWITCH_PLANE"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FLARES"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_COUNTERMEASURES_FLARES"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_COUNTERMEASURES_CHAFF"
    checkAssign = false
    needShowInHelp = true
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
    id = "ID_TOGGLE_FUEL_DUMPING"
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
    id = "ID_TOGGLE_LASER_DESIGNATOR"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TOGGLE_AIR_RADAR_GUI_CONTROL_MODE"
    checkAssign = false
    needShowInHelp = false
  }
  {
    id = "ID_TOGGLE_AIR_RADAR_GUI_NAVIGATION"
    checkAssign = false
    needShowInHelp = false
    showFunc = @() hasXInputDevice()
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
  }
  {
    id = "ID_TOGGLE_ROCKETS_BALLISTIC_COMPUTER"
    checkAssign = false
  }
  {
    id = "ID_SWITCH_COCKPIT_SIGHT_MODE"
    checkAssign = false
  }
  {
    id = "ID_SWITCH_REGISTERED_BOMB_TARGETING_POINT"
    checkAssign = false
  }
  {
    id = "ID_LOCK_TARGETING_AT_POINT"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_UNLOCK_TARGETING_AT_POINT"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_LOCK_TARGETING"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_UNLOCK_TARGETING"
    checkAssign = false
    needShowInHelp = true
  }

  {
    id = "ID_SENSORS_HEADER"
    type = CONTROL_TYPE.SECTION
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
    id = "sensor_cue_x"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "sensor_cue_y"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "sensor_cue_z"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "ID_SENSOR_SWITCH"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_TYPE_SWITCH"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_MODE_SWITCH"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_ACM_SWITCH"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_SCAN_PATTERN_SWITCH"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_STABILIZATION_SWITCH"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_DIRECTION_AXES_RESET"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_RANGE_SWITCH"
    checkAssign = false
    needShowInHelp = true
  }

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
    optionType = USEROPT_GUNNER_VIEW_SENSE
    showFunc = needFullGunnerSettings
  }
  {
    id = "gunner_view_zoom_sens"
    type = CONTROL_TYPE.SLIDER
    optionType = USEROPT_GUNNER_VIEW_ZOOM_SENS
    showFunc = @() needFullGunnerSettings()
  }
  {
    id = "gunner_joy_speed"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * (get_option_multiplier(OPTION_CAMERA_SPEED) - MIN_CAMERA_SPEED) / (MAX_CAMERA_SPEED - MIN_CAMERA_SPEED)
    setValue = @(_joyParams, objValue) set_option_multiplier(OPTION_CAMERA_SPEED, MIN_CAMERA_SPEED + (objValue / 100.0) * (MAX_CAMERA_SPEED - MIN_CAMERA_SPEED))
    showFunc = needFullGunnerSettings
  }
  {
    id = "invert_y_gunner"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_GUNNER_INVERTY
  }

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
    id = "ID_CAMERA_OPTICS"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_SEEKER"
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
    condition = @() isPlatformSony || isPlatformXbox
  }
  {
    id = "target_camera"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    condition = @() isPlatformSony || isPlatformXbox
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
    optionType = USEROPT_INVERTCAMERAY
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
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
  }
  {
    id = "ID_MFD_1_PAGE_PLANE"
    checkAssign = false
  }
  {
    id = "ID_MFD_2_PAGE_PLANE"
    checkAssign = false
  }
  {
    id = "ID_MFD_3_PAGE_PLANE"
    checkAssign = false
  }
  {
    id = "ID_MFD_ZOOM_PLANE"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_HMD"
    checkAssign = false
  }
  {
    id = "ID_INC_HMD_BRIGHTNESS"
    checkAssign = false
  }
  {
    id = "ID_DEC_HMD_BRIGHTNESS"
    checkAssign = false
  }
  {
    id = "ID_PLANE_NIGHT_VISION"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_PLANE_SMOKE_SCREEN_GENERATOR"
    checkAssign = false
  }
  {
    id = "ID_PLANE_KILLSTREAK_WHEEL_MENU"
    checkAssign = false
    showFunc = hasXInputDevice
  }
  {
    id = "wheelmenu_x"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.X
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = hasXInputDevice
    checkAssign = @() isXInputDevice()
  }
  {
    id = "wheelmenu_y"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.Y
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = hasXInputDevice
    checkAssign = @() isXInputDevice()
  }

  {
    id = "ID_INSTRUCTOR_HEADER"
    type = CONTROL_TYPE.SECTION
    filterShow = [ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR]
  }
  {
    id = "instructor_ground_avoidance"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR]
    optionType = USEROPT_INSTRUCTOR_GROUND_AVOIDANCE
  }
  {
    id = "instructor_gear_control"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR]
    optionType = USEROPT_INSTRUCTOR_GEAR_CONTROL
  }
  {
    id = "instructor_flaps_control"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR]
    optionType = USEROPT_INSTRUCTOR_FLAPS_CONTROL
  }
  {
    id = "instructor_engine_control"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR]
    optionType = USEROPT_INSTRUCTOR_ENGINE_CONTROL
  }
  {
    id = "instructor_simple_joy"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ControlHelpersMode.EM_INSTRUCTOR]
    optionType = USEROPT_INSTRUCTOR_SIMPLE_JOY
  }

  {
    id = "ID_PLANE_MOUSE_AIM_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    filterHide = [ControlHelpersMode.EM_INSTRUCTOR, ControlHelpersMode.EM_REALISTIC, ControlHelpersMode.EM_FULL_REAL]
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
  }
  {
    id = "mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    filterHide = [ControlHelpersMode.EM_INSTRUCTOR, ControlHelpersMode.EM_REALISTIC, ControlHelpersMode.EM_FULL_REAL]
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
  }
  {
    id = "aim_time_nonlinearity_air"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_AIR)
    setValue = @(_joyParams, objValue) set_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_AIR, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_air"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_AIR)
    setValue = @(_joyParams, objValue) set_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_AIR, objValue / 100.0)
  }

  {
    id = "ID_PLANE_JOYSTICK_HEADER"
    type = CONTROL_TYPE.SECTION
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
  }
  {
    id = "mouse_joystick_mode"
    type = CONTROL_TYPE.SPINNER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    options = ["#options/mouse_joy_mode_simple", "#options/mouse_joy_mode_standard"]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(_joyParams) get_option_int(OPTION_MOUSE_JOYSTICK_MODE)
    setValue = @(_joyParams, objValue) set_option_int(OPTION_MOUSE_JOYSTICK_MODE, objValue)
  }
  {
    id = "mouse_joystick_sensitivity"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = function(_joyParams) {
      let gp = get_game_params()
      let minSens = gp?.minMouseJoystickSensitivity ?? 0.0
      let maxSens = gp?.maxMouseJoystickSensitivity ?? 1.0
      return 100.0 * (get_option_multiplier(OPTION_MOUSE_JOYSTICK_SENSITIVITY) - minSens) / (maxSens - minSens)
    }
    setValue = function(_joyParams, objValue) {
      let gp = get_game_params()
      let minSens = gp?.minMouseJoystickSensitivity ?? 0.0
      let maxSens = gp?.maxMouseJoystickSensitivity ?? 1.0
      set_option_multiplier(OPTION_MOUSE_JOYSTICK_SENSITIVITY, minSens + (objValue / 100.0) * (maxSens - minSens))
    }
  }
  {
    id = "mouse_joystick_deadzone"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = function(_joyParams) {
      let dz = get_game_params()?.maxMouseJoystickDeadZone ?? 1.0
      return 100.0 * get_option_multiplier(OPTION_MOUSE_JOYSTICK_DEADZONE) / dz
    }
    setValue = function(_joyParams, objValue) {
      let dz = get_game_params()?.maxMouseJoystickDeadZone ?? 1.0
      set_option_multiplier(OPTION_MOUSE_JOYSTICK_DEADZONE, (objValue / 100.0) * dz)
    }
  }
  {
    id = "mouse_joystick_screensize"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = function(_joyParams) {
      let gp = get_game_params()
      let minVal = gp?.minMouseJoystickScreenSize ?? 0.0
      let maxVal = gp?.maxMouseJoystickScreenSize ?? 1.0
      return 100.0 * (get_option_multiplier(OPTION_MOUSE_JOYSTICK_SCREENSIZE) - minVal) / (maxVal - minVal)
    }
    setValue = function(_joyParams, objValue) {
      let gp = get_game_params()
      let minVal = gp?.minMouseJoystickScreenSize ?? 0.0
      let maxVal = gp?.maxMouseJoystickScreenSize ?? 1.0
      set_option_multiplier(OPTION_MOUSE_JOYSTICK_SCREENSIZE, minVal + (objValue / 100.0) * (maxVal - minVal))
    }
  }
  {
    id = "mouse_joystick_screen_place"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_MOUSE_JOYSTICK_SCREENPLACE)
    setValue = @(_joyParams, objValue) set_option_multiplier(OPTION_MOUSE_JOYSTICK_SCREENPLACE, objValue / 100.0)
  }
  {
    id = "mouse_joystick_aileron"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
    value = function(_joyParams) {
      let maxVal = get_game_params()?.maxMouseJoystickAileron ?? 1.0
      return 100.0 * get_option_multiplier(OPTION_MOUSE_AILERON_AILERON_FACTOR) / maxVal
    }
    setValue = function(_joyParams, objValue) {
      let maxVal = get_game_params()?.maxMouseJoystickAileron ?? 1.0
      set_option_multiplier(OPTION_MOUSE_AILERON_AILERON_FACTOR, (objValue / 100.0) * maxVal)
    }
  }
  {
    id = "mouse_joystick_rudder"
    type = CONTROL_TYPE.SLIDER
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
    value = function(_joyParams) {
      let maxVal = get_game_params()?.maxMouseJoystickRudder ?? 1.0
      return 100.0 * get_option_multiplier(OPTION_MOUSE_AILERON_RUDDER_FACTOR) / maxVal
    }
    setValue = function(_joyParams, objValue) {
      let maxVal = get_game_params()?.maxMouseJoystickRudder ?? 1.0
      set_option_multiplier(OPTION_MOUSE_AILERON_RUDDER_FACTOR, (objValue / 100.0) * maxVal)
    }
  }
  {
    id = "mouse_joystick_square"
    type = CONTROL_TYPE.SWITCH_BOX
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
    value = @(_joyParams) get_option_mouse_joystick_square()
    setValue = @(_joyParams, objValue) set_option_mouse_joystick_square(objValue)
  }
  {
    id = "ID_CENTER_MOUSE_JOYSTICK"
    filterHide = [ControlHelpersMode.EM_MOUSE_AIM]
    showFunc = @() is_mouse_available() && (getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK)
    checkAssign = false
  }

  {
    id = "ID_TRIM_CONTROL_HEADER"
    type = CONTROL_TYPE.SECTION
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
  }
  {
    id = "ID_TRIM"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TRIM_RESET"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TRIM_SAVE"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "trim_elevator"
    type = CONTROL_TYPE.AXIS
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "trim_ailerons"
    type = CONTROL_TYPE.AXIS
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "trim_rudder"
    type = CONTROL_TYPE.AXIS
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }

  {
    id = "ID_MANUAL_ENGINE_CONTROL_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_COMPLEX_ENGINE"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_ENGINE"
    checkAssign = false
  }
  {
    id = "mixture"
    type = CONTROL_TYPE.AXIS
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "prop_pitch"
    type = CONTROL_TYPE.AXIS
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_PROP_PITCH_AUTO"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "radiator"
    type = CONTROL_TYPE.AXIS
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "oil_radiator"
    type = CONTROL_TYPE.AXIS
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_RADIATOR_AUTO"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "turbo_charger"
    type = CONTROL_TYPE.AXIS
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_AUTO_TURBO_CHARGER"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_SUPERCHARGER"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_MAGNETO_INCREASE"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_MAGNETO_DECREASE"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_PROP_FEATHERING"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_EXTINGUISHER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_1_ENGINE_CONTROL"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_2_ENGINE_CONTROL"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_3_ENGINE_CONTROL"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_4_ENGINE_CONTROL"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_5_ENGINE_CONTROL"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_6_ENGINE_CONTROL"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  {
    id = "ID_ENABLE_ALL_ENGINE_CONTROL"
    filterShow = [ControlHelpersMode.EM_FULL_REAL]
    checkAssign = false
  }
  





]
