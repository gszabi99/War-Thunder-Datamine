let { getBundlesBlockName } = require("scripts/onlineShop/onlineBundles.nut")
let { requestMultipleItems } = require("scripts/onlineShop/shopItemInfo.nut")
let { GUI } = require("scripts/utils/configs.nut")
let { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

let bundlesShopInfo = Watched(null)

let function updateBundlesShopInfo() {
  if (!::g_login.isLoggedIn() || bundlesShopInfo.value)
    return

  let guidsList = []

  let bundlesList = GUI.get()?.bundles?[getBundlesBlockName()] ?? {}
  for (local i = 0; i < bundlesList.paramCount(); i++)
    guidsList.append(bundlesList.getParamValue(i))

  if (guidsList.len())
    requestMultipleItems(
      guidsList,
      function(res) {
        ::dagor.debug($"[ENTITLEMENTS INFO] Received success result, {res.status}")
        let resList = {}
        foreach (id, guid in bundlesList)
          if (guid in res.items)
            resList[id] <- res.items[guid].__merge({guid})
          else
            ::dagor.debug($"[ENTITLEMENTS INFO] Skip saving {id} - {guid}")
        bundlesShopInfo(resList)
      },
      function() {
        ::dagor.debug("[ENTITLEMENTS INFO] Received failure result")
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
  ScriptsReloaded = @(p) resetCache()
  SignOut = @(p) resetCache()
  LoginComplete = @(p) resetCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  bundlesShopInfo
}