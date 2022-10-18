from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { startLogout } = require("%scripts/login/logout.nut")
let { isDataBlock, eachParam } = require("%sqstd/datablock.nut")

const MAX_FETCH_RETRIES = 5

local unstableClusters = null

let function cacheUnstableClustersOnce() {
  if (unstableClusters != null)
    return
  unstableClusters = []
  let blk = ::get_network_block()?[::get_cur_circuit_name()].unstableClusters[::get_country_code()]
  if (isDataBlock(blk))
    eachParam(blk, @(v, k) v ? unstableClusters.append(k) : null)
}

let function isClusterUnstable(clusterName)
{
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

  function forceUpdateClustersList()
  {
    if (!::is_online_available())
      return

    __clusters_fetching = false
    __update_clusters_list()
  }

  function onClustersLoaded(params)
  {
    log("[MM] clusters loaded")
    debugTableData(params)

    let clusters = getTblValue("clusters", params)
    if (!::u.isArray(clusters))
      return false

    clusters_info.clear()
    foreach (_idx, val in params.clusters)
      clusters_info.append(mkCluster(val))
    //TODO: need to update clusters in GUI

    return clusters_info.len() > 0
  }

  function onClustersChanged(params)
  {
    if ("added" in params)
    {
      foreach (cluster in params.added)
      {
        local found = false
        foreach (_idx, c in clusters_info)
        {
          if (c.name == cluster)
          {
            found = true
            break
          }
        }
        if (!found)
        {
          clusters_info.append(mkCluster(cluster))
          log("[MM] cluster added " + cluster)
        }
      }
    }

    if ("removed" in params)
    {
      foreach (cluster in params.removed)
      {
        foreach (idx, c in clusters_info)
        {
          if (c.name == cluster)
          {
            clusters_info.remove(idx)
            break
          }
        }
        log("[MM] cluster removed " + cluster)
      }
    }
    log("clusters list updated")
    debugTableData(clusters_info)
    //TODO: need to update clusters in GUI
  }

// private
  __clusters_fetching = false
  __fetch_counter = 0

  function __update_clusters_list()
  {
    if (__clusters_fetching)
      return

    __clusters_fetching = true
    __fetch_counter++
    ::fetch_clusters_list(null,
      function(params)
      {
        if (!this)
          return

        __clusters_fetching = false

        if (::checkMatchingError(params, false)
            && onClustersLoaded(params))
        {
          __fetch_counter = 0
          return
        }

        //clusters not loaded or broken data
        if (__fetch_counter < MAX_FETCH_RETRIES)
        {
          log("fetch cluster error, retry - " + __fetch_counter)
          __update_clusters_list()
        } else
        {
          ::checkMatchingError(params, true)
          if (!::is_dev_version)
            startLogout()
        }
      }.bindenv(::g_clusters))
  }

  function onEventSignOut(_p)
  {
    clusters_info.clear()
  }

  function onEventScriptsReloaded(_p)
  {
    forceUpdateClustersList()
  }

  function onEventMatchingConnect(_p)
  {
    forceUpdateClustersList()
  }

  function getClusterLocName(clusterName)
  {
    if (clusterName.indexof("wthost") != null)
      return clusterName
    return loc("cluster/" + clusterName)
  }

  isClusterUnstable
}

::subscribe_handler(::g_clusters)