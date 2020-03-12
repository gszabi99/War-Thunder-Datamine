local hudTankStates = require("scripts/hud/hudTankStates.nut")

local function updateState(obj, state, value) {
  local updateObj = state.updateObj
  local isVisible = state?.isVisible(value) ?? true
  if (!::check_obj(obj))
    return
  obj.show(isVisible)
  if (!isVisible)
    return

  updateObj(obj, value)
}

local function initStates(obj) {
  local stateObj = obj
  local subscriptions = {}
  foreach (name, state in hudTankStates.getStatesByObjName(obj?.id ?? ""))
  {
    local watched = state?.watched
    if (watched == null)
      continue

    local curState = state
    local updateObjectFunc = @(value) updateState(stateObj, curState, value)
    watched.subscribe(updateObjectFunc)
    subscriptions[name] <- updateObjectFunc
  }

  obj.setUserData(subscriptions)
}

local bhvHudTankStates = class {
  function onAttach(obj) {
    initStates(obj)
    return ::RETCODE_NOTHING
  }

  function onDetach(obj) {
    local subscriptions = obj.getUserData()
    if (subscriptions == null)
      return ::RETCODE_NOTHING

    local objStates = hudTankStates.getStatesByObjName(obj?.id ?? "")
    foreach (name, subscription in subscriptions)
      objStates?[name].watched.unsubscribe(subscription)

    return ::RETCODE_NOTHING
  }
}

::replace_script_gui_behaviour("bhvHudTankStates", bhvHudTankStates)
