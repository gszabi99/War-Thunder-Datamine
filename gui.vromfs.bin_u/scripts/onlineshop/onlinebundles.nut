import "%scripts/g_listener_priority.nut" as g_listener_priority
import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
from "%sqstd/platform.nut" import isSony, isXbox
from "%appGlobals/clientState/platform.nut" import ps4RegionName
from "%sqstd/underscore.nut" import getSubTable
from "%sqstd/datablock.nut" import convertBlk
from "%scripts/dagui_natives.nut" import epic_is_running
from "%scripts/dagui_library.nut" import *

let { GUI } = require("%scripts/utils/configs.nut")

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

let getBundlesBlockName = @() isSony ? ps4RegionName()
  : isXbox ? "xbox"
  : epic_is_running() ? "epic"
  : "guid"

return freeze({
  getBundlesBlockName
  getBundleId = @(name) getCachedBundleId(getBundlesBlockName(), name)
  getEntitlementId = @(name) getCachedEntitlementId(getBundlesBlockName(), name)
})