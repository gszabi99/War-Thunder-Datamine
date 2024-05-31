from "%scripts/dagui_library.nut" import *
let { get_option_multiplier, set_option_multiplier,
  OPTION_AIM_TIME_NONLINEARITY_SHIP, OPTION_AIM_ACCELERATION_DELAY_SHIP,
  OPTION_MOUSE_Z_SHIP_MULT
} = require("gameOptions")
let controlsOperations = require("%scripts/controls/controlsOperations.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { ActionGroup, hasXInputDevice, isXInputDevice } = require("controls")
let { checkOptionValue } = require("%scripts/controls/controlsUtils.nut")
let { CONTROL_TYPE, AxisDirection } = require("%scripts/controls/controlsConsts.nut")
let { USEROPT_SEPERATED_ENGINE_CONTROL_SHIP, USEROPT_WHEEL_CONTROL_SHIP,
  USEROPT_SINGLE_SHOT_BY_TURRET, USEROPT_SHIP_COMBINE_PRI_SEC_TRIGGERS,
  USEROPT_INVERTY_SHIP
} = require("%scripts/options/optionsExtNames.nut")

return [
  {
    id = "ID_SHIP_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitTypes = [
      unitTypes.SHIP
      unitTypes.BOAT
    ]
    needShowInHelp = true
  }
//-------------------------------------------------------
  {
    id = "ID_SHIP_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() hasXInputDevice()
  }
  {
    id = "ID_SHIP_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON
    onClick = @() controlsOperations.swapGamepadSticks(
      ActionGroup.SHIP,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() hasXInputDevice()
  }
  {
    id = "ID_SHIP_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON,
    onClick = @() controlsOperations.swapGamepadSticks(ActionGroup.SHIP)
    showFunc = @() hasXInputDevice()
  }
//-------------------------------------------------------
  {
    id = "ID_SHIP_MOVE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ship_seperated_engine_control"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_SEPERATED_ENGINE_CONTROL_SHIP
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "ship_main_engine"
    type = CONTROL_TYPE.AXIS
    showFunc = @() checkOptionValue(USEROPT_SEPERATED_ENGINE_CONTROL_SHIP, false)
    axisDirection = AxisDirection.Y
    needShowInHelp = true
  }
  {
    id = "ship_port_engine"
    type = CONTROL_TYPE.AXIS
    showFunc = @() checkOptionValue(USEROPT_SEPERATED_ENGINE_CONTROL_SHIP, true)
    checkAssign = false
  }
  {
    id = "ship_star_engine"
    type = CONTROL_TYPE.AXIS
    showFunc = @() checkOptionValue(USEROPT_SEPERATED_ENGINE_CONTROL_SHIP, true)
    checkAssign = false
  }
  {
    id = "ship_steering"
    type = CONTROL_TYPE.AXIS,
    axisDirection = AxisDirection.X
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_FULL_STOP"
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_SHIP_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_SHIP_WEAPON_ALL"
    needShowInHelp = true
  }
  {
    id = "selectWheelShipEnable"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_WHEEL_CONTROL_SHIP
    onChangeValue = "doControlsGroupChangeDelayed"
    showFunc = @() (isXInputDevice() || isPlatformSony || isPlatformXboxOne)
  }
  {
    id = "ID_SHIP_SELECTWEAPON_WHEEL_MENU"
    checkAssign = false
    showFunc = @() checkOptionValue(USEROPT_WHEEL_CONTROL_SHIP, true)
      && (isXInputDevice() || isPlatformSony || isPlatformXboxOne)
  }
  {
    id = "ID_SHIP_WEAPON_PRIMARY"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_SECONDARY"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_MACHINEGUN"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SINGLE_SHOT_SHIP"
    checkAssign = false
  }
  {
    id = "singleShotByTurret"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_SINGLE_SHOT_BY_TURRET
  }
  {
    id = "shipCombinePriSecTriggers"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_SHIP_COMBINE_PRI_SEC_TRIGGERS
  }
  {
    id = "ID_SHIP_WEAPON_TORPEDOES"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_DEPTH_CHARGE"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_MINE"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_MORTAR"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_WEAPON_ROCKETS"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_SMOKE_GRENADE"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_SMOKE_SCREEN_GENERATOR"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_TORPEDO_SIGHT"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_TOGGLE_GUNNERS"
    checkAssign = false
  }
  {
    id = "ID_SHIP_SWITCH_TRIGGER_GROUP"
    checkAssign = false
  }
  {
    id = "ID_SHIP_SELECT_TARGET_AI_PRIM"
    checkAssign = false
  }
  {
    id = "ID_SHIP_SELECT_TARGET_AI_SEC"
    checkAssign = false
  }
  {
    id = "ID_SHIP_SELECT_TARGET_AI_MGUN"
    checkAssign = false
  }
  {
    id = "ID_SHIP_NEXT_BULLET_TYPE"
     checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_SHIP_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_TOGGLE_VIEW_SHIP"
    needShowInHelp = true
  }
  {
    id = "ID_TARGETING_HOLD_SHIP"
    checkAssign = false
  }
  {
    id = "ID_LOCK_TARGETING_AT_POINT_SHIP"
    checkAssign = false
  }
  {
    id = "ID_WEAPON_LEAD_SHIP"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_SWITCH_SHIP"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_WEAPON_LOCK_SHIP"
    checkAssign = false
    needShowInHelp = true
  }
/*
  {
    id = "ID_SENSOR_TYPE_SWITCH_SHIP"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_MODE_SWITCH_SHIP"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_ACM_SWITCH_SHIP"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_SCAN_PATTERN_SWITCH_SHIP"
    checkAssign = false
  }
*/
  {
    id = "ID_SENSOR_RANGE_SWITCH_SHIP"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_TARGET_SWITCH_SHIP"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_TARGET_LOCK_SHIP"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ship_sensor_cue_x"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "ship_sensor_cue_y"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "ship_sensor_cue_z"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "ship_zoom"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "ship_camx"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.X
  }
  {
    id = "ship_camy"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "invert_y_ship"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_INVERTY_SHIP
  }
  {
    id = "ship_mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
  }
  {
    id = "ship_mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
  }
  {
    id = "aim_time_nonlinearity_ship"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_SHIP)
    setValue = @(_joyParams, objValue)
      set_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_SHIP, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_ship"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_SHIP)
    setValue = @(_joyParams, objValue)
      set_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_SHIP, objValue / 100.0)
  }
  {
    id = "mouse_z_ship"
    type = CONTROL_TYPE.MOUSE_AXIS
    axis_num = MouseAxis.MOUSE_SCROLL_SHIP
    values = ["none", "ship_sight_distance", "ship_main_engine", "ship_zoom"]
    onChangeValue = "onMouseWheel"
    showFunc = @() hasFeature("EnableMouse")
  }
  {
    id = "mouse_z_mult_ship"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_MOUSE_Z_SHIP_MULT)
    setValue = @(_joyParams, objValue) set_option_multiplier(OPTION_MOUSE_Z_SHIP_MULT, objValue / 100.0)
    showFunc = @() hasFeature("EnableMouse")
  }
