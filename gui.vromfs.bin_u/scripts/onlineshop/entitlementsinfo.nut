from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { getBundlesBlockName } = require("%scripts/onlineShop/onlineBundles.nut")
let { requestMultipleItems } = require("%scripts/onlineShop/shopItemInfo.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isPlatformPC } = require("%scripts/clientState/platform.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { eventbus_subscribe } = require("eventbus")

let bundlesShopInfo = Watched(null)
let lists = {}

function updateBundlesShopInfo() {
  if (!isLoggedIn.get() || bundlesShopInfo.get() || !isPlatformPC)
    return

  lists.guidsList <- []

  lists.bundlesList <- GUI.get()?.bundles?[getBundlesBlockName()] ?? {}
  for (local i = 0; i < lists.bundlesList.paramCount(); i++)
    lists.guidsList.append(lists.bundlesList.getParamValue(i))

  if (lists.guidsList.len())
    requestMultipleItems(lists.guidsList, "requestMultipleItemsCb")
  else
    bundlesShopInfo.set({})
}

eventbus_subscribe("requestMultipleItemsCb", function(result) {
  if (!isLoggedIn.get())
    return

  log($"[ENTITLEMENTS INFO] Received success result, {result.status}")
  let resList = {}
  foreach (id, guid in lists.bundlesList)
    if (guid in result.items)
      resList[id] <- result.items[guid].__merge({ guid })
    else
      log($"[ENTITLEMENTS INFO] Skip saving {id} - {guid}")
  bundlesShopInfo.set(resList)
})

function resetCache() {
  lists.clear()
  bundlesShopInfo.set(null)
  updateBundlesShopInfo()
}

addListenersWithoutEnv({
  ScriptsReloaded = @(_p) resetCache()
  SignOut = @(_p) resetCache()
  LoginComplete = @(_p) resetCache()
}, g_listener_priority.CONFIG_VALIDATION)

return {
  bundlesShopInfo
}