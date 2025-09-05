from "%scripts/dagui_library.nut" import *
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { CONTROL_TYPE, AxisDirection } = require("%scripts/controls/controlsConsts.nut")
let { hasXInputDevice } = require("controls")
let { ControlHelpersMode } = require("globalEnv")

return [
  {
    id = "ID_HUMAN_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitTypes = [ unitTypes.TANK



]
    unitTag = "type_exoskeleton"
    showFunc = @() hasFeature("Human") || (getPlayerCurUnit()?.isHuman() ?? false)
    needShowInHelp = true
  }

  {
    id = "ID_HUMAN_MOVE_HEADER"
    type = CONTROL_TYPE.SECTION
    needShowInHelp = true
  }
  {
    id = "human_walk"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.Y
    needShowInHelp = true
  }
  {
    id = "human_strafe"
    type = CONTROL_TYPE.AXIS
    axisDirection = AxisDirection.Y
    needShowInHelp = true
  }
  {
    id = "ID_HUMAN_JUMP"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_HUMAN_SPRINT"
    checkAssign = false
    needShowInHelp = true
  }


























































  {
    id = "ID_HUMAN_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
  }




























































  {
    id = "ID_HUMAN_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "human_camx"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.X
  }
  {
    id = "human_camy"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    axisDirection = AxisDirection.Y
  }
  {
    id = "human_mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
    needShowInHelp = true
  }
  {
    id = "human_mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
    needShowInHelp = true
  }
  {
    id = "ID_TOGGLE_VIEW_HUMAN"
    needShowInHelp = true
  }
  {
    id = "ID_TARGETING_HOLD_HUMAN"
    checkAssign = false
  }







  {
    id = "ID_HUMAN_UAV"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "human_uav_roll"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    needShowInHelp = true
  }
  {
    id = "human_uav_pitch"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    needShowInHelp = true
  }
  {
    id = "human_uav_yaw"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    needShowInHelp = true
  }
  {
    id = "human_uav_throttle"
    type = CONTROL_TYPE.AXIS
    needShowInHelp = true
  }
  {
    id = "human_uav_climb"
    type = CONTROL_TYPE.AXIS
    filterShow = [ ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR ]
  }
  {
    id = "ID_CONTROL_MODE_HUMAN_UAV"
    filterShow = [ControlHelpersMode.EM_MOUSE_AIM, ControlHelpersMode.EM_INSTRUCTOR]
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_LOCK_TARGETING_AT_POINT_HUMAN_UAV"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_UNLOCK_TARGETING_AT_POINT_HUMAN_UAV"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_TOGGLE_VIEW_HUMAN_UAV"
    checkAssign = false
    needShowInHelp = true
  }

  {
    id = "ID_HUMAN_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_HUMAN_KILLSTREAK_WHEEL_MENU"
    checkAssign = false
    showFunc = hasXInputDevice
  }
  {
    id = "ID_START_SUPPORT_PLANE_HUMAN"
    checkAssign = false
  }
  {
    id = "ID_SUPPORT_PLANE_ORBITING_HUMAN"
    checkAssign = false
  }
  {
    id = "ID_REPAIR_HUMAN"
    needShowInHelp = true
    checkAssign = false
  }
]
