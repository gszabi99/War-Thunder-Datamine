from "%scripts/dagui_library.nut" import *
let { get_option_multiplier, set_option_multiplier,
  OPTION_AIM_TIME_NONLINEARITY_TANK, OPTION_AIM_ACCELERATION_DELAY_TANK,
  OPTION_MOUSE_Z_TANK_MULT
} = require("gameOptions")
let controlsOperations = require("%scripts/controls/controlsOperations.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { ActionGroup, hasXInputDevice, isXInputDevice } = require("controls")
let { checkOptionValue } = require("%scripts/controls/controlsUtils.nut")
let { CONTROL_TYPE, AxisDirection, ConflictGroups } = require("%scripts/controls/controlsConsts.nut")
let { USEROPT_AUTOMATIC_TRANSMISSION_TANK, USEROPT_INVERTY_TANK
} = require("%scripts/options/optionsExtNames.nut")
let { can_add_tank_alt_crosshair } = require("crosshair")

return [
  {
    id = "ID_TANK_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitTypes = [ unitTypes.TANK ]
    needShowInHelp = true
  }

  {
    id = "ID_TANK_OPERATIONS_HEADER"
    type = CONTROL_TYPE.SECTION
    showFunc = @() hasXInputDevice()
  }
  {
    id = "ID_TANK_SWAP_GAMEPAD_STICKS_WITHOUT_MODIFIERS"
    type = CONTROL_TYPE.BUTTON,
    onClick = @() controlsOperations.swapGamepadSticks(
      ActionGroup.TANK,
      controlsOperations.Flags.WITHOUT_MODIFIERS
    )
    showFunc = @() hasXInputDevice()
  }
  {
    id = "ID_TANK_SWAP_GAMEPAD_STICKS"
    type = CONTROL_TYPE.BUTTON,
    onClick = @() controlsOperations.swapGamepadSticks(
      ActionGroup.TANK
    )
    showFunc = @() hasXInputDevice()
  }

  {
    id = "ID_TANK_MOVE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "gm_automatic_transmission"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_AUTOMATIC_TRANSMISSION_TANK
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "ID_TOGGLE_TRANSMISSION_MODE_GM"
    checkAssign = false
  }
  {
    id = "gm_throttle"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.Y
    needShowInHelp = true
  }
  {
    id = "gm_steering"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.X
    needShowInHelp = true
  }
  {
    id = "ID_SHORT_BRAKE"
    checkAssign = false
  }
  {
    id = "gm_brake_left"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "gm_brake_right"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "ID_TRANS_GEAR_UP"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TRANS_GEAR_DOWN"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TRANS_GEAR_NEUTRAL"
    checkAssign = false
    showFunc = @() checkOptionValue(USEROPT_AUTOMATIC_TRANSMISSION_TANK, false)
  }
  {
    id = "ID_ENABLE_GM_DIRECTION_DRIVING"
    checkAssign = false
  }
  {
    id = "ID_ENABLE_GM_HULL_AIMING"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_GM_ENGINE"
    checkAssign = false
  }

  {
    id = "ID_TANK_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_FIRE_GM"
    conflictGroup = ConflictGroups.TANK_FIRE
    needShowInHelp = true
  }
  {
    id = "ID_FIRE_GM_SECONDARY_GUN"
    conflictGroup = ConflictGroups.TANK_FIRE
    checkAssign = false
  }
  {
    id = "ID_FIRE_GM_MACHINE_GUN"
    conflictGroup = ConflictGroups.TANK_FIRE
    checkAssign = false
  }
  {
    id = "ID_FIRE_GM_SPECIAL_GUN"
  }
  {
    id = "ID_SELECT_GM_GUN_RESET"
    checkAssign = false
  }
  {
    id = "ID_SELECT_GM_GUN_PRIMARY"
    checkAssign = false
  }
  {
    id = "ID_SELECT_GM_GUN_SECONDARY"
    checkAssign = false
  }
  {
    id = "ID_SELECT_GM_GUN_MACHINEGUN"
    checkAssign = false
  }
  {
    id = "ID_SELECT_GM_GUN_SPECIAL"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_AUTOTURRET_TARGETS"
    checkAssign = false
  }
  {
    id = "ID_SELECT_AUTOTURRET_TARGET"
    checkAssign = false
  }
  {
    id = "ID_IRCM_SWITCH_TANK"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SMOKE_SCREEN"
    checkAssign = false
  }
  {
    id = "ID_SMOKE_SCREEN_GENERATOR"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_CHANGE_SHOT_FREQ"
    checkAssign = false
  }
  {
    id = "ID_NEXT_BULLET_TYPE"
    checkAssign = false
  }
  {
    id = "ID_WEAPON_LOCK_TANK"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_WEAPON_LEAD_TANK"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_SWITCH_TANK"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_TYPE_SWITCH_TANK"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_MODE_SWITCH_TANK"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_ACM_SWITCH_TANK"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_SCAN_PATTERN_SWITCH_TANK"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_RANGE_SWITCH_TANK"
    checkAssign = false
  }
  {
    id = "ID_SENSOR_TARGET_SWITCH_TANK"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SENSOR_TARGET_LOCK_TANK"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "gm_sensor_cue_x"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "gm_sensor_cue_y"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "gm_sensor_cue_z"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "ID_TANK_NIGHT_VISION"
    checkAssign = false
  }
  {
    id = "ID_IR_PROJECTOR"
    checkAssign = false
  }
  {
    id = "ID_THERMAL_WHITE_IS_HOT"
    checkAssign = false
  }
  {
    id = "ID_COMMANDER_AIM_MODE"
    checkAssign = false
  }

  {
    id = "ID_TANK_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_ZOOM_HOLD_GM"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_VIEW_GM"
    needShowInHelp = true
  }
  {
    id = "ID_CAMERA_DRIVER"
    checkAssign = false
  }
  {
    id = "ID_CAMERA_BINOCULARS"
    checkAssign = false
  }
  {
    id = "ID_CAMERA_COMMANDER"
    checkAssign = false
  }
  






  {
    id = "ID_ENABLE_GUN_STABILIZER_GM"
    checkAssign = false
  }
  {
    id = "ID_TARGETING_HOLD_GM"
    checkAssign = false
  }
  {
    id = "gm_target_camera"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    condition = @() isPlatformSony || isPlatformXboxOne
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
  }
  {
    id = "gm_zoom"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "gm_camx"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.X
  }
  {
    id = "gm_camy"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "invert_y_tank"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_INVERTY_TANK
  }
  {
    id = "gm_mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
    needShowInHelp = true
  }
  {
    id = "gm_mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
    needShowInHelp = true
  }
  {
    id = "aim_time_nonlinearity_tank"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_TANK)
    setValue = @(_joyParams, objValue)
      set_option_multiplier(OPTION_AIM_TIME_NONLINEARITY_TANK, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_tank"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_TANK)
    setValue = @(_joyParams, objValue)
      set_option_multiplier(OPTION_AIM_ACCELERATION_DELAY_TANK, objValue / 100.0)
  }
  {
    id = "mouse_z_ground"
    type = CONTROL_TYPE.MOUSE_AXIS
    axis_num = MouseAxis.MOUSE_SCROLL_TANK
    values = ["none", "gm_zoom", "gm_sight_distance"]
    onChangeValue = "onMouseWheel"
    showFunc = @() hasFeature("EnableMouse")
  }
  {
    id = "mouse_z_mult_ground"
    type = CONTROL_TYPE.SLIDER
    value = @(_joyParams) 100.0 * get_option_multiplier(OPTION_MOUSE_Z_TANK_MULT)
    setValue = @(_joyParams, objValue) set_option_multiplier(OPTION_MOUSE_Z_TANK_MULT, objValue / 100.0)
    showFunc = @() hasFeature("EnableMouse")
  }

  {
    id = "ID_TANK_SUSPENSION_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_SUSPENSION_PITCH_UP"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_PITCH_DOWN"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_ROLL_UP"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_ROLL_DOWN"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_CLEARANCE_UP"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_CLEARANCE_DOWN"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SUSPENSION_RESET"
    checkAssign = false
    needShowInHelp = true
  }

  {
    id = "ID_TANK_SCOUT_UAV_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_START_SUPPORT_PLANE"
    checkAssign = false
    showFunc = @() hasFeature("TankSupportPlane")
  }
  {
    id = "ID_TOGGLE_UAV_CAMERA"
    checkAssign = false
  }
  {
    id = "ID_SUPPORT_PLANE_ORBITING"
    checkAssign = false
    showFunc = @() hasFeature("TankSupportPlane")
  }
  {
    id = "ID_DESIGNATE_TARGET"
    checkAssign = false
  }

  {
    id = "ID_TANK_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_REPAIR_TANK"
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_1"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_2"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_3"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_4"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_5"
    checkAssign = false
    showFunc = @() !isXInputDevice()
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_6"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_7"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_8"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_9"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_10"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_ACTION_BAR_ITEM_12"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_KILLSTREAK_WHEEL_MENU"
    checkAssign = false
    showFunc = hasXInputDevice
  }
  {
    id = "ID_SCOUT"
    checkAssign = false
    showFunc = @() hasFeature("ActiveScouting")
  }
  {
    id = "ID_START_UGV"
    checkAssign = false
    showFunc = @() hasFeature("TankSupportPlane")
  }
  {
    id = "ID_MINE_DETONATION"
    checkAssign = false
  }
  {
    id = "ID_UNLIMITED_CONTROL"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_CONSTRUCTION_MODE"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_STEALTH"
    checkAssign = false
    showFunc = @() hasFeature("TankStealth")
  }
  {
    id = "ID_RANGEFINDER"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_GM_CROSSHAIR_LIGHTING"
    checkAssign = false
  }
  {
    id = "ID_RELOAD_USER_SIGHT_GM"
    checkAssign = false
    showFunc = @() can_add_tank_alt_crosshair() && hasFeature("TankAltCrosshair")
  }
  {
    id = "ID_GM_TERRAFORM_TOGGLE"
    checkAssign = false
    showFunc = @() hasFeature("tankTerraform")
  }
  {
    id = "gm_sight_distance"
    type = CONTROL_TYPE.AXIS
    isAbsOnlyWhenRealAxis = true
    checkAssign = false
  }
  {
    id = "gm_wheelmenu_x"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.X
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = hasXInputDevice
    checkAssign = @() isXInputDevice()
  }
  {
    id = "gm_wheelmenu_y"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.Y
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    showFunc = hasXInputDevice
    checkAssign = @() isXInputDevice()
  }
  {
    id = "ID_TANK_SWITCH_FUSE_MODE"
    checkAssign = false
  }
]
