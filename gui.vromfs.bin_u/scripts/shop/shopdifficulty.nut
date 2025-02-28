from "%scripts/dagui_library.nut" import *

let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

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

return {
  getShopDiffCode
  getShopDiffMode
  storeShopDiffMode
  isAutoDiff
}