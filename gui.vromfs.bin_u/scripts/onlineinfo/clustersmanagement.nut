from "%scripts/dagui_natives.nut" import get_cur_circuit_name, is_online_available
from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version

let u = require("%sqStdLibs/helpers/u.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { DEFAULT_HANDLER } = require("%scripts/g_listener_priority.nut")
let { getCountryCode } = require("auth_wt")
let { getClustersByCountry } = require("%scripts/onlineInfo/defaultClusters.nut")
let { optimalClusters } = require("%scripts/onlineInfo/optimalClusters.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { isDataBlock, eachParam } = require("%sqstd/datablock.nut")
let { fetchClustersList } = require("%scripts/matching/serviceNotifications/match.nut")
let { get_network_block } = require("blkGetters")

const MAX_FETCH_RETRIES = 5

let clustersList = []

local unstableClusters = null

function cacheUnstableClustersOnce() {
  if (unstableClusters != null)
    return
  unstableClusters = []
  let blk = get_network_block()?[get_cur_circuit_name()].unstableClusters[getCountryCode()]
  if (isDataBlock(blk))
    eachParam(blk, @(v, k) v ? unstableClusters.append(k) : null)
}

function isClusterUnstable(clusterName) {
  cacheUnstableClustersOnce()
  return unstableClusters.contains(clusterName)
}

let mkCluster = @(name) {
  name
  isUnstable = isClusterUnstable(name)
}

function updateDefaultClusters() {
  let defaults = optimalClusters.value.len() > 0
    ? optimalClusters.value
    : getClustersByCountry(getCountryCode())
  clustersList.each(@(info) info.isDefault <- defaults.contains(info.name))
  let hasDefault = clustersList.findindex(@(info) info.isDefault) != null
  if (!hasDefault)
    clustersList.each(@(info) info.isDefault = true)
}

function onClustersLoaded(params) {
  log("[MM] clusters loaded")
  debugTableData(params)

  let clusters = getTblValue("clusters", params)
  if (!u.isArray(clusters))
    return false

  clustersList.clear()
  foreach (_idx, val in params.clusters)
    clustersList.append(mkCluster(val))

  updateDefaultClusters()
  return clustersList.len() > 0
}

let getClusterShortName = @(clusterId) loc($"cluster/{clusterId}", clusterId)

function getClusterFullName(clusterId) {
  let longName = loc($"cluster/{clusterId}/full", "")
  if (longName == "")
    return getClusterShortName(clusterId)

  return "".concat(longName,
    loc("ui/parentheses/space", { text = getClusterShortName(clusterId) }))
}

local isClustersFetching = false
local fetchCounter = 0

function updateClustersList() {
  if (isClustersFetching)
    return

  isClustersFetching = true
  ++fetchCounter

  let self = callee()
  fetchClustersList(null,
    function(params) {
      isClustersFetching = false

      if (::checkMatchingError(params, false)
          && onClustersLoaded(params)) {
        fetchCounter = 0
        return
      }

      // Clusters not loaded or data is broken
      if (fetchCounter < MAX_FETCH_RETRIES) {
        log($"fetch cluster error, retry - {fetchCounter}")
        self()
      }
      else if (!is_dev_version())
        startLogout()
    })
}

function forceUpdateClustersList() {
  if (!is_online_available())
    return

  isClustersFetching = false
  updateClustersList()
}

function onClustersChanged(params) {
  local needUpdateDefaultClusters = false
  if ("added" in params) {
    foreach (cluster in params.added) {
      local found = false
      foreach (_idx, c in clustersList) {
        if (c.name == cluster) {
          found = true
          break
        }
      }
      if (!found) {
        clustersList.append(mkCluster(cluster))
        log($"[MM] cluster added {cluster}")
        needUpdateDefaultClusters = true
      }
    }
  }

  if ("removed" in params) {
    foreach (cluster in params.removed) {
      foreach (idx, c in clustersList) {
        if (c.name == cluster) {
          clustersList.remove(idx)
          needUpdateDefaultClusters = true
          break
        }
      }
      log($"[MM] cluster removed {cluster}")
    }
  }
  if (needUpdateDefaultClusters)
    updateDefaultClusters()
  log("clusters list updated")
  debugTableData(clustersList)
}

optimalClusters.subscribe(@(_) updateDefaultClusters())

addListenersWithoutEnv({
  MatchingConnect = @(_) forceUpdateClustersList()
  ScriptsReloaded = @(_) forceUpdateClustersList() // todo consider implement persist
  SignOut = @(_) clustersList.clear()
  ClustersChanged = onClustersChanged
}, DEFAULT_HANDLER)

return {
  getClustersList = @() clustersList
  getClusterShortName
  getClusterFullName
  isClusterUnstable
}