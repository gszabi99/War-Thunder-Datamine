local unitTypes = require("scripts/unit/unitTypesList.nut")

return [
  {
    id = "ID_SUIT_CONTROL_HEADER"
    unitType = unitTypes.TANK
    unitTag = "suit"
    showFunc = @() true //::has_feature("SuitControl") || ::get_player_cur_unit()?.isSuit()
    type = CONTROL_TYPE.HEADER
  }
//-------------------------------------------------------
  {
    id = "ID_SUIT_MOVE_HEADER"
    type = CONTROL_TYPE.SECTION
    needShowInHelp = true
  }
  {
    id = "suit_forward"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUIT
    axisDirection = AxisDirection.Y
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "suit_strafe"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUIT
    axisDirection = AxisDirection.X
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "suit_updown"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUIT
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "suit_roll"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUIT
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUIT_KILL_ROTATION"
    checkGroup = ctrlGroups.SUIT
    checkAssign = false
    needShowInHelp = true
  }
//-------------------------------------------------------
  {
    id = "ID_SUIT_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_SUIT"
    checkGroup = ctrlGroups.SUIT
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_SUIT_SECONDARY_GUN"
    checkGroup = ctrlGroups.SUIT
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_SUIT_SPECIAL_GUN"
    checkGroup = ctrlGroups.SUIT
    checkAssign = false
    needShowInHelp = true
  }
//-------------------------------------------------------
  {
    id = "ID_SUIT_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
    needShowInHelp = true
  }
  {
    id = "suit_zoom"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUIT
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TOGGLE_VIEW_SUIT"
    checkGroup = ctrlGroups.SUIT
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TARGETING_HOLD_SUIT"
    checkGroup = ctrlGroups.SUIT
    checkAssign = false
  }
  {
    id = "suit_camx"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUIT
    reqInMouseAim = false
    axisDirection = AxisDirection.X
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "suit_camy"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUIT
    reqInMouseAim = false
    axisDirection = AxisDirection.Y
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "invert_y_suit"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTY_SUIT
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "suit_mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUIT
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
    needShowInHelp = true
  }
  {
    id = "suit_mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.SUIT
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
    needShowInHelp = true
  }
  {
    id = "aim_time_nonlinearity_suit"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SUIT)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SUIT, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_suit"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SUIT)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SUIT, objValue / 100.0)
  }
]