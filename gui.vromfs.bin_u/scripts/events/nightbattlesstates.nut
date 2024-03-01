from "%scripts/dagui_library.nut" import *

let { getCurGameModeMinMRankForNightBattles } = require("%scripts/events/eventInfo.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { isProfileReceived } = require("%scripts/login/loginStates.nut")
let { getCurrentGameMode } = require("%scripts/gameModes/gameModeManagerState.nut")

const SEEN_NIGHT_BATTLE_WINDOW_ID  = "seen/night_battle_window"
local isSeenNightBattlesWindow = null

function canGoToNightBattleOnUnit(unit, modeName = null) {
  if (unit == null)
    return false

  let curEvent = getCurrentGameMode()?.getEvent()
  if (curEvent == null)
    return false
  let minMRank = getCurGameModeMinMRankForNightBattles(curEvent)
  if (minMRank == null || (minMRank > unit.getEconomicRank(::events.getEDiffByEvent(curEvent))))
    return false

  if (modeName != null)
    return unit.getNVDSights(modeName).len() > 0
  return unit.modifications.findvalue(@(v) unit.getNVDSights(v.name).len() > 0) != null
}

function needShowUnseenNightBattlesForUnit(unit, modeName = null) {
  if (!isProfileReceived.value)
    return false

  if (isSeenNightBattlesWindow == null)
    isSeenNightBattlesWindow = loadLocalAccountSettings(SEEN_NIGHT_BATTLE_WINDOW_ID, false)

  if (isSeenNightBattlesWindow)
    return false

  return canGoToNightBattleOnUnit(unit, modeName)
}

function saveSeenNightBattle(value) {
  isSeenNightBattlesWindow = value
  if (isProfileReceived.value)
    saveLocalAccountSettings(SEEN_NIGHT_BATTLE_WINDOW_ID, value)
  broadcastEvent("MarkSeenNightBattle")
}

addListenersWithoutEnv({
  SignOut = @(_p) isSeenNightBattlesWindow = null
})

let { register_command } = require("console")
register_command(@() saveSeenNightBattle(false), "debug.unseenNightBattle")

return {
  canGoToNightBattleOnUnit
  markSeenNightBattle = @() saveSeenNightBattle(true)
  needShowUnseenNightBattlesForUnit
}
