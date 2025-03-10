from "%scripts/dagui_library.nut" import *
let { isString } = require("%sqStdLibs/helpers/u.nut")
let { capitalize } = require("%sqstd/string.nut")
let { addListenersWithoutEnv, CONFIG_VALIDATION, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_current_mission_info_cached } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { eventbus_subscribe } = require("eventbus")

let missionRules = {}
local curRules = null
local isCurRulesValid = false

function registerMissionRules(name, rules) {
  if (name in missionRules)
    logerr($"Mission rules {name} class already exist")
  missionRules[name] <- rules
}

let getMissionRulesClass = @(name) missionRules?[name]

let curMissionRulesInvalidate = @() isCurRulesValid = false

function getCurMissionRulesName(isDebug = false) {
  let mis = (isDebug || isInFlight()) ? get_current_mission_info_cached() : null
  return mis?.customRules.guiName ?? mis?.customRules.name
}

let findRulesClassByName = @(rulesName) getMissionRulesClass(capitalize(rulesName)) ?? getMissionRulesClass("Empty")

function getCurMissionRules(isDebug = false) {
  if (isCurRulesValid)
    return curRules

  local rulesClass = getMissionRulesClass("Empty")

  let rulesName = getCurMissionRulesName(isDebug)
  if (isString(rulesName))
    rulesClass = findRulesClassByName(rulesName)

  let chosenRulesName = (rulesClass == getMissionRulesClass("Empty")) ? "empty" : rulesName
  log($"Set mission custom rules to {chosenRulesName}. In mission info was {rulesName}")

  curRules = rulesClass()

  isCurRulesValid = true
  return curRules
}

function onMissionStateChanged(_) {
  if (curRules)
    curRules.onMissionStateChanged()
  broadcastEvent("MissionCustomStateChanged")
}

function onUserStateChanged(p) {
  let { userId64 } = p
  if (userId64 != userIdInt64.value)
    return

  getCurMissionRules().clearUnitsLimitData()
  broadcastEvent("MyCustomStateChanged")
  
}

eventbus_subscribe("on_custom_mission_state_changed", onMissionStateChanged)
eventbus_subscribe("on_custom_user_state_changed", onUserStateChanged)

addListenersWithoutEnv({
  LoadingStateChange = @(_) curMissionRulesInvalidate()
}, CONFIG_VALIDATION)

return {
  curMissionRulesInvalidate
  getCurMissionRules
  registerMissionRules
  findRulesClassByName
}