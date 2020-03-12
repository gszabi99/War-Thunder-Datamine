local controlsOperations = require("scripts/controls/controlsOperations.nut")

return [
  {
    id = "ID_TANK_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitType = ::g_unit_type.TANK
    showFunc = @() ::has_feature("Tanks")
    needShowInHelp = true
  }
//-------------------------------------------------------
  {
    id = "ID_TANK_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() ::is_xinput_device()
  }
  {
    id = "ID_TANK_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON,
    onClick = @() controlsOperations.swapGamepadSticks(
      ctrlGroups.TANK,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() ::is_xinput_device()
  }
  {
    id = "ID_TANK_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON,
    onClick = @() controlsOperations.swapGamepadSticks(
      ctrlGroups.TANK
    )
    showFunc = @() ::is_xinput_device()
  }
//-------------------------------------------------------
  {
    id = "ID_TANK_MOVE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "gm_automatic_transmission"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_AUTOMATIC_TRANSMISSION_TANK
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "ID_TOGGLE_TRANSMISSION_MODE_GM"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "gm_throttle"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.TANK
    axisDirection = AxisDirection.Y
    needShowInHelp = true
  }
  {
    id = "gm_steering"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.TANK
    axisDirection = AxisDirection.X
    needShowInHelp = true
  }
  {
    id = "ID_SHORT_BRAKE"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "gm_brake_left"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "gm_brake_right"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_TRANS_GEAR_UP"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TRANS_GEAR_DOWN"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TRANS_GEAR_NEUTRAL"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    showFunc = @() ::g_controls_utils.checkOptionValue(::USEROPT_AUTOMATIC_TRANSMISSION_TANK, false)
  }
  {
    id = "ID_ENABLE_GM_DIRECTION_DRIVING"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_ENABLE_GM_HULL_AIMING"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_GM_ENGINE"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_TANK_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_FIRE_GM"
    checkGroup = ctrlGroups.TANK
    conflictGroup = ConflictGroups.TANK_FIRE
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_GM_SECONDARY_GUN"
    checkGroup = ctrlGroups.TANK
    conflictGroup = ConflictGroups.TANK_FIRE
    checkAssign = false
  }
  {
    id = "ID_FIRE_GM_MACHINE_GUN"
    checkGroup = ctrlGroups.TANK
    conflictGroup = ConflictGroups.TANK_FIRE
    checkAssign = false
  }
  {
    id = "ID_FIRE_GM_SPECIAL_GUN"
    checkGroup = ctrlGroups.TANK
  }
  {
    id = "ID_SELECT_GM_GUN_RESET"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_SELECT_GM_GUN_PRIMARY"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_SELECT_GM_GUN_SECONDARY"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_SELECT_GM_GUN_MACHINEGUN"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_SMOKE_SCREEN"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_SMOKE_SCREEN_GENERATOR"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CHANGE_SHOT_FREQ"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_NEXT_BULLET_TYPE"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_WEAPON_LOCK_TANK"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_SWITCH_TANK"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_MODE_SWITCH_TANK"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_SENSOR_SCAN_PATTERN_SWITCH_TANK"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_SENSOR_RANGE_SWITCH_TANK"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_SENSOR_TARGET_SWITCH_TANK"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_TARGET_LOCK_TANK"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TANK_NIGHT_VISION"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_IR_PROJECTOR"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_THERMAL_WHITE_IS_HOT"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_TANK_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_ZOOM_HOLD_GM"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_VIEW_GM"
    checkGroup = ctrlGroups.TANK
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_DRIVER"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_CAMERA_BINOCULARS"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_ENABLE_GUN_STABILIZER_GM"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_TARGETING_HOLD_GM"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "gm_zoom"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "gm_camx"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.TANK
    reqInMouseAim = false
    axisDirection = AxisDirection.X
  }
  {
    id = "gm_camy"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.TANK
    reqInMouseAim = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "invert_y_tank"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTY_TANK
  }
  {
    id = "gm_mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.TANK
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
    needShowInHelp = true
  }
  {
    id = "gm_mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.TANK
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
    needShowInHelp = true
  }
  {
    id = "aim_time_nonlinearity_tank"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_TANK)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_TANK, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_tank"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_TANK)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_TANK, objValue / 100.0)
  }
  {
    id = "mouse_z_ground"
    type = CONTROL_TYPE.MOUSE_AXIS
    axis_num = MouseAxis.MOUSE_SCROLL_TANK
    values = ["none", "gm_zoom", "gm_sight_distance"]
    onChangeValue = "onMouseWheel"
    showFunc = @() ::has_feature("EnableMouse") && ::has_feature("Tanks")
  }
  {
    id = "mouse_z_mult_ground"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_MOUSE_Z_TANK_MULT)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_Z_TANK_MULT, objValue / 100.0)
    showFunc = @() ::has_feature("EnableMouse") && ::has_feature("Tanks")
  }
//-------------------------------------------------------
  {
    id = "ID_TANK_SUSPENSION_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_SUSPENSION_PITCH_UP"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_PITCH_DOWN"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_ROLL_UP"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_ROLL_DOWN"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_CLEARANCE_UP"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_CLEARANCE_DOWN"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_RESET"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
//-------------------------------------------------------
  {
    id = "ID_TANK_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_REPAIR_TANK"
    checkGroup = ctrlGroups.TANK
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_1"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_2"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_3"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_4"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_5"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    showFunc = @() ::is_platform_pc && !::is_xinput_device()
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_6"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_7"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_8"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_9"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_10"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_12"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_KILLSTREAK_WHEEL_MENU"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    showFunc = @() !(::is_platform_pc && !::is_xinput_device())
  }
  {
    id = "ID_SCOUT"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    showFunc = @() ::has_feature("ActiveScouting")
  }
  {
    id = "ID_RANGEFINDER"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_GM_CROSSHAIR_LIGHTING"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
  {
    id = "ID_RELOAD_USER_SIGHT_GM"
    checkGroup = ctrlGroups.TANK
    checkAssign = false
    showFunc = @() ::can_add_tank_alt_crosshair() && ::has_feature("TankAltCrosshair")
  }
  {
    id = "gm_sight_distance"
    type = CONTROL_TYPE.AXIS
    def_relative = true
    isAbsOnlyWhenRealAxis = true
    checkGroup = ctrlGroups.TANK
    checkAssign = false
  }
]
