//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")

local shopDiffMode = null

let function getShopDiffMode() {
  if (shopDiffMode != null)
    return shopDiffMode

  if (!::g_login.isProfileReceived())
    return null

  shopDiffMode = loadLocalAccountSettings("shopShowMode", -1)
  return shopDiffMode
}

let function storeShopDiffMode(value) {
  if (value == shopDiffMode)
    return

  shopDiffMode = value

  if (::g_login.isProfileReceived())
    saveLocalAccountSettings("shopShowMode", shopDiffMode)

  broadcastEvent("ShopDiffCodeChanged")
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