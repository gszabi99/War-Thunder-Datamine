let { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

let getPurchaseLimitWb = @(warbond) ::warbonds_get_purchase_limit(warbond.id, warbond.listId)

let leftSpecialTasksBoughtCount = ::Watched(-1)

let updateLeftSpecialTasksBoughtCount = function() {
  if (!::g_login.isLoggedIn())
    return

  let specialTaskAward = ::g_warbonds.getCurrentWarbond()?.getAwardByType(::g_wb_award_type[::EWBAT_BATTLE_TASK])
  if (specialTaskAward == null) {
    leftSpecialTasksBoughtCount(-1)
    return
  }

  leftSpecialTasksBoughtCount(specialTaskAward.getLeftBoughtCount())
}

addListenersWithoutEnv({
  PriceUpdated = @(p) updateLeftSpecialTasksBoughtCount()
  LoginComplete = @(p) updateLeftSpecialTasksBoughtCount()
  ScriptsReloaded = @(p) updateLeftSpecialTasksBoughtCount()
  ProfileUpdated = @(p) updateLeftSpecialTasksBoughtCount()
})

return {
  leftSpecialTasksBoughtCount
  getPurchaseLimitWb
}
