//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

local shopDiffMode = null

let function getShopDiffMode() {
  if (shopDiffMode != null)
    return shopDiffMode

  if (!::g_login.isProfileReceived())
    return null

  shopDiffMode = ::load_local_account_settings("shopShowMode", -1)
  return shopDiffMode
}

let function storeShopDiffMode(value) {
  if (value == shopDiffMode)
    return

  shopDiffMode = value

  if (::g_login.isProfileReceived())
    ::save_local_account_settings("shopShowMode", shopDiffMode)

  ::broadcastEvent("ShopDiffCodeChanged")
}

let isAutoDiff = @() shopDiffMode == -1
let getShopDiffCode = @() isAutoDiff()
  ? ::get_current_ediff()
  : getShopDiffMode() ?? ::get_current_ediff()

addListenersWithoutEnv({
  SignOut = @(_p) shopDiffMode = null
})

return {
  getShopDiffCode
  getShopDiffMode
  storeShopDiffMode
  isAutoDiff
}