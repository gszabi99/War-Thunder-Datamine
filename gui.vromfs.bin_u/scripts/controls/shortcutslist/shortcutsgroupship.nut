local controlsOperations = require("scripts/controls/controlsOperations.nut")

return [
  {
    id = "ID_SHIP_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitType = ::g_unit_type.SHIP
    needShowInHelp = true
  }
//-------------------------------------------------------
  {
    id = "ID_SHIP_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() ::is_xinput_device()
  }
  {
    id = "ID_SHIP_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ctrlGroups.SHIP,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() ::is_xinput_device()
  }
  {
    id = "ID_SHIP_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON,
    onClick = @() controlsOperations.swapGamepadSticks(ctrlGroups.SHIP)
    showFunc = @() ::is_xinput_device()
  }
//-------------------------------------------------------
  {
    id = "ID_SHIP_MOVE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ship_seperated_engine_control"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_SEPERATED_ENGINE_CONTROL_SHIP
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "ship_main_engine"
    type = CONTROL_TYPE.AXIS
    def_relative = true
    checkGroup = ctrlGroups.SHIP
    showFunc = @() ::g_controls_utils.checkOptionValue(::USEROPT_SEPERATED_ENGINE_CONTROL_SHIP, false)
    axisDirection = AxisDirection.Y
    needShowInHelp = true
  }
  {
    id = "ship_port_engine"
    type = CONTROL_TYPE.AXIS
    def_relative = true
    checkGroup = ctrlGroups.SHIP
    showFunc = @() ::g_controls_utils.checkOptionValue(::USEROPT_SEPERATED_ENGINE_CONTROL_SHIP, true)
    checkAssign = false
  }
  {
    id = "ship_star_engine"
    type = CONTROL_TYPE.AXIS
    def_relative = true
    checkGroup = ctrlGroups.SHIP
    showFunc = @() ::g_controls_utils.checkOptionValue(::USEROPT_SEPERATED_ENGINE_CONTROL_SHIP, true)
    checkAssign = false
  }
  {
    id = "ship_steering"
    type = CONTROL_TYPE.AXIS,
    checkGroup = ctrlGroups.SHIP,
    axisDirection = AxisDirection.X
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_FULL_STOP"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_SHIP_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_SHIP_WEAPON_ALL"
    checkGroup = ctrlGroups.SHIP
    needShowInHelp = true
  }
  {
    id = "selectWheelShipEnable"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_WHEEL_CONTROL_SHIP
    onChangeValue = "doControlsGroupChangeDelayed"
    showFunc = @() (::is_xinput_device() || ::is_ps4_or_xbox)
  }
  {
    id = "ID_SHIP_SELECTWEAPON_WHEEL_MENU"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    showFunc = @() ::g_controls_utils.checkOptionValue(::USEROPT_WHEEL_CONTROL_SHIP, true)
      && (::is_xinput_device() || ::is_ps4_or_xbox)
  }
  {
    id = "ID_SHIP_WEAPON_PRIMARY"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    showFunc = @() ::g_controls_utils.checkOptionValue(::USEROPT_WHEEL_CONTROL_SHIP, false)
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_SECONDARY"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    showFunc = @() ::g_controls_utils.checkOptionValue(::USEROPT_WHEEL_CONTROL_SHIP, false)
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_MACHINEGUN"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    showFunc = @() ::g_controls_utils.checkOptionValue(::USEROPT_WHEEL_CONTROL_SHIP, false)
    needShowInHelp = true
  }
  {
    id = "ID_SINGLE_SHOT_SHIP"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "singleShotByTurret"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_SINGLE_SHOT_BY_TURRET
  }
  {
    id = "ID_SHIP_WEAPON_TORPEDOES"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_DEPTH_CHARGE"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_MINE"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_MORTAR"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_ROCKETS"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_SMOKE_GRENADE"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_SMOKE_SCREEN_GENERATOR"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_TORPEDO_SIGHT"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_TOGGLE_GUNNERS"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "ID_SHIP_SELECT_TARGET_AI_PRIM"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "ID_SHIP_SELECT_TARGET_AI_SEC"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "ID_SHIP_SELECT_TARGET_AI_MGUN"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "ID_SHIP_NEXT_BULLET_TYPE"
     checkGroup = ctrlGroups.SHIP
     checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_SHIP_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_TOGGLE_VIEW_SHIP"
    checkGroup = ctrlGroups.SHIP
    needShowInHelp = true
  }
  {
    id = "ID_TARGETING_HOLD_SHIP"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "ID_LOCK_TARGETING_AT_POINT_SHIP"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "ID_SENSOR_SWITCH_SHIP"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
/*
  {
    id = "ID_SENSOR_MODE_SWITCH_SHIP"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "ID_SENSOR_SCAN_PATTERN_SWITCH_SHIP"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
*/
  {
    id = "ID_SENSOR_RANGE_SWITCH_SHIP"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "ID_SENSOR_TARGET_SWITCH_SHIP"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_TARGET_LOCK_SHIP"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ship_zoom"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "ship_camx"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SHIP
    reqInMouseAim = false
    axisDirection = AxisDirection.X
  }
  {
    id = "ship_camy"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SHIP
    reqInMouseAim = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "invert_y_ship"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTY_SHIP
  }
  {
    id = "ship_mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SHIP
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
  }
  {
    id = "ship_mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SHIP
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
  }
  {
    id = "aim_time_nonlinearity_ship"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SHIP)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SHIP, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_ship"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SHIP)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SHIP, objValue / 100.0)
  }
  {
    id = "mouse_z_ship"
    type = CONTROL_TYPE.MOUSE_AXIS
    axis_num = MouseAxis.MOUSE_SCROLL_SHIP
    values = ["none", "ship_sight_distance", "ship_main_engine", "ship_zoom"]
    onChangeValue = "onMouseWheel"
    showFunc = @() ::has_feature("EnableMouse") && ::has_feature("Ships")
  }
  {
    id = "mouse_z_mult_ship"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_MOUSE_Z_SHIP_MULT)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_Z_SHIP_MULT, objValue / 100.0)
    showFunc = @() ::has_feature("EnableMouse") && ::has_feature("Ships")
  }
//-------------------------------------------------------
  {
    id = "ID_SHIP_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_1"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_2"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_3"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_4"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_5"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_KILLSTREAK_WHEEL_MENU"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    showFunc = @() !(::is_platform_pc && !::is_xinput_device())
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_6"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_11"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_REPAIR_BREACHES"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_10"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_LOCK_SHOOT_DISTANCE"
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "ship_sight_distance"
    type = CONTROL_TYPE.AXIS
    def_relative = true
    isAbsOnlyWhenRealAxis = true
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
  {
    id = "ship_shoot_direction"
    type = CONTROL_TYPE.AXIS
    def_relative = true
    isAbsOnlyWhenRealAxis = true
    checkGroup = ctrlGroups.SHIP
    checkAssign = false
  }
]