//-------------------------------------------------------
  {
    id = "ID_SHIP_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_1"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_2"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_3"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_4"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_5"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_KILLSTREAK_WHEEL_MENU"
    checkAssign = false
    showFunc = hasXInputDevice
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_6"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_11"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_REPAIR_BREACHES"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHIP_ACTION_BAR_ITEM_10"
    checkAssign = false
    needShowInHelp = true
  }
  //
















  {
    id = "ID_SHIP_LOCK_SHOOT_DISTANCE"
    checkAssign = false
  }
  {
    id = "ship_sight_distance"
    type = CONTROL_TYPE.AXIS
    isAbsOnlyWhenRealAxis = true
    checkAssign = false
  }
  {
    id = "ship_shoot_direction"
    type = CONTROL_TYPE.AXIS
    isAbsOnlyWhenRealAxis = true
    checkAssign = false
  }
  {
    id = "ship_wheelmenu_x"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.X
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = hasXInputDevice
    checkAssign = @() isXInputDevice()
  }
  {
    id = "ship_wheelmenu_y"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.Y
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = hasXInputDevice
    checkAssign = @() isXInputDevice()
  }
  {
    id = "ID_EVENT_ACTION"
    checkAssign = false
  }
  {
    id = "ID_START_SUPPORT_PLANE_SHIP"
    checkAssign = false
  }
  {
    id = "ID_SUPPORT_PLANE_ORBITING_SHIP"
    checkAssign = false
  }
  //

















































  {
    id = "ID_CANCEL_SUPPORT_PLANE_FUSE"
    checkAssign = false
  }
]
