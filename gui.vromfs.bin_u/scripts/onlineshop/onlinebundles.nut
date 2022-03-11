local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local { ps4RegionName, isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")
local { GUI } = require("scripts/utils/configs.nut")

local cache = persist("cache", @() {})
local function clearCache() {
  cache.clear()
  foreach (id in ["guid", "xbox", ps4RegionName(), "epic"])
  {
    cache[id] <- {}
    cache[$"inv_{id}"] <- {}
  }
}
clearCache()

local function getBundlesList(blockName) {
  if (!cache[blockName].len())
  {
    if (!(blockName in cache))
    {
      ::script_net_assert_once($"not exist bundles block {blockName} in cache", $"Don't exist requested bundles block {blockName} in cache")
      return ""
    }

    local guiBlk = GUI.get()?.bundles
    if (!guiBlk)
      return ""

    cache[blockName] = ::buildTableFromBlk(guiBlk[blockName])
  }

  return cache[blockName]
}

local function getCachedBundleId(blockName, entName) {
  local list = getBundlesList(blockName)
  local res = list?[entName] ?? ""
  ::dagor.debug($"Bundles: get id from block '{blockName}' by bundle '{entName}' = {res}")
  return res
}

local function getCachedEntitlementId(blockName, bundleName) {
  if (!bundleName || bundleName == "")
    return ""

  local invBlockName = $"inv_{blockName}"

  if (!(bundleName in cache[invBlockName]))
  {
    cache[invBlockName][bundleName] <- ""
    local list = getBundlesList(blockName)
    foreach (entId, bndlId in list)
      if (bndlId == bundleName)
      {
        cache[invBlockName][bundleName] = entId
        break
      }
  }

  return cache[invBlockName][bundleName]
}

subscriptions.addListenersWithoutEnv({
  ScriptsReloaded = @(p) clearCache()
  SignOut = @(p) clearCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

local getBundlesBlockName = @() isPlatformSony ? ps4RegionName()
  : isPlatformXboxOne ? "xbox"
  : ::epic_is_running() ? "epic"
  : "guid"

return {
  getBundlesBlockName
  getBundleId = @(name) getCachedBundleId(getBundlesBlockName(), name)
  getEntitlementId = @(name) getCachedEntitlementId(getBundlesBlockName(), name)
}