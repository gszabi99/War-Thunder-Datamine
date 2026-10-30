from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeEdiff
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent, addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "%scripts/dagui_library.nut" import *

local shopDiffMode = null

function getShopDiffMode() {
  if (shopDiffMode != null)
    return shopDiffMode

  if (!isProfileReceived.get())
    return null

  shopDiffMode = loadLocalAccountSettings("shopShowMode", -1)
  return shopDiffMode
}

function storeShopDiffMode(value) {
  if (value == shopDiffMode)
    return

  shopDiffMode = value

  if (isProfileReceived.get())
    saveLocalAccountSettings("shopShowMode", shopDiffMode)

  broadcastEvent("ShopDiffCodeChanged")
}

let isAutoDiff = @() shopDiffMode == -1
let getShopDiffCode = @() isAutoDiff()
  ? getCurrentGameModeEdiff()
  : getShopDiffMode() ?? getCurrentGameModeEdiff()

addListenersWithoutEnv({
  SignOut = @(_p) shopDiffMode = null
})

return freeze({
  getShopDiffCode
  getShopDiffMode
  storeShopDiffMode
  isAutoDiff
})