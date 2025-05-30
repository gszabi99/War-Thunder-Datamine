from "%scripts/dagui_natives.nut" import epic_is_running
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { ps4RegionName, isPlatformSony, isPlatformXbox } = require("%scripts/clientState/platform.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { convertBlk } = require("%sqstd/datablock.nut")

let cache = persist("cache", @() {})
function clearCache() {
  cache.clear()
  foreach (id in ["guid", "xbox", ps4RegionName(), "epic"]) {
    cache[id] <- {}
    cache[$"inv_{id}"] <- {}
  }
}
clearCache()

function getBundlesList(blockName) {
  if (!cache[blockName].len()) {
    if (!(blockName in cache)) {
      script_net_assert_once($"not exist bundles block {blockName} in cache", $"Don't exist requested bundles block {blockName} in cache")
      return ""
    }

    let guiBlk = GUI.get()?.bundles
    if (!guiBlk)
      return ""

    cache[blockName] = convertBlk(guiBlk[blockName])
  }

  return cache[blockName]
}

function getCachedBundleId(blockName, entName) {
  let list = getBundlesList(blockName)
  let res = list?[entName] ?? ""
  log($"Bundles: get id from block '{blockName}' by bundle '{entName}' = {res}")
  return res
}

function getCachedEntitlementId(blockName, bundleName) {
  if (!bundleName || bundleName == "")
    return ""

  let invBlockName = $"inv_{blockName}"

  if (!(bundleName in cache[invBlockName])) {
    cache[invBlockName][bundleName] <- ""
    let list = getBundlesList(blockName)
    foreach (entId, bndlId in list)
      if (bndlId == bundleName) {
        cache[invBlockName][bundleName] = entId
        break
      }
  }

  return cache[invBlockName][bundleName]
}

subscriptions.addListenersWithoutEnv({
  ScriptsReloaded = @(_p) clearCache()
  SignOut = @(_p) clearCache()
}, g_listener_priority.CONFIG_VALIDATION)

let getBundlesBlockName = @() isPlatformSony ? ps4RegionName()
  : isPlatformXbox ? "xbox"
  : epic_is_running() ? "epic"
  : "guid"

return {
  getBundlesBlockName
  getBundleId = @(name) getCachedBundleId(getBundlesBlockName(), name)
  getEntitlementId = @(name) getCachedEntitlementId(getBundlesBlockName(), name)
}