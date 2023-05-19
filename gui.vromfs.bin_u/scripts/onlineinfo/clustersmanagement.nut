//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this
let { getCountryCode } = require("auth_wt")
let { getClustersByCountry } = require("%scripts/onlineInfo/defaultClusters.nut")
let { optimalClusters } = require("%scripts/onlineInfo/optimalClusters.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { isDataBlock, eachParam } = require("%sqstd/datablock.nut")
let { fetchClustersList } = require("%scripts/matching/serviceNotifications/match.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")

const MAX_FETCH_RETRIES = 5

local unstableClusters = null

let function cacheUnstableClustersOnce() {
  if (unstableClusters != null)
    return
  unstableClusters = []
  let blk = ::get_network_block()?[::get_cur_circuit_name()].unstableClusters[getCountryCode()]
  if (isDataBlock(blk))
    eachParam(blk, @(v, k) v ? unstableClusters.append(k) : null)
}

let function isClusterUnstable(clusterName) {
  cacheUnstableClustersOnce()
  return unstableClusters.contains(clusterName)
}

let mkCluster = @(name) {
  name
  isUnstable = isClusterUnstable(name)
}

// -------------------------------------------------------
// Clusters managment
// -------------------------------------------------------
::g_clusters <- {
  clusters_info = []

  function forceUpdateClustersList() {
    if (!::is_online_available())
      return

    this.__clusters_fetching = false
    this.__update_clusters_list()
  }

  function onClustersLoaded(params) {
    log("[MM] clusters loaded")
    debugTableData(params)

    let clusters = getTblValue("clusters", params)
    if (!u.isArray(clusters))
      return false

    this.clusters_info.clear()
    foreach (_idx, val in params.clusters)
      this.clusters_info.append(mkCluster(val))

    this.updateDefaultClusters()
    //TODO: need to update clusters in GUI

    return this.clusters_info.len() > 0
  }

  function updateDefaultClusters() {
    let defaults = optimalClusters.value.len() > 0
      ? optimalClusters.value
      : getClustersByCountry(getCountryCode())
    this.clusters_info.each(@(info) info.isDefault <- defaults.contains(info.name))
    let hasDefault = this.clusters_info.findindex(@(info) info.isDefault) != null
    if (!hasDefault)
      this.clusters_info.each(@(info) info.isDefault = true)
  }

  function onClustersChanged(params) {
    if ("added" in params) {
      foreach (cluster in params.added) {
        local found = false
        foreach (_idx, c in this.clusters_info) {
          if (c.name == cluster) {
            found = true
            break
          }
        }
        if (!found) {
          this.clusters_info.append(mkCluster(cluster))
          log("[MM] cluster added " + cluster)
          this.updateDefaultClusters()
        }
      }
    }

    if ("removed" in params) {
      foreach (cluster in params.removed) {
        foreach (idx, c in this.clusters_info) {
          if (c.name == cluster) {
            this.clusters_info.remove(idx)
            break
          }
        }
        log("[MM] cluster removed " + cluster)
      }
    }
    log("clusters list updated")
    debugTableData(this.clusters_info)
    //TODO: need to update clusters in GUI
  }

// private
  __clusters_fetching = false
  __fetch_counter = 0

  function __update_clusters_list() {
    if (this.__clusters_fetching)
      return

    this.__clusters_fetching = true
    this.__fetch_counter++
    fetchClustersList(null,
      function(params) {
        if (!this)
          return

        this.__clusters_fetching = false

        if (::checkMatchingError(params, false)
            && this.onClustersLoaded(params)) {
          this.__fetch_counter = 0
          return
        }

        //clusters not loaded or broken data
        if (this.__fetch_counter < MAX_FETCH_RETRIES) {
          log("fetch cluster error, retry - " + this.__fetch_counter)
          this.__update_clusters_list()
        }
        else if (!::is_dev_version)
          startLogout()
      }.bindenv(::g_clusters))
  }

  function onEventSignOut(_p) {
    this.clusters_info.clear()
  }

  function onEventScriptsReloaded(_p) {
    this.forceUpdateClustersList()
  }

  function onEventMatchingConnect(_p) {
    this.forceUpdateClustersList()
  }

  function getClusterLocName(clusterName) {
    if (clusterName.indexof("wthost") != null)
      return clusterName
    return loc("cluster/" + clusterName)
  }

  isClusterUnstable
}

optimalClusters.subscribe(@(_) ::g_clusters.updateDefaultClusters())
subscribe_handler(::g_clusters)