from "%scripts/dagui_natives.nut" import epic_is_running
from "%scripts/dagui_library.nut" import *
let { getSubTable } = require("%sqstd/underscore.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { ps4RegionName, isPlatformSony, isPlatformXbox } = require("%scripts/clientState/platform.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { convertBlk } = require("%sqstd/datablock.nut")

let cache = {}
let clearCache = @() cache.clear()

function getBundlesList(blockName) {
  if (blockName not in cache) {
    let blk = GUI.get()?.bundles[blockName]
    cache[blockName] <- blk ? convertBlk(blk) : {}
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

  let invBlock = getSubTable(cache, $"inv_{blockName}")
  if (bundleName not in invBlock) {
    invBlock[bundleName] <- ""
    let list = getBundlesList(blockName)
    foreach (entId, bndlId in list)
      if (bndlId == bundleName) {
        invBlock[bundleName] = entId
        break
      }
  }
  return invBlock[bundleName]
}

subscriptions.addListenersWithoutEnv({
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