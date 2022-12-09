from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let controlsOperations = require("%scripts/controls/controlsOperations.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { ActionGroup } = require("controls")

return [
  {
    id = "ID_SUBMARINE_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitTypes = [ unitTypes.SHIP ]
    unitTag = "submarine"
    showFunc = @() hasFeature("SpecialShips") || (getPlayerCurUnit()?.isSubmarine() ?? false)
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
      ActionGroup.SUBMARINE,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() ::have_xinput_device()
  }
  {
    id = "ID_SUBMARINE_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ActionGroup.SUBMARINE
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
    axisDirection = AxisDirection.Y
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "submarine_steering"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.X
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "submarine_depth"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_FULL_STOP"
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
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_WEAPON_TORPEDOES"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_SWITCH_ACTIVE_SONAR"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_WEAPON_TOGGLE_SELF_HOMMING"
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
    checkAssign = false
  }
  {
    id = "submarine_camx"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.X
  }
  {
    id = "submarine_camy"
    type = CONTROL_TYPE.AXIS
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
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
  }
  {
    id = "submarine_mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
  }
  {
    id = "aim_time_nonlinearity_submarine"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * ::get_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_SUBMARINE)
    setValue = @(_joyParams, objValue)
      ::set_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_SUBMARINE, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_submarine"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * ::get_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_SUBMARINE)
    setValue = @(_joyParams, objValue)
      ::set_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_SUBMARINE, objValue / 100.0)
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
    value = @(_joyParams) 100.0 * ::get_option_multiplier(OPTION_MOUSE_Z_SUBMARINE_MULT)
    setValue = @(_joyParams, objValue) ::set_option_multiplier(OPTION_MOUSE_Z_SUBMARINE_MULT, objValue / 100.0)
    showFunc = ::is_mouse_available
  }
//-------------------------------------------------------
  {
    id = "ID_SUBMARINE_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_SUBMARINE_ACOUSTIC_COUNTERMEASURES"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_KILLSTREAK_WHEEL_MENU"
    showFunc = ::have_xinput_device
    checkAssign = false
  }
  {
    id = "ID_SUBMARINE_ACTION_BAR_ITEM_11"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUBMARINE_REPAIR_BREACHES"
    checkAssign = false
    needShowInHelp = true
  }
]
