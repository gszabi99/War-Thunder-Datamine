local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local getLimitCountByName = @(warbond) ::warbonds_get_purchase_limit(warbond.id, warbond.listId)

local leftSpecialTasksBoughtCount = ::Watched(-1)

local updateLeftSpecialTasksBoughtCount = function() {
  if (!::g_login.isLoggedIn())
    return

  local curWb = ::g_warbonds.getCurrentWarbond()
  if (curWb == null) {
    leftSpecialTasksBoughtCount(-1)
    return
  }

  leftSpecialTasksBoughtCount(getLimitCountByName(curWb))
}

addListenersWithoutEnv({
  PriceUpdated = @(p) updateLeftSpecialTasksBoughtCount()
  LoginComplete = @(p) updateLeftSpecialTasksBoughtCount()
  ScriptsReloaded = @(p) updateLeftSpecialTasksBoughtCount()
  BattleTasksRewardReceived = @(p) updateLeftSpecialTasksBoughtCount()
  WarbondAwardBought = @(p) updateLeftSpecialTasksBoughtCount()
})

return {
  leftSpecialTasksBoughtCount
}
