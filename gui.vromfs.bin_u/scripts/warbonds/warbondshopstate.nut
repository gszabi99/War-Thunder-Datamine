local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local leftSpecialTasksBoughtCount = ::Watched(-1)

const WARBONDS_SHOP_LEVEL_STATS = "val_warbonds_shop_level"

local updateLeftSpecialTasksBoughtCount = function() {
  if (!::g_login.isLoggedIn())
    return

  local curWb = ::g_warbonds.getCurrentWarbond()
  if (curWb == null) {
    leftSpecialTasksBoughtCount(-1)
    return
  }
  local specialTaskAward = curWb.getAwardByType(::g_wb_award_type[::EWBAT_BATTLE_TASK])
  if (specialTaskAward == null || specialTaskAward.maxBoughtCount <= 0) {
    leftSpecialTasksBoughtCount(-1)
    return
  }

  leftSpecialTasksBoughtCount(
    ::clamp(specialTaskAward.getLeftBoughtCount(), 0, specialTaskAward.maxBoughtCount))
}

addListenersWithoutEnv({
  PriceUpdated = @(p) updateLeftSpecialTasksBoughtCount()
  LoginComplete = @(p) updateLeftSpecialTasksBoughtCount()
  ScriptsReloaded = @(p) updateLeftSpecialTasksBoughtCount()
})

return {
  leftSpecialTasksBoughtCount
  WARBONDS_SHOP_LEVEL_STATS
}
