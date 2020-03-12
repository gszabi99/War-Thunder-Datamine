local hudTankStates = require_native("hudTankStates")
local { hudTankMovementStatesVisible } = require("scripts/hud/hudConfigByGame.nut")

enum ORDER //order for movement state info
{
  GEAR
  RPM
  CRUISE_CONTROL
  SPEED
}

local tankState = {
  stabilizer = {
    objName = "stabilizer"
    watched = hudTankStates.getStabilizerObservable()
    isVisible = @(value) value != -1
    getValue = @(value) value == 0 ? "off" : "on"
    updateObj = @(obj, value) obj.state = value == 0 ? "off" : "on"
  }
  gear = {
    objName = "gear"
    orderView = ORDER.GEAR
    getLocName = @() ::loc("HUD/GEAR_SHORT")
    watched = hudTankStates.getGearObservable()
    getValue = @(value) value
    updateObj = @(obj, value) obj.findObject("state_value").setValue(value)
  }
  rpm = {
    objName = "rpm"
    orderView = ORDER.RPM
    getLocName = @() ::loc("HUD/RPM_SHORT")
    watched =  hudTankStates.getRpmObservable()
    getValue = @(value) value.tostring()
    updateObj = @(obj, value) obj.findObject("state_value").setValue(value.tostring())
  }
  speed = {
    objName = "speed"
    orderView = ORDER.SPEED
    getLocName = @() ::loc("HUD/REAL_SPEED_SHORT")
    watched = hudTankStates.getSpeedObservable()
    getValue = @(value) "".concat(value.tostring(), " ", ::g_measure_type.SPEED.getMeasureUnitsName())
    updateObj = @(obj, value) obj.findObject("state_value").setValue(
      "".concat(value.tostring(), " ", ::g_measure_type.SPEED.getMeasureUnitsName()))
  }
  hasSpeedWarning = {
    objName = "speed"
    watched = hudTankStates.getHasSpeedWarningObservable()
    updateObj = @(obj, value) obj.findObject("state_value").overlayTextColor = value ? "bad" : ""
  }

  drivingDirectionMode = {
    objName = "driving_direction_mode"
    watched = hudTankStates.getDrivingDirectionMode()
    updateObj = @(obj, value) obj.state = value ? "on" : "off"
  }

  cruise_control = {
    objName = "cruise_control"
    orderView = ORDER.CRUISE_CONTROL
    getLocName = @() ::loc("HUD/CRUISE_CONTROL_SHORT")
    watched = hudTankStates.getCruiseControl()
    isVisible = @(value) value != ""
    getValue = @(value) value
    updateObj = @(obj, value) obj.findObject("state_value").setValue(value)
  }
}

local function getMovementViewArray() {
  local statesArray = []
  foreach (id, state in tankState)
    if ((id in hudTankMovementStatesVisible.value) && state?.orderView != null && state.watched != null)
      statesArray.append({
        stateId = state.objName
        stateName = state.getLocName()
        orderView = state.orderView
        stateValue = state.getValue(state.watched.value)
        isVisibleState = state?.isVisible(state.watched.value) ?? true
      })

  statesArray.sort(@(a, b) a.orderView <=> b.orderView)
  return statesArray
}

local function showHudTankMovementStates(scene) {
  local movementStatesObj = scene.findObject("hud_movement_info")
  if (!::check_obj(movementStatesObj))
    return

  local blk = ::handyman.renderCached("gui/hud/hudTankMovementInfo", {tankStates = getMovementViewArray()})
  guiScene.replaceContentFromText(movementStatesObj, blk, blk.len(), this)
}

local getStatesByObjName = @(objName) tankState.filter(@(v) v.objName == objName)

return {
  showHudTankMovementStates = showHudTankMovementStates
  getStatesByObjName = getStatesByObjName
}

