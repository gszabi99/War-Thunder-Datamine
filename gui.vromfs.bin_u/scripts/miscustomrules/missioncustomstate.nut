::mission_rules <- {}
foreach (fn in [
                 "unitLimit.nut"
                 "ruleBase.nut"
                 "ruleSharedPool.nut"
                 "ruleEnduringConfrontation.nut"
                 "ruleNumSpawnsByUnitType.nut"
                 "ruleUnitsDeck.nut"
               ])
  ::g_script_reloader.loadOnce("%scripts/misCustomRules/" + fn) // no need to includeOnce to correct reload this scripts pack runtime

::on_custom_mission_state_changed <- function on_custom_mission_state_changed()
{
  ::g_mis_custom_state.onMissionStateChanged()
}

::on_custom_user_state_changed <- function on_custom_user_state_changed(userId64)
{
  ::g_mis_custom_state.onUserStateChanged(userId64)
}

::g_mis_custom_state <- {
  curRules = null
  isCurRulesValid = false
}

g_mis_custom_state.getCurMissionRules <- function getCurMissionRules()
{
  if (isCurRulesValid)
    return curRules

  local rulesClass = ::mission_rules.Empty

  let rulesName = getCurMissionRulesName()
  if (::u.isString(rulesName))
    rulesClass = findRulesClassByName(rulesName)

  let chosenRulesName = (rulesClass == ::mission_rules.Empty) ? "empty" : rulesName
  dagor.debug("Set mission custom rules to " + chosenRulesName + ". In mission info was " + rulesName)

  curRules = rulesClass()

  isCurRulesValid = true
  return curRules
}

g_mis_custom_state.getCurMissionRulesName <- function getCurMissionRulesName()
{
  let mis = ::is_in_flight() ? ::get_current_mission_info_cached() : null
  return mis?.customRules.guiName ?? mis?.customRules.name
}

g_mis_custom_state.findRulesClassByName <- function findRulesClassByName(rulesName)
{
  return ::getTblValue(::g_string.toUpper(rulesName, 1), ::mission_rules, ::mission_rules.Empty)
}

g_mis_custom_state.onMissionStateChanged <- function onMissionStateChanged()
{
  if (curRules)
    curRules.onMissionStateChanged()
  ::broadcastEvent("MissionCustomStateChanged")
}

g_mis_custom_state.onUserStateChanged <- function onUserStateChanged(userId64)
{
  if (userId64 == ::my_user_id_int64)
    ::broadcastEvent("MyCustomStateChanged")
  //::broadcastEvent("UserCustomStateChanged", { userId64 = userId64 }) //not used ATM but maybe needed in future
}

g_mis_custom_state.onEventLoadingStateChange <- function onEventLoadingStateChange(p)
{
  isCurRulesValid = false
}

::subscribe_handler(::g_mis_custom_state, ::g_listener_priority.CONFIG_VALIDATION)
