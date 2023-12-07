from "%scripts/dagui_library.nut" import *
let { isString } = require("%sqStdLibs/helpers/u.nut")
let { toUpper } = require("%sqstd/string.nut")
let { addListenersWithoutEnv, CONFIG_VALIDATION, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_current_mission_info_cached } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { userIdInt64 } = require("%scripts/user/myUser.nut")

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

let findRulesClassByName = @(rulesName) getMissionRulesClass(toUpper(rulesName, 1)) ?? getMissionRulesClass("Empty")

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

function onMissionStateChanged() {
  if (curRules)
    curRules.onMissionStateChanged()
  broadcastEvent("MissionCustomStateChanged")
}

function onUserStateChanged(userId64) {
  if (userId64 != userIdInt64.value)
    return

  getCurMissionRules().clearUnitsLimitData()
  broadcastEvent("MyCustomStateChanged")
  //broadcastEvent("UserCustomStateChanged", { userId64 = userId64 }) //not used ATM but maybe needed in future
}

::on_custom_mission_state_changed <- function on_custom_mission_state_changed() {
  onMissionStateChanged()
}

::on_custom_user_state_changed <- function on_custom_user_state_changed(userId64) {
  onUserStateChanged(userId64)
}

addListenersWithoutEnv({
  LoadingStateChange = @(_) curMissionRulesInvalidate()
}, CONFIG_VALIDATION)

return {
  curMissionRulesInvalidate
  getCurMissionRules
  registerMissionRules
  findRulesClassByName
}