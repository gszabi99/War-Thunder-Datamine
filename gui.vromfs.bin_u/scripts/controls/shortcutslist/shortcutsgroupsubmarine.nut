local controlsOperations = require("scripts/controls/controlsOperations.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

return [
  {
    id = "ID_SUBMARINE_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitType = unitTypes.SHIP
    unitTag = "submarine"
    showFunc = @() ::has_feature("SpecialShips") || ::is_submarine(::get_player_cur_unit())
    needShowInHelp = true
  }
//-------------------------------------------------------
  {
    id = "ID_SUBMARINE_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() ::have_xinput_device()
  }
  {
    id = "ID_SUBMARINE_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ctrlGroups.SUBMARINE,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() ::have_xinput_device()
  }
  {
    id = "ID_SUBMARINE_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ctrlGroups.SUBMARINE
    )
    showFunc = @() ::have_xinput_device()
  }
//-------------------------------------------------------
  {
    id = "ID_SUBMARINE_MOVE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "submarine_main_engine"
    type = CONTROL_TYPE.AXIS
    def_relative = true
    checkGroup = ctrlGroups.SUBMARINE
    axisDirection = AxisDirection.Y
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "submarine_steering"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUBMARINE
    axisDirection = AxisDirection.X
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "submarine_depth"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUBMARINE
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_FULL_STOP"
    checkGroup = ctrlGroups.SUBMARINE
    checkAssign = false
    needShowInHelp = true
  }
//-------------------------------------------------------
  {
    id = "ID_SUBMARINE_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
    needShowInHelp = true
  }
  {
    id = "ID_TOGGLE_VIEW_SUBMARINE"
    checkGroup = ctrlGroups.SUBMARINE
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_WEAPON_TORPEDOES"
    checkGroup = ctrlGroups.SUBMARINE
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_SWITCH_ACTIVE_SONAR"
    checkGroup = ctrlGroups.SUBMARINE
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR"
    checkGroup = ctrlGroups.SUBMARINE
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_WEAPON_TOGGLE_SELF_HOMMING"
    checkGroup = ctrlGroups.SUBMARINE
    checkAssign = false
    needShowInHelp = true
  }
//-------------------------------------------------------
  {
    id = "ID_SUBMARINE_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "submarine_zoom"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUBMARINE
    checkAssign = false
  }
  {
    id = "submarine_camx"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUBMARINE
    reqInMouseAim = false
    axisDirection = AxisDirection.X
  }
  {
    id = "submarine_camy"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUBMARINE
    reqInMouseAim = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "invert_y_submarine"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTY_SUBMARINE
  }
  {
    id = "submarine_mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUBMARINE
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
  }
  {
    id = "submarine_mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUBMARINE
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
  }
  {
    id = "aim_time_nonlinearity_submarine"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SUBMARINE)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SUBMARINE, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_submarine"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SUBMARINE)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SUBMARINE, objValue / 100.0)
  }
  {
    id = "mouse_z_submarine"
    type = CONTROL_TYPE.MOUSE_AXIS
    axis_num = MouseAxis.MOUSE_SCROLL_SUBMARINE
    values = ["none", "submarine_main_engine", "submarine_zoom"]
    onChangeValue = "onMouseWheel"
    showFunc = ::is_mouse_available
  }
  {
    id = "mouse_z_mult_submarine"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_MOUSE_Z_SUBMARINE_MULT)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_Z_SUBMARINE_MULT, objValue / 100.0)
    showFunc = ::is_mouse_available
  }
//-------------------------------------------------------
  {
    id = "ID_SUBMARINE_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_SUBMARINE_ACOUSTIC_COUNTERMEASURES"
    checkGroup = ctrlGroups.SUBMARINE
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_KILLSTREAK_WHEEL_MENU"
    checkGroup = ctrlGroups.SUBMARINE
    showFunc = @() !(::is_platform_pc && !::is_xinput_device())
    checkAssign = false
  }
  {
    id = "ID_SUBMARINE_ACTION_BAR_ITEM_11"
    checkGroup = ctrlGroups.SUBMARINE
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_REPAIR_BREACHES"
    checkGroup = ctrlGroups.SUBMARINE
    checkAssign = false
    needShowInHelp = true
  }
]
