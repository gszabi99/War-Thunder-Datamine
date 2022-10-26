from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this


let { getBundlesBlockName } = require("%scripts/onlineShop/onlineBundles.nut")
let { requestMultipleItems } = require("%scripts/onlineShop/shopItemInfo.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isPlatformPC } = require("%scripts/clientState/platform.nut")

let bundlesShopInfo = Watched(null)

let function updateBundlesShopInfo() {
  if (!::g_login.isLoggedIn() || bundlesShopInfo.value || !isPlatformPC)
    return

  let guidsList = []

  let bundlesList = GUI.get()?.bundles?[getBundlesBlockName()] ?? {}
  for (local i = 0; i < bundlesList.paramCount(); i++)
    guidsList.append(bundlesList.getParamValue(i))

  if (guidsList.len())
    requestMultipleItems(
      guidsList,
      function(res) {
        log($"[ENTITLEMENTS INFO] Received success result, {res.status}")
        let resList = {}
        foreach (id, guid in bundlesList)
          if (guid in res.items)
            resList[id] <- res.items[guid].__merge({guid})
          else
            log($"[ENTITLEMENTS INFO] Skip saving {id} - {guid}")
        bundlesShopInfo(resList)
      },
      function() {
        log("[ENTITLEMENTS INFO] Received failure result")
        debugTableData(guidsList)
      }
    )
  else
    bundlesShopInfo({})
}

let function resetCache() {
  bundlesShopInfo(null)
  updateBundlesShopInfo()
}

addListenersWithoutEnv({
  ScriptsReloaded = @(_p) resetCache()
  SignOut = @(_p) resetCache()
  LoginComplete = @(_p) resetCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  bundlesShopInfo
}