local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local shopDiffMode = null

local function getShopDiffMode() {
  if (shopDiffMode != null)
    return shopDiffMode

  if (!::g_login.isProfileReceived())
    return null

  shopDiffMode = ::load_local_account_settings("shopShowMode", -1)
  return shopDiffMode
}

local function storeShopDiffMode(value) {
  if (value == shopDiffMode)
    return

  shopDiffMode = value

  if (::g_login.isProfileReceived())
    ::save_local_account_settings("shopShowMode", shopDiffMode)

  ::broadcastEvent("ShopDiffCodeChanged")
}

local isAutoDiff = @() shopDiffMode == -1
local getShopDiffCode = @() isAutoDiff()
  ? ::get_current_ediff()
  : getShopDiffMode() ?? ::get_current_ediff()

addListenersWithoutEnv({
  SignOut = @(p) shopDiffMode = null
})

return {
  getShopDiffCode
  getShopDiffMode
  storeShopDiffMode
  isAutoDiff
}