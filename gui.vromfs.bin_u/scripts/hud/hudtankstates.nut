from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let hudTankStates = require("hudTankStates")
let { hudTankMovementStatesVisible } = require("%scripts/hud/hudConfigByGame.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { measureType } = require("%scripts/measureType.nut")

enum ORDER { 
  GEAR
  RPM
  CRUISE_CONTROL
  SPEED
}

let tankStatesByObjId = {
  stabilizer = {
    objName = "stabilizer"
    updateConfigs = [{
      watch = hudTankStates.getStabilizerObservable()
      isVisible = @(value) value != -1
      updateObj = @(obj, value) obj.findObject("stabilizer").state = value == 2 ? "dmg" : value == 0 ? "off" : "on"
    }]
  }
  lws = {
    objName = "lws"
    updateConfigs = [{
      watch = hudTankStates.getLwsObservable()
      isVisible = @(value) value != -1
      updateObj = @(obj, value) obj.findObject("lws").state = value == 2 ? "dmg" : value == 0 ? "off" : "on"
    }]
  }
  ircm = {
    objName = "ircm"
    updateConfigs = [{
      watch = hudTankStates.getIrcmObservable()
      isVisible = @(value) value != -1
      updateObj = @(obj, value) obj.findObject("ircm").state = value == 3 ? "off" : value == 2 ? "dmg" : "on"
    }]
  }
  gear = {
    objName = "gear"
    orderView = ORDER.GEAR
    getLocName = @() loc("HUD/GEAR_SHORT")
    updateConfigs = [{
      watch = hudTankStates.getGearObservable()
      updateObj = @(obj, value) obj.findObject("state_value").setValue(value)
    }]
  }
  rpm = {
    objName = "rpm"
    orderView = ORDER.RPM
    getLocName = @() loc("HUD/RPM_SHORT")
    updateConfigs = [{
      watch =  hudTankStates.getRpmObservable()
      updateObj = @(obj, value) obj.findObject("state_value").setValue(value.tostring())
    }]
  }
  speed = {
    objName = "speed"
    orderView = ORDER.SPEED
    getLocName = @() loc("HUD/REAL_SPEED_SHORT")
    updateConfigs = [{
        watch = hudTankStates.getSpeedObservable()
        updateObj = @(obj, value) obj.findObject("state_value").setValue(
          "".concat(value.tostring(), " ", measureType.SPEED.getMeasureUnitsName()))
      },
      {
        objName = "speed"
        watch = hudTankStates.getHasSpeedWarningObservable()
        updateObj = @(obj, value) obj.findObject("state_value").overlayTextColor = value ? "bad" : ""
      }]
   }

  driving_direction_mode = {
    objName = "driving_direction_mode"
    updateConfigs = [{
      watch = hudTankStates.getDrivingDirectionMode()
      updateObj = @(obj, value) obj.state = value ? "on" : "off"
    }]
  }

  cruise_control = {
    objName = "cruise_control"
    orderView = ORDER.CRUISE_CONTROL
    getLocName = @() loc("HUD/CRUISE_CONTROL_SHORT")
    updateConfigs = [{
      watch = hudTankStates.getCruiseControl()
      isVisible = @(value) value != ""
      updateObj = @(obj, value) obj.findObject("state_value").setValue(value)
    }]
  }

  first_stage_ammo = {
    objName = "first_stage_ammo"
    updateConfigs = [{
      watch = hudTankStates?.getFirstStageAmmo()
      isVisible = @(value) (value?.state ?? 0) > 0
      updateObj = function(obj, value) {
        let amount = value?.amount ?? 0
        obj.state = (value?.state ?? 0) == 2 ? "dmg"
            : amount > 0 ? "" : "dead"
        obj.findObject("state_value").setValue(amount.tostring())
      }
    }]
  }
}

function updateState(obj, watchConfig, value) {
  let isVisible = watchConfig?.isVisible(value) ?? true
  if (!checkObj(obj))
    return
  obj.show(isVisible)
  if (!isVisible)
    return

  watchConfig.updateObj(obj, value)
}

function getValueForObjUpdate(updateConfigs) {
  let stateValue = []
  foreach (updateConfig in updateConfigs) {
    let config = updateConfig
    let watch = config.watch
    if (watch == null)
      continue

    stateValue.append({
      watch = watch
      updateFunc = @(obj, value) updateState(obj, config, value)
    })
  }

  if (stateValue.len() == 0)
    return -1

  return stashBhvValueConfig(stateValue)
}

function getMovementViewArray() {
  let statesArray = []
  foreach (id, state in tankStatesByObjId) {
    if (!(id in hudTankMovementStatesVisible.get()) || state?.orderView == null)
      continue

    let stateValue = getValueForObjUpdate(state.updateConfigs)
    if (stateValue == "")
      continue

    statesArray.append({
      stateId = state.objName
      stateName = state.getLocName()
      orderView = state.orderView
      stateValue = stateValue
      })
  }
  statesArray.sort(@(a, b) a.orderView <=> b.orderView)
  return statesArray
}

function showHudTankMovementStates(scene) {
  let movementStatesObj = scene.findObject("hud_movement_info")
  if (!checkObj(movementStatesObj))
    return

  let blk = handyman.renderCached("%gui/hud/hudTankMovementInfo.tpl", { tankStates = getMovementViewArray() })
  this.guiScene.replaceContentFromText(movementStatesObj, blk, blk.len(), this)
}

let getConfigValueById = @(objName) getValueForObjUpdate(tankStatesByObjId?[objName].updateConfigs ?? [])

return {
  showHudTankMovementStates = showHudTankMovementStates
  getConfigValueById = getConfigValueById
}